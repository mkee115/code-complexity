# =============================================================================
# complexity_analysis.R
# Statistical analysis of Java method complexity metrics
# Data source: cc_data.csv + repos.csv produced by ComplexityCalculator.java
#
# cc_data columns:
#   project, class_name, method_name,
#   cc, cognitive_complexity,
#   loc, loc_physical,
#   avg_nesting, max_nesting,
#   avg_id_words, abbreviated_ratio, single_letter_ids, longest_id,
#   total_words, comment_count, comment_words
#
# repos.csv columns:
#   full_name, url, scraped_at, language, stars, forks,
#   size_kb, commit_count, java_file_count, created_at, pushed_at
# =============================================================================

library(tidyverse)
library(scales)
library(moments)
if (!requireNamespace("GGally",   quietly = TRUE)) install.packages("GGally")
if (!requireNamespace("ggridges", quietly = TRUE)) install.packages("ggridges")
if (!requireNamespace("broom",    quietly = TRUE)) install.packages("broom")
if (!requireNamespace("ggrepel",  quietly = TRUE)) install.packages("ggrepel")
library(GGally)
library(ggridges)
library(broom)
library(ggrepel)

# =============================================================================
# 0. CONFIG
# =============================================================================

CC_FILE    <- "cc_data.csv"
REPOS_FILE <- "repos.csv"
OUT        <- "output"
dir.create(OUT, showWarnings = FALSE)

BAND_BREAKS  <- c(5, 10, 15, 25)
BAND_LABELS  <- c("1-5", "6-10", "11-15", "16-25", "25+")
BAND_COLOURS <- c("#2ca02c", "#8fbc8f", "#ff7f0e", "#d62728", "#9467bd")
names(BAND_COLOURS) <- BAND_LABELS

save_plot <- function(p, name, w = 9, h = 6) {
  ggsave(file.path(OUT, name), p, width = w, height = h, dpi = 150)
  invisible(p)
}

# =============================================================================
# 1. LOAD & CLEAN
# =============================================================================

cat("Loading cc_data.csv...\n")
df_raw <- read_csv(CC_FILE, show_col_types = FALSE)

# enforce numeric types — only coerce columns that are actually present
numeric_candidates <- c("cc", "cognitive_complexity", "loc", "loc_physical",
                        "avg_nesting", "max_nesting", "avg_id_words",
                        "abbreviated_ratio", "single_letter_ids", "longest_id",
                        "total_words", "comment_count", "comment_words")
numeric_present <- intersect(numeric_candidates, names(df_raw))

df <- df_raw
for (col in numeric_present) {
  df[[col]] <- as.numeric(unlist(df[[col]]))
}
df <- df %>% filter(!is.na(cc), cc >= 1)

# derived columns — guarded so missing source columns produce NA, not an error
has_loc_col      <- "loc"                  %in% names(df)
has_loc_phys_col <- "loc_physical"         %in% names(df)
has_cog_col      <- "cognitive_complexity" %in% names(df)
has_comment_cols <- all(c("comment_count", "comment_words") %in% names(df))
has_id_cols      <- all(c("avg_id_words", "abbreviated_ratio") %in% names(df))

df <- df %>% mutate(
  risk_band       = cut(cc, breaks = c(0, BAND_BREAKS, Inf),
                        labels = BAND_LABELS, right = TRUE),
  loc_band        = if (has_loc_col)      ifelse(loc <= 24, "<=24 LOC", ">24 LOC") else NA_character_,
  has_comments    = if (has_comment_cols) comment_count > 0                         else NA,
  comment_density = if (has_comment_cols && has_loc_col)
    ifelse(loc > 0, comment_words / loc, NA_real_)               else NA_real_,
  word_density    = if ("total_words" %in% names(df) && has_loc_col)
    ifelse(loc > 0, total_words / loc, NA_real_)                 else NA_real_,
  naming_score    = if (has_id_cols)
    avg_id_words * (1 - abbreviated_ratio)                        else NA_real_,
  cog_ratio       = if (has_cog_col)
    ifelse(cc > 0, cognitive_complexity / cc, NA_real_)           else NA_real_,
  blank_ratio     = if (has_loc_phys_col && has_loc_col)
    ifelse(loc_physical > 0, (loc_physical - loc) / loc_physical, NA_real_) else NA_real_
)

# repos metadata (optional - enriches project-level analysis)
repos <- if (file.exists(REPOS_FILE)) {
  read_csv(REPOS_FILE, show_col_types = FALSE) %>%
    rename(project = full_name)
} else {
  cat("Note: repos.csv not found. Project-level metadata plots will be skipped.\n")
  NULL
}

n         <- nrow(df)
n_proj    <- n_distinct(df$project)
cat(sprintf("Loaded %d methods across %d projects.\n", n, n_proj))

# columns present?
has_repos    <- !is.null(repos)
has_cognitive <- "cognitive_complexity" %in% names(df) && sum(!is.na(df$cognitive_complexity)) > 0
has_nesting  <- all(c("avg_nesting", "max_nesting") %in% names(df))
has_id       <- all(c("avg_id_words", "abbreviated_ratio") %in% names(df))
has_comments <- all(c("comment_count", "comment_words") %in% names(df))
has_loc      <- "loc" %in% names(df)

# =============================================================================
# 2. DESCRIPTIVE STATISTICS TABLE
# =============================================================================

cat("\n-- Descriptive Statistics --\n")

metric_cols <- c("cc", "cognitive_complexity", "loc", "loc_physical",
                 "avg_nesting", "max_nesting", "avg_id_words",
                 "abbreviated_ratio", "total_words", "comment_words")
metric_cols <- intersect(metric_cols, names(df))

desc <- map_dfr(metric_cols, function(col) {
  x <- df[[col]][!is.na(df[[col]])]
  tibble(
    metric   = col,
    n        = length(x),
    min      = min(x),
    q1       = quantile(x, 0.25),
    median   = median(x),
    mean     = mean(x),
    q3       = quantile(x, 0.75),
    max      = max(x),
    sd       = sd(x),
    skewness = skewness(x),
    kurtosis = kurtosis(x)
  )
})

print(desc, n = Inf)
write_csv(desc, file.path(OUT, "descriptive_stats.csv"))

# =============================================================================
# 3. METRIC INTERCORRELATION ANALYSIS
# =============================================================================

# --- 3a. Full correlation matrix with significance -------------------------

cat("\n-- Correlation Matrix --\n")

cor_cols <- intersect(
  c("cc", "cognitive_complexity", "loc", "loc_physical",
    "avg_nesting", "max_nesting", "avg_id_words", "abbreviated_ratio",
    "single_letter_ids", "longest_id", "total_words",
    "comment_count", "comment_words"),
  names(df)
)

cor_data   <- df[, cor_cols] %>% drop_na()
cor_matrix <- cor(cor_data, use = "pairwise.complete.obs")
print(round(cor_matrix, 3))
write_csv(as_tibble(cor_matrix, rownames = "metric"),
          file.path(OUT, "correlation_matrix.csv"))

nice_names <- c(
  cc                   = "Cyclomatic",
  cognitive_complexity = "Cognitive",
  loc                  = "LOC (NBNC)",
  loc_physical         = "LOC (physical)",
  avg_nesting          = "Avg Nesting",
  max_nesting          = "Max Nesting",
  avg_id_words         = "Avg ID Words",
  abbreviated_ratio    = "Abbrev Ratio",
  single_letter_ids    = "Single-letter IDs",
  longest_id           = "Longest ID",
  total_words          = "Total Words",
  comment_count        = "Comment Count",
  comment_words        = "Comment Words"
)

cor_long <- as_tibble(cor_matrix, rownames = "var1") %>%
  pivot_longer(-var1, names_to = "var2", values_to = "r") %>%
  mutate(
    var1  = recode(var1, !!!nice_names),
    var2  = recode(var2, !!!nice_names),
    label = ifelse(abs(r) >= 0.05, sprintf("%.2f", r), "")
  )

# Plot 01: Correlation heatmap
p01 <- ggplot(cor_long, aes(x = var1, y = var2, fill = r)) +
  geom_tile(colour = "white", linewidth = 0.4) +
  geom_text(aes(label = label), size = 2.6) +
  scale_fill_gradient2(low = "#d62728", mid = "white", high = "#1f77b4",
                       midpoint = 0, limits = c(-1, 1), name = "r") +
  labs(title = "Pearson Correlation Between All Complexity Metrics",
       subtitle = "Cells suppressed below |r| = 0.05",
       x = NULL, y = NULL) +
  theme_minimal(base_size = 11) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1),
        panel.grid  = element_blank())
save_plot(p01, "01_correlation_heatmap.png", w = 11, h = 9)

# --- 3b. Cyclomatic vs Cognitive: where do they diverge? ------------------

if (has_cognitive) {
  
  # Ratio distribution: cog/cc — values above 1 mean cognitive penalises more
  p02 <- ggplot(df %>% filter(!is.na(cog_ratio), cog_ratio > 0, cc >= 2),
                aes(x = cc, y = cog_ratio)) +
    geom_hex(bins = 60) +
    geom_hline(yintercept = 1, linetype = "dashed", colour = "red", linewidth = 0.8) +
    geom_smooth(method = "loess", span = 0.5, colour = "orange",
                se = FALSE, linewidth = 1) +
    scale_x_log10(labels = label_comma()) +
    scale_y_log10(labels = label_comma()) +
    scale_fill_viridis_c(trans = "log10", name = "Methods") +
    labs(title = "Cognitive / Cyclomatic Ratio vs Cyclomatic Complexity",
         subtitle = "Above red line: cognitive complexity scores relatively higher than cyclomatic",
         x = "Cyclomatic Complexity (log)", y = "Cognitive / Cyclomatic Ratio (log)") +
    theme_minimal(base_size = 12)
  save_plot(p02, "02_cog_cc_ratio_vs_cc.png")
  
  # Methods where the two metrics strongly disagree
  df_disagree <- df %>%
    filter(!is.na(cog_ratio), cc >= 3) %>%
    mutate(
      agree_band = case_when(
        cog_ratio < 0.5  ~ "Cyclomatic much higher",
        cog_ratio < 0.8  ~ "Cyclomatic slightly higher",
        cog_ratio <= 1.2 ~ "Roughly equal",
        cog_ratio <= 2.0 ~ "Cognitive slightly higher",
        TRUE             ~ "Cognitive much higher"
      ),
      agree_band = factor(agree_band, levels = c(
        "Cyclomatic much higher", "Cyclomatic slightly higher",
        "Roughly equal",
        "Cognitive slightly higher", "Cognitive much higher"))
    )
  
  agree_summary <- df_disagree %>%
    count(agree_band) %>%
    mutate(pct = round(100 * n / sum(n), 1))
  print(agree_summary)
  write_csv(agree_summary, file.path(OUT, "metric_agreement_summary.csv"))
  
  p03 <- ggplot(agree_summary, aes(x = agree_band, y = pct, fill = agree_band)) +
    geom_col(show.legend = FALSE) +
    geom_text(aes(label = paste0(pct, "%")), vjust = -0.4, size = 3.5) +
    scale_fill_manual(values = c(
      "Cyclomatic much higher"   = "#1f77b4",
      "Cyclomatic slightly higher" = "#aec7e8",
      "Roughly equal"            = "#98df8a",
      "Cognitive slightly higher" = "#ffbb78",
      "Cognitive much higher"    = "#d62728"
    )) +
    labs(title = "Agreement Between Cyclomatic and Cognitive Complexity",
         subtitle = "Methods with CC >= 3 only; ratio = cognitive / cyclomatic",
         x = NULL, y = "% of Methods") +
    theme_minimal(base_size = 12) +
    theme(axis.text.x = element_text(angle = 20, hjust = 1))
  save_plot(p03, "03_metric_agreement_bands.png", w = 9, h = 5)
  
  # What structural features predict high cognitive penalty?
  # cc_residual: how much cognitive EXCEEDS what cyclomatic predicts
  df_res <- df %>%
    filter(cc > 0, cognitive_complexity >= 0, !is.na(cc)) %>%
    mutate(cog_excess = cognitive_complexity - cc)
  
  cat("\n-- Cognitive excess (cognitive - cyclomatic) summary --\n")
  cat(sprintf("  Mean excess:   %.2f\n",   mean(df_res$cog_excess)))
  cat(sprintf("  Median excess: %.2f\n", median(df_res$cog_excess)))
  cat(sprintf("  %% where cognitive > cyclomatic: %.1f%%\n",
              100 * mean(df_res$cog_excess > 0)))
  
  write_csv(
    df_res %>%
      summarise(mean_excess   = mean(cog_excess),
                median_excess = median(cog_excess),
                pct_cog_wins  = 100 * mean(cog_excess > 0)),
    file.path(OUT, "cognitive_excess_summary.csv")
  )
  
  # Excess by nesting: does deep nesting drive cognitive penalty?
  if (has_nesting) {
    p04 <- ggplot(df_res %>% filter(max_nesting <= 15) %>%
                    sample_frac(min(1, 100000 / nrow(.))),
                  aes(x = factor(max_nesting), y = cog_excess)) +
      geom_boxplot(fill = "#9467bd", alpha = 0.6,
                   outlier.size = 0.5, outlier.alpha = 0.3) +
      geom_hline(yintercept = 0, linetype = "dashed", colour = "red") +
      labs(title = "Cognitive Excess (Cognitive - Cyclomatic) by Max Nesting Depth",
           subtitle = "Positive = cognitive penalises more; driven by nesting penalty in cognitive spec",
           x = "Max Nesting Depth", y = "Cognitive - Cyclomatic") +
      theme_minimal(base_size = 12)
    save_plot(p04, "04_cog_excess_by_nesting.png")
  }
}

# =============================================================================
# 4. COMPLEXITY METRIC DISTRIBUTIONS (density overlays, comparable scale)
# =============================================================================

# Overlay normalised density for cc, cognitive, loc on the same plot so you
# can visually compare their shape/spread

if (has_cognitive && has_loc) {
  
  overlay_df <- df %>%
    select(cc, cognitive_complexity, loc) %>%
    drop_na() %>%
    filter(cc > 0, cognitive_complexity >= 0, loc > 0) %>%
    pivot_longer(everything(), names_to = "metric", values_to = "value") %>%
    mutate(metric = recode(metric,
                           cc                   = "Cyclomatic",
                           cognitive_complexity = "Cognitive",
                           loc                  = "LOC (NBNC)"
    ))
  
  p05 <- ggplot(overlay_df %>% filter(value > 0),
                aes(x = value, colour = metric, fill = metric)) +
    geom_density(alpha = 0.15, linewidth = 0.9, adjust = 1.5) +
    scale_x_log10(labels = label_comma()) +
    scale_colour_manual(values = c("Cyclomatic" = "#1f77b4",
                                   "Cognitive"  = "#9467bd",
                                   "LOC (NBNC)" = "#e377c2")) +
    scale_fill_manual(values = c("Cyclomatic" = "#1f77b4",
                                 "Cognitive"  = "#9467bd",
                                 "LOC (NBNC)" = "#e377c2")) +
    labs(title = "Density Comparison: Cyclomatic, Cognitive, and LOC",
         subtitle = "Log scale; curves normalised to density so shape is comparable",
         x = "Value (log scale)", y = "Density", colour = NULL, fill = NULL) +
    theme_minimal(base_size = 12) +
    theme(legend.position = "top")
  save_plot(p05, "05_metric_density_overlay.png")
}

# =============================================================================
# 5. WHAT DRIVES HIGH CYCLOMATIC COMPLEXITY?
#    Partial correlation / regression decomposition
# =============================================================================

# We want to know: given LOC, nesting, and identifier quality — how much of
# CC variance do each explain independently?

if (has_loc && has_nesting && has_id) {
  
  cat("\n-- Linear model: log(CC) ~ log(LOC) + max_nesting + avg_id_words + abbreviated_ratio --\n")
  
  df_lm <- df %>%
    filter(cc > 0, loc > 0, !is.na(max_nesting), !is.na(avg_id_words),
           !is.na(abbreviated_ratio)) %>%
    mutate(log_cc  = log(cc),
           log_loc = log(loc))
  
  lm_full <- lm(log_cc ~ log_loc + max_nesting + avg_id_words + abbreviated_ratio,
                data = df_lm)
  cat(sprintf("  Full model R^2: %.4f\n", summary(lm_full)$r.squared))
  print(tidy(lm_full))
  write_csv(tidy(lm_full), file.path(OUT, "lm_cc_predictors.csv"))
  
  # Incremental R^2: how much does each predictor add beyond the others?
  lm_loc_only    <- lm(log_cc ~ log_loc,                                        data = df_lm)
  lm_nesting     <- lm(log_cc ~ log_loc + max_nesting,                          data = df_lm)
  lm_id          <- lm(log_cc ~ log_loc + max_nesting + avg_id_words,           data = df_lm)
  lm_abbrev      <- lm(log_cc ~ log_loc + max_nesting + avg_id_words + abbreviated_ratio, data = df_lm)
  
  r2_steps <- tibble(
    model     = c("LOC only", "+ max nesting", "+ avg ID words", "+ abbrev ratio"),
    r_squared = c(
      summary(lm_loc_only)$r.squared,
      summary(lm_nesting)$r.squared,
      summary(lm_id)$r.squared,
      summary(lm_abbrev)$r.squared
    )
  ) %>% mutate(incremental_r2 = r_squared - lag(r_squared, default = 0))
  
  cat("\n-- Incremental R^2 by predictor --\n")
  print(r2_steps)
  write_csv(r2_steps, file.path(OUT, "incremental_r2.csv"))
  
  p06 <- ggplot(r2_steps, aes(x = model, y = incremental_r2, fill = model)) +
    geom_col(show.legend = FALSE) +
    geom_text(aes(label = sprintf("+%.3f", incremental_r2)), vjust = -0.4, size = 3.5) +
    scale_x_discrete(limits = r2_steps$model) +
    labs(title = "Incremental R² Added by Each Predictor of log(CC)",
         subtitle = "Each bar = unique variance explained beyond predictors to its left",
         x = NULL, y = "Incremental R²") +
    theme_minimal(base_size = 12)
  save_plot(p06, "06_incremental_r2.png", w = 8, h = 5)
}

# =============================================================================
# 6. NESTING VS COMPLEXITY METRICS
# =============================================================================

if (has_nesting) {
  
  # Does max nesting predict cognitive better than cyclomatic?
  # (Expected yes, because cognitive explicitly penalises nesting)
  if (has_cognitive) {
    r_cc_nest  <- cor(df$cc,                   df$max_nesting, use = "complete.obs")
    r_cog_nest <- cor(df$cognitive_complexity, df$max_nesting, use = "complete.obs")
    cat(sprintf("\nCorrelation max_nesting vs CC:        %.4f\n", r_cc_nest))
    cat(sprintf(  "Correlation max_nesting vs Cognitive: %.4f\n", r_cog_nest))
    
    nest_pivot <- df %>%
      filter(!is.na(max_nesting), !is.na(cognitive_complexity)) %>%
      select(max_nesting, cc, cognitive_complexity) %>%
      pivot_longer(c(cc, cognitive_complexity),
                   names_to = "metric", values_to = "value") %>%
      mutate(metric = recode(metric,
                             cc                   = "Cyclomatic",
                             cognitive_complexity = "Cognitive"
      )) %>%
      filter(value > 0)
    
    p07 <- ggplot(nest_pivot %>% sample_frac(min(1, 100000 / nrow(.))),
                  aes(x = max_nesting + 1, y = value, colour = metric)) +
      geom_smooth(method = "lm", se = TRUE, linewidth = 1.1) +
      scale_x_log10(labels = label_comma()) +
      scale_y_log10(labels = label_comma()) +
      scale_colour_manual(values = c("Cyclomatic" = "#1f77b4",
                                     "Cognitive"  = "#9467bd")) +
      annotate("text", x = Inf, y = Inf,
               label = sprintf("r(CC) = %.3f\nr(Cog) = %.3f", r_cc_nest, r_cog_nest),
               hjust = 1.1, vjust = 1.5, size = 3.5, family = "mono") +
      labs(title = "Nesting Depth vs Cyclomatic and Cognitive Complexity",
           subtitle = "Cognitive should correlate more strongly with nesting by design",
           x = "Max Nesting Depth + 1 (log)", y = "Complexity Score (log)",
           colour = NULL) +
      theme_minimal(base_size = 12) +
      theme(legend.position = "top")
    save_plot(p07, "07_nesting_vs_both_metrics.png")
  }
  
  # Nesting profile: how is nesting depth distributed across risk bands?
  p08 <- ggplot(df %>% filter(!is.na(max_nesting)),
                aes(x = max_nesting, y = risk_band, fill = risk_band)) +
    geom_density_ridges(alpha = 0.7, scale = 1.3, rel_min_height = 0.01) +
    scale_fill_manual(values = BAND_COLOURS) +
    scale_x_continuous(breaks = 0:20, limits = c(0, 20)) +
    labs(title = "Max Nesting Depth Distribution by CC Risk Band",
         x = "Max Nesting Depth", y = "CC Risk Band") +
    theme_minimal(base_size = 12) +
    theme(legend.position = "none")
  save_plot(p08, "08_nesting_ridgeline_by_cc_band.png", w = 9, h = 6)
}

# =============================================================================
# 7. NAMING QUALITY & COMPLEXITY
# =============================================================================

if (has_id) {
  
  # 7a. Is identifier quality a function of complexity or just of method length?
  # We compare avg_id_words and abbreviated_ratio controlling for LOC
  
  if (has_loc) {
    
    cat("\n-- Naming quality controlling for LOC --\n")
    
    df_nam <- df %>%
      filter(loc > 0, !is.na(avg_id_words), !is.na(abbreviated_ratio)) %>%
      mutate(log_loc = log(loc))
    
    lm_idwords <- lm(avg_id_words      ~ log_loc + cc, data = df_nam)
    lm_abbrev  <- lm(abbreviated_ratio ~ log_loc + cc, data = df_nam)
    
    cat("avg_id_words ~ log(LOC) + CC:\n")
    print(tidy(lm_idwords))
    cat("\nabbreviated_ratio ~ log(LOC) + CC:\n")
    print(tidy(lm_abbrev))
    
    write_csv(tidy(lm_idwords), file.path(OUT, "lm_id_words_vs_loc_cc.csv"))
    write_csv(tidy(lm_abbrev),  file.path(OUT, "lm_abbrev_vs_loc_cc.csv"))
  }
  
  # 7b. Does naming quality differ between the structural complexity profiles?
  # Split on high/low nesting AND high/low CC to get 4 quadrants
  
  if (has_nesting && has_loc) {
    med_cc   <- median(df$cc,          na.rm = TRUE)
    med_nest <- median(df$max_nesting, na.rm = TRUE)
    
    df_quad <- df %>%
      filter(!is.na(max_nesting), !is.na(naming_score)) %>%
      mutate(
        cc_level   = ifelse(cc          > med_cc,   "High CC",   "Low CC"),
        nest_level = ifelse(max_nesting > med_nest, "Deep Nest", "Shallow Nest"),
        quadrant   = paste(cc_level, "/", nest_level)
      )
    
    quad_summary <- df_quad %>%
      group_by(quadrant) %>%
      summarise(
        n               = n(),
        median_naming   = median(naming_score,    na.rm = TRUE),
        median_abbrev   = median(abbreviated_ratio, na.rm = TRUE),
        median_idwords  = median(avg_id_words,    na.rm = TRUE),
        .groups = "drop"
      )
    cat("\n-- Naming quality by CC x Nesting quadrant --\n")
    print(quad_summary)
    write_csv(quad_summary, file.path(OUT, "naming_by_cc_nesting_quadrant.csv"))
    
    p09 <- ggplot(df_quad, aes(x = quadrant, y = naming_score, fill = quadrant)) +
      geom_violin(alpha = 0.4, trim = TRUE) +
      geom_boxplot(width = 0.12, outlier.size = 0.3, outlier.alpha = 0.15, alpha = 0.9) +
      geom_text(data = quad_summary,
                aes(x = quadrant, y = median_naming,
                    label = sprintf("med=%.2f", median_naming)),
                vjust = -0.8, size = 3, inherit.aes = FALSE) +
      labs(title = "Naming Quality Score by Structural Complexity Quadrant",
           subtitle = sprintf("Split at median CC=%g, median max_nesting=%g", med_cc, med_nest),
           x = NULL, y = "Naming Score (avg_id_words * (1 - abbrev_ratio))") +
      theme_minimal(base_size = 12) +
      theme(legend.position = "none",
            axis.text.x = element_text(angle = 15, hjust = 1))
    save_plot(p09, "09_naming_by_cc_nesting_quadrant.png", w = 9, h = 6)
  }
  
  # 7c. Single-letter ID rate: does it track with complexity?
  r_single_cc <- cor(df$cc, df$single_letter_ids, use = "complete.obs")
  cat(sprintf("\nCorrelation CC vs single_letter_ids: %.4f\n", r_single_cc))
  
  p10 <- ggplot(df %>% filter(!is.na(risk_band)),
                aes(x = risk_band, y = single_letter_ids + 1, fill = risk_band)) +
    geom_violin(alpha = 0.4, trim = TRUE) +
    geom_boxplot(width = 0.12, outlier.size = 0.3, outlier.alpha = 0.15, alpha = 0.9) +
    scale_fill_manual(values = BAND_COLOURS) +
    scale_y_log10(labels = label_comma()) +
    labs(title = "Single-Letter Identifier Count by CC Risk Band",
         subtitle = sprintf("r(CC, single_letter_ids) = %.3f", r_single_cc),
         x = "CC Risk Band", y = "Single-letter IDs + 1 (log scale)") +
    theme_minimal(base_size = 12) +
    theme(legend.position = "none")
  save_plot(p10, "10_single_letter_ids_by_cc_band.png", w = 8, h = 5)
}

# =============================================================================
# 8. COMMENT BEHAVIOUR
# =============================================================================

if (has_comments) {
  
  # 8a. Do developers comment more complex methods?
  # Wilcoxon: CC distribution for commented vs uncommented methods
  wtest <- wilcox.test(cc ~ has_comments, data = df)
  cat(sprintf("\nWilcoxon CC ~ has_comments: W=%.0f, p=%.4e\n",
              wtest$statistic, wtest$p.value))
  
  med_commented   <- median(df$cc[df$has_comments],  na.rm = TRUE)
  med_uncommented <- median(df$cc[!df$has_comments], na.rm = TRUE)
  cat(sprintf("  Median CC (commented):   %.1f\n", med_commented))
  cat(sprintf("  Median CC (uncommented): %.1f\n", med_uncommented))
  
  p11 <- ggplot(df, aes(x = cc, fill = has_comments, colour = has_comments)) +
    geom_density(alpha = 0.3, adjust = 1.5, linewidth = 0.9) +
    scale_x_log10(labels = label_comma()) +
    scale_fill_manual(values  = c("TRUE" = "#2ca02c", "FALSE" = "#d62728"),
                      labels  = c("TRUE" = "Has comments", "FALSE" = "No comments")) +
    scale_colour_manual(values = c("TRUE" = "#2ca02c", "FALSE" = "#d62728"),
                        labels = c("TRUE" = "Has comments", "FALSE" = "No comments")) +
    annotate("text", x = Inf, y = Inf,
             label = sprintf("Wilcoxon p = %.2e\nmed(commented)=%.0f\nmed(uncommented)=%.0f",
                             wtest$p.value, med_commented, med_uncommented),
             hjust = 1.05, vjust = 1.4, size = 3.2, family = "mono") +
    labs(title = "CC Density: Methods With vs Without Comments",
         subtitle = "Are higher-complexity methods more likely to be commented?",
         x = "Cyclomatic Complexity (log scale)", y = "Density",
         fill = NULL, colour = NULL) +
    theme_minimal(base_size = 12) +
    theme(legend.position = "top")
  save_plot(p11, "11_cc_density_comment_presence.png")
  
  # 8b. Comment density vs complexity risk band
  # (are dense comments a signal of complex code, or just verbose style?)
  if (has_loc) {
    p12 <- ggplot(df %>% filter(!is.na(comment_density), comment_density > 0,
                                !is.na(risk_band)),
                  aes(x = risk_band, y = comment_density, fill = risk_band)) +
      geom_violin(alpha = 0.4, trim = TRUE) +
      geom_boxplot(width = 0.12, outlier.size = 0.3, outlier.alpha = 0.15) +
      scale_fill_manual(values = BAND_COLOURS) +
      scale_y_log10(labels = label_comma()) +
      labs(title = "Comment Density (Comment Words / LOC) by CC Risk Band",
           subtitle = "Methods with at least 1 comment word only",
           x = "CC Risk Band", y = "Comment Words / LOC (log scale)") +
      theme_minimal(base_size = 12) +
      theme(legend.position = "none")
    save_plot(p12, "12_comment_density_by_cc_band.png", w = 8, h = 5)
  }
  
  # 8c. Comment rate by risk band (what % of methods in each band have comments?)
  comment_rate <- df %>%
    filter(!is.na(risk_band)) %>%
    group_by(risk_band) %>%
    summarise(
      n           = n(),
      pct_commented = round(100 * mean(has_comments), 1),
      .groups = "drop"
    )
  cat("\n-- Comment rate by CC risk band --\n")
  print(comment_rate)
  write_csv(comment_rate, file.path(OUT, "comment_rate_by_cc_band.csv"))
  
  p13 <- ggplot(comment_rate, aes(x = risk_band, y = pct_commented, fill = risk_band)) +
    geom_col(show.legend = FALSE) +
    geom_text(aes(label = paste0(pct_commented, "%")), vjust = -0.4, size = 3.5) +
    scale_fill_manual(values = BAND_COLOURS) +
    labs(title = "% of Methods With Comments by CC Risk Band",
         subtitle = "Indicates whether developers comment complex code more frequently",
         x = "CC Risk Band", y = "% Methods With Comments") +
    theme_minimal(base_size = 12) +
    coord_cartesian(ylim = c(0, max(comment_rate$pct_commented) * 1.15))
  save_plot(p13, "13_comment_rate_by_cc_band.png", w = 7, h = 5)
}

# =============================================================================
# 9. PROJECT-LEVEL ANALYSIS
# =============================================================================

project_stats <- df %>%
  group_by(project) %>%
  summarise(
    n_methods        = n(),
    median_cc        = median(cc),
    mean_cc          = mean(cc),
    sd_cc            = sd(cc),
    max_cc           = max(cc),
    pct_high_cc      = 100 * mean(cc > 10),
    median_cognitive = if (has_cognitive) median(cognitive_complexity, na.rm = TRUE) else NA,
    median_loc       = if (has_loc)       median(loc,                  na.rm = TRUE) else NA,
    median_nesting   = if (has_nesting)   median(max_nesting,          na.rm = TRUE) else NA,
    pct_commented    = if (has_comments)  100 * mean(has_comments,     na.rm = TRUE) else NA,
    .groups = "drop"
  )

write_csv(project_stats, file.path(OUT, "project_summary.csv"))

# If repos.csv is present, join for richer project plots
if (has_repos) {
  project_stats <- project_stats %>%
    left_join(repos %>% select(project, stars, forks, commit_count,
                               size_kb, java_file_count),
              by = "project")
  
  # Does repo maturity (commits, stars) predict typical complexity?
  if (all(c("commit_count", "stars") %in% names(project_stats))) {
    
    p14 <- project_stats %>%
      filter(!is.na(commit_count), commit_count > 0) %>%
      ggplot(aes(x = commit_count, y = median_cc, size = n_methods,
                 colour = pct_high_cc)) +
      geom_point(alpha = 0.7) +
      geom_smooth(method = "lm", se = TRUE, colour = "orange",
                  linewidth = 0.9, inherit.aes = FALSE,
                  aes(x = commit_count, y = median_cc)) +
      scale_x_log10(labels = label_comma()) +
      scale_size_continuous(name = "Methods in repo", range = c(2, 8)) +
      scale_colour_viridis_c(name = "% CC > 10") +
      labs(title = "Repo Commit Count vs Median Cyclomatic Complexity",
           subtitle = "Size = number of methods; colour = % methods with CC > 10",
           x = "Commit Count (log scale)", y = "Median CC") +
      theme_minimal(base_size = 12)
    save_plot(p14, "14_commits_vs_median_cc.png")
    
    r_commits_cc <- cor(log(project_stats$commit_count[project_stats$commit_count > 0]),
                        project_stats$median_cc[project_stats$commit_count > 0],
                        use = "complete.obs")
    cat(sprintf("\nCorrelation log(commits) vs median project CC: %.4f\n", r_commits_cc))
  }
  
  # Project size (java_file_count) vs complexity spread
  if ("java_file_count" %in% names(project_stats)) {
    p15 <- project_stats %>%
      filter(!is.na(java_file_count), java_file_count > 0) %>%
      ggplot(aes(x = java_file_count, y = sd_cc, colour = median_cc)) +
      geom_point(alpha = 0.75, size = 2.5) +
      geom_smooth(method = "lm", se = TRUE, colour = "orange",
                  linewidth = 0.9, inherit.aes = FALSE,
                  aes(x = java_file_count, y = sd_cc)) +
      scale_x_log10(labels = label_comma()) +
      scale_colour_viridis_c(name = "Median CC") +
      labs(title = "Project Size (Java Files) vs Complexity Spread (SD of CC)",
           subtitle = "Do larger projects have more variance in method complexity?",
           x = "Java File Count (log scale)", y = "SD of CC") +
      theme_minimal(base_size = 12)
    save_plot(p15, "15_project_size_vs_cc_spread.png")
  }
}

# Project-level complexity profile: show the 20 highest and lowest median CC projects
top_bottom <- bind_rows(
  project_stats %>% slice_max(median_cc, n = 20) %>% mutate(group = "Highest CC"),
  project_stats %>% slice_min(median_cc, n = 20) %>% mutate(group = "Lowest CC")
) %>%
  mutate(project_short = str_extract(project, "[^/]+$"))

p16 <- ggplot(top_bottom,
              aes(x = reorder(project_short, median_cc), y = median_cc,
                  fill = group)) +
  geom_col(show.legend = FALSE) +
  geom_errorbar(aes(ymin = median_cc - sd_cc / sqrt(n_methods),
                    ymax = median_cc + sd_cc / sqrt(n_methods)),
                width = 0.4, colour = "grey40") +
  facet_wrap(~ group, scales = "free_y") +
  coord_flip() +
  scale_fill_manual(values = c("Highest CC" = "#d62728", "Lowest CC" = "#2ca02c")) +
  labs(title = "Top and Bottom 20 Projects by Median Cyclomatic Complexity",
       x = NULL, y = "Median CC (error bars = SE)") +
  theme_minimal(base_size = 10)
save_plot(p16, "16_top_bottom_projects_cc.png", w = 12, h = 8)

# =============================================================================
# 10. LOC EFFICIENCY: COMPLEXITY PER LINE
# =============================================================================

if (has_loc) {
  
  df <- df %>%
    mutate(cc_per_loc = ifelse(loc > 0, cc / loc, NA_real_))
  
  cat("\n-- CC per LOC summary --\n")
  cat(sprintf("  Mean:   %.4f\n", mean(df$cc_per_loc, na.rm = TRUE)))
  cat(sprintf("  Median: %.4f\n", median(df$cc_per_loc, na.rm = TRUE)))
  
  # High cc_per_loc = dense complexity (short methods that pack in many branches)
  # Low  cc_per_loc = spread complexity (long methods with relatively few branches)
  p17 <- ggplot(df %>% filter(!is.na(cc_per_loc), cc_per_loc > 0),
                aes(x = cc_per_loc)) +
    geom_histogram(bins = 60, fill = "#1f77b4", colour = "white", linewidth = 0.2) +
    geom_vline(xintercept = median(df$cc_per_loc, na.rm = TRUE),
               linetype = "dashed", colour = "red", linewidth = 0.8) +
    scale_x_log10(labels = label_number(accuracy = 0.01)) +
    scale_y_log10(labels = label_comma()) +
    labs(title = "Cyclomatic Complexity per Line of Code",
         subtitle = "High = short methods densely packed with branches; red = median",
         x = "CC / LOC (log scale)", y = "Method Count (log scale)") +
    theme_minimal(base_size = 12)
  save_plot(p17, "17_cc_per_loc_histogram.png")
  
  # Physical vs NBNC LOC ratio (blank/comment ratio as a style proxy)
  if ("loc_physical" %in% names(df)) {
    p18 <- ggplot(df %>% filter(!is.na(blank_ratio), blank_ratio >= 0,
                                !is.na(risk_band)),
                  aes(x = risk_band, y = blank_ratio, fill = risk_band)) +
      geom_violin(alpha = 0.4, trim = TRUE) +
      geom_boxplot(width = 0.12, outlier.size = 0.3, outlier.alpha = 0.15) +
      scale_fill_manual(values = BAND_COLOURS) +
      scale_y_continuous(labels = percent_format()) +
      labs(title = "Blank/Comment Line Ratio by CC Risk Band",
           subtitle = "(physical LOC - NBNC LOC) / physical LOC",
           x = "CC Risk Band", y = "Blank + Comment Line Fraction") +
      theme_minimal(base_size = 12) +
      theme(legend.position = "none")
    save_plot(p18, "18_blank_ratio_by_cc_band.png", w = 8, h = 5)
  }
}

# =============================================================================
# 11. STRUCTURAL FINGERPRINTS: METRIC PROFILES PER RISK BAND
# =============================================================================

# Radar-style summary: for each risk band, what is the typical value of each
# metric expressed as a percentile rank of the overall distribution?

profile_metrics <- intersect(
  c("loc", "avg_nesting", "max_nesting", "avg_id_words",
    "abbreviated_ratio", "comment_density", "word_density"),
  names(df)
)

if (length(profile_metrics) >= 3) {
  
  band_profiles <- df %>%
    filter(!is.na(risk_band)) %>%
    group_by(risk_band) %>%
    summarise(across(all_of(profile_metrics), ~ median(.x, na.rm = TRUE)),
              .groups = "drop")
  
  # Normalise each metric to [0,1] for comparability
  band_profiles_norm <- band_profiles %>%
    mutate(across(all_of(profile_metrics), ~ {
      r <- range(.x, na.rm = TRUE)
      if (diff(r) == 0) .x else (.x - r[1]) / diff(r)
    }))
  
  band_long <- band_profiles_norm %>%
    pivot_longer(-risk_band, names_to = "metric", values_to = "norm_value") %>%
    mutate(metric = recode(metric,
                           loc               = "LOC",
                           avg_nesting       = "Avg Nesting",
                           max_nesting       = "Max Nesting",
                           avg_id_words      = "Avg ID Words",
                           abbreviated_ratio = "Abbrev Ratio",
                           comment_density   = "Comment Density",
                           word_density      = "Word Density"
    ))
  
  p19 <- ggplot(band_long, aes(x = metric, y = norm_value,
                               colour = risk_band, group = risk_band)) +
    geom_line(linewidth = 1) +
    geom_point(size = 2.5) +
    scale_colour_manual(values = BAND_COLOURS) +
    scale_y_continuous(labels = percent_format(), limits = c(0, 1)) +
    labs(title = "Structural Fingerprint of Each CC Risk Band",
         subtitle = "Median of each metric, normalised 0-1 across bands; higher = relatively more",
         x = NULL, y = "Normalised Median Value", colour = "CC Band") +
    theme_minimal(base_size = 12) +
    theme(axis.text.x = element_text(angle = 20, hjust = 1),
          legend.position = "top")
  save_plot(p19, "19_risk_band_structural_fingerprint.png", w = 9, h = 6)
  
  # Raw medians table for reference
  write_csv(band_profiles, file.path(OUT, "band_metric_profiles.csv"))
}

# =============================================================================
# 12. SKEWNESS & DISTRIBUTIONAL SHAPE COMPARISON
# =============================================================================

shape_cols <- intersect(
  c("cc", "cognitive_complexity", "loc", "max_nesting",
    "avg_id_words", "abbreviated_ratio", "comment_words"),
  names(df)
)

shape_stats <- map_dfr(shape_cols, function(col) {
  x <- df[[col]][!is.na(df[[col]]) & df[[col]] > 0]
  tibble(
    metric      = col,
    skewness    = skewness(x),
    kurtosis    = kurtosis(x),
    cv          = sd(x) / mean(x),   # coefficient of variation
    gini        = {
      xs <- sort(x)
      n  <- length(xs)
      2 * sum(seq_len(n) * xs) / (n * sum(xs)) - (n + 1) / n
    }
  )
}) %>% arrange(desc(skewness))

cat("\n-- Distributional Shape Statistics --\n")
print(shape_stats)
write_csv(shape_stats, file.path(OUT, "distributional_shape.csv"))

p20 <- shape_stats %>%
  mutate(metric = recode(metric, !!!nice_names)) %>%
  ggplot(aes(x = reorder(metric, skewness), y = skewness, fill = skewness > 0)) +
  geom_col(show.legend = FALSE) +
  geom_text(aes(label = sprintf("%.1f", skewness),
                hjust = ifelse(skewness >= 0, -0.1, 1.1)), size = 3.5) +
  coord_flip() +
  scale_fill_manual(values = c("TRUE" = "#d62728", "FALSE" = "#1f77b4")) +
  labs(title = "Skewness of Each Complexity Metric",
       subtitle = "All metrics are expected to be right-skewed; more skew = heavier tail",
       x = NULL, y = "Skewness") +
  theme_minimal(base_size = 12) +
  expand_limits(y = max(shape_stats$skewness) * 1.15)
save_plot(p20, "20_metric_skewness_comparison.png", w = 8, h = 5)

# =============================================================================
# 13. NORMALITY TESTS
# =============================================================================

cat("\n-- Normality Tests (Shapiro-Wilk on 5000-sample, KS vs log-normal fit) --\n")

norm_results <- map_dfr(intersect(c("cc", "cognitive_complexity", "loc"), names(df)),
                        function(col) {
                          x <- df[[col]][!is.na(df[[col]]) & df[[col]] > 0]
                          sw_s <- sample(x, min(5000, length(x)))
                          sw   <- shapiro.test(sw_s)
                          ks   <- ks.test(x, "plnorm",
                                          meanlog = mean(log(x)), sdlog = sd(log(x)))
                          tibble(
                            metric     = col,
                            sw_W       = sw$statistic,
                            sw_p       = sw$p.value,
                            ks_D       = ks$statistic,
                            ks_p       = ks$p.value
                          )
                        }
)

print(norm_results)
write_csv(norm_results, file.path(OUT, "normality_tests.csv"))

# =============================================================================
# 14. SUMMARY REPORT
# =============================================================================

report <- c(
  "# Complexity Analysis Summary",
  sprintf("Generated: %s", Sys.time()),
  sprintf("Methods:   %d", n),
  sprintf("Projects:  %d", n_proj),
  "",
  "## Key Statistics",
  sprintf("  Cyclomatic:  median=%g, mean=%.2f, SD=%.2f",
          median(df$cc), mean(df$cc), sd(df$cc)),
  if (has_cognitive) sprintf(
    "  Cognitive:   median=%g, mean=%.2f, SD=%.2f",
    median(df$cognitive_complexity, na.rm = TRUE),
    mean(df$cognitive_complexity, na.rm = TRUE),
    sd(df$cognitive_complexity, na.rm = TRUE)),
  if (has_loc) sprintf(
    "  LOC (NBNC):  median=%g, mean=%.2f, SD=%.2f",
    median(df$loc, na.rm = TRUE),
    mean(df$loc, na.rm = TRUE),
    sd(df$loc, na.rm = TRUE)),
  "",
  "## Metric Correlations (with CC)",
  if (has_cognitive) sprintf(
    "  CC vs Cognitive:    r=%.3f",
    cor(df$cc, df$cognitive_complexity, use = "complete.obs")),
  if (has_loc) sprintf(
    "  CC vs LOC:          r=%.3f",
    cor(df$cc, df$loc, use = "complete.obs")),
  if (has_nesting) sprintf(
    "  CC vs max_nesting:  r=%.3f",
    cor(df$cc, df$max_nesting, use = "complete.obs")),
  if (has_id) sprintf(
    "  CC vs naming_score: r=%.3f",
    cor(df$cc, df$naming_score, use = "complete.obs")),
  "",
  "## Risk Band Distribution",
  paste(
    apply(
      df %>% count(risk_band) %>%
        mutate(pct = round(100 * n / sum(n), 1)),
      1, function(r) sprintf("  CC %s: %s%%", r["risk_band"], r["pct"])
    ),
    collapse = "\n"
  )
)

writeLines(report[!sapply(report, is.null)],
           file.path(OUT, "summary_report.txt"))

cat("\nDone. Output written to:", OUT, "\n")