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
#   total_words, comment_count, comment_words,
#   halstead_volume, halstead_difficulty, halstead_effort,
#   maintainability_index, mi_normalized,
#   param_count, return_count, fan_out,
#   max_line_length, avg_line_length
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
library(GGally)
library(ggridges)
library(broom)

# =============================================================================
# 0. CONFIG
# =============================================================================

# Inputs (produced by the Java program) and all generated CSV tables live in
# data_tables/; every generated plot lives under graphs/.
DATA_DIR   <- "data_tables"
GRAPHS_DIR <- "graphs"

CC_FILE    <- file.path(DATA_DIR, "cc_data.csv")
REPOS_FILE <- file.path(DATA_DIR, "repos.csv")

DIR_DIST    <- file.path(GRAPHS_DIR, "01_distributions")
DIR_CORR    <- file.path(GRAPHS_DIR, "02_correlations")
DIR_BANDS   <- file.path(GRAPHS_DIR, "03_risk_bands")
DIR_PROJ    <- file.path(GRAPHS_DIR, "04_projects")
DIR_CCVCOG  <- file.path(GRAPHS_DIR, "06_cc_vs_cognitive")
DIR_NESTING <- file.path(GRAPHS_DIR, "07_nesting_drivers")
DIR_LOC     <- file.path(GRAPHS_DIR, "08_loc_vs_complexity")
DIR_MODEL   <- file.path(GRAPHS_DIR, "09_modelling")

# every write_csv() target — all tables collected in one flat folder
DIR_TABLES  <- DATA_DIR

for (d in c(DATA_DIR, GRAPHS_DIR, DIR_DIST, DIR_CORR, DIR_BANDS, DIR_PROJ,
            DIR_TABLES, DIR_CCVCOG, DIR_NESTING, DIR_LOC, DIR_MODEL)) {
  dir.create(d, showWarnings = FALSE, recursive = TRUE)
}

BAND_BREAKS  <- c(5, 10, 15, 25)
BAND_LABELS  <- c("1-5", "6-10", "11-15", "16-25", "25+")
BAND_COLOURS <- c("#2ca02c", "#8fbc8f", "#ff7f0e", "#d62728", "#9467bd")
names(BAND_COLOURS) <- BAND_LABELS

# Graphics devices cap any single figure at 50,000px per side. At 150 dpi that
# is ~333in, so clamp every saved figure's dimensions well under that ceiling —
# otherwise a tall per-project chart aborts the whole script.
MAX_DIM_IN <- 320
sp <- function(p, dir, name, w = 9, h = 6) {
  w <- min(w, MAX_DIM_IN); h <- min(h, MAX_DIM_IN)
  suppressWarnings(ggsave(file.path(dir, name), p, width = w, height = h, dpi = 150, limitsize = FALSE))
  invisible(p)
}

# With thousands of repositories, per-project bar/box charts that list every
# project are unreadable AND large enough to blow past the device limit. Show
# only the most extreme projects, and derive a safe height from how many appear.
MAX_PROJ_BARS <- 60
proj_h <- function(k) min(40, max(6, k * 0.28 + 2))

# Top-k projects by a given summary column, plus a subtitle that says how many
# of the full set are shown.
top_projects <- function(stat_tbl, col, k = MAX_PROJ_BARS)
  stat_tbl %>% slice_max(.data[[col]], n = k, with_ties = FALSE) %>% pull(project)
proj_subtitle <- function(k_shown) {
  if (n_proj > k_shown) sprintf("Showing top %d of %d projects", k_shown, n_proj)
  else sprintf("All %d projects", n_proj)
}

# =============================================================================
# 1. LOAD & CLEAN
# =============================================================================

cat("Loading cc_data.csv...\n")
df_raw <- read_csv(CC_FILE, show_col_types = FALSE)

numeric_candidates <- c("cc", "cognitive_complexity", "loc", "loc_physical",
                        "avg_nesting", "max_nesting", "avg_id_words",
                        "abbreviated_ratio", "single_letter_ids", "longest_id",
                        "total_words", "comment_count", "comment_words",
                        "halstead_volume", "halstead_difficulty", "halstead_effort",
                        "maintainability_index", "mi_normalized",
                        "param_count", "return_count", "fan_out",
                        "max_line_length", "avg_line_length")
numeric_present <- intersect(numeric_candidates, names(df_raw))

df <- df_raw
for (col in numeric_present) df[[col]] <- as.numeric(unlist(df[[col]]))
df <- df %>% filter(!is.na(cc), cc >= 1)

has_loc      <- "loc"                  %in% names(df)
has_loc_phys <- "loc_physical"         %in% names(df)
has_cog      <- "cognitive_complexity" %in% names(df)
has_nest     <- all(c("avg_nesting", "max_nesting") %in% names(df))
has_id       <- all(c("avg_id_words", "abbreviated_ratio") %in% names(df))
has_comments <- all(c("comment_count", "comment_words") %in% names(df))

# derived columns — assigned directly to avoid dplyr if() evaluation issues
df$risk_band <- cut(df$cc, breaks = c(0, BAND_BREAKS, Inf), labels = BAND_LABELS, right = TRUE)
if (has_loc)      df$loc_band        <- ifelse(df$loc <= 24, "<=24 LOC", ">24 LOC")
if (has_comments) df$has_comment_flag <- df$comment_count > 0
if (has_comments && has_loc) df$comment_density <- ifelse(df$loc > 0, df$comment_words / df$loc, NA_real_)
if (has_loc && "total_words" %in% names(df)) df$word_density <- ifelse(df$loc > 0, df$total_words / df$loc, NA_real_)
if (has_id)       df$naming_score    <- df$avg_id_words * (1 - df$abbreviated_ratio)
if (has_cog)      df$cog_ratio       <- ifelse(df$cc > 0, df$cognitive_complexity / df$cc, NA_real_)
if (has_cog)      df$cog_excess      <- df$cognitive_complexity - df$cc
if (has_loc_phys && has_loc) df$blank_ratio <- ifelse(df$loc_physical > 0, (df$loc_physical - df$loc) / df$loc_physical, NA_real_)
if (has_loc)      df$cc_per_loc      <- ifelse(df$loc > 0, df$cc / df$loc, NA_real_)


repos <- if (file.exists(REPOS_FILE)) {
  read_csv(REPOS_FILE, show_col_types = FALSE) %>% rename(project = full_name)
} else {
  cat("Note: repos.csv not found. Project metadata skipped.\n")
  NULL
}

n      <- nrow(df)
n_proj <- n_distinct(df$project)
cat(sprintf("Loaded %d methods across %d projects.\n\n", n, n_proj))

# =============================================================================
# 2. DESCRIPTIVE STATISTICS  →  05_tables
# =============================================================================

cat("Computing descriptive statistics...\n")

stat_cols <- intersect(
  c("cc", "cognitive_complexity", "loc", "loc_physical",
    "avg_nesting", "max_nesting", "avg_id_words", "abbreviated_ratio",
    "single_letter_ids", "longest_id", "total_words",
    "comment_count", "comment_words",
    "halstead_volume", "halstead_difficulty", "halstead_effort",
    "maintainability_index", "mi_normalized",
    "param_count", "return_count", "fan_out",
    "max_line_length", "avg_line_length",
    "cc_per_loc", "cog_ratio", "cog_excess", "naming_score",
    "comment_density", "word_density", "blank_ratio"),
  names(df)
)

desc <- map_dfr(stat_cols, function(col) {
  x <- df[[col]][!is.na(df[[col]])]
  tibble(
    metric   = col,
    n        = length(x),
    min      = min(x),
    p5       = quantile(x, 0.05),
    q1       = quantile(x, 0.25),
    median   = median(x),
    mean     = mean(x),
    q3       = quantile(x, 0.75),
    p95      = quantile(x, 0.95),
    max      = max(x),
    sd       = sd(x),
    cv       = sd(x) / abs(mean(x)),
    skewness = skewness(x),
    kurtosis = kurtosis(x)
  )
})
print(desc, n = Inf)
write_csv(desc, file.path(DIR_TABLES, "descriptive_stats.csv"))

band_counts <- df %>%
  count(risk_band) %>%
  mutate(pct = round(100 * n / sum(n), 2))
write_csv(band_counts, file.path(DIR_TABLES, "risk_band_counts.csv"))

top50 <- df %>%
  select(project, class_name, method_name, cc,
         any_of(c("cognitive_complexity", "loc", "max_nesting"))) %>%
  arrange(desc(cc)) %>%
  slice_head(n = 50)
write_csv(top50, file.path(DIR_TABLES, "top50_complex_methods.csv"))

# =============================================================================
# 3. DISTRIBUTIONS  →  01_distributions
# =============================================================================

cat("Generating distribution plots...\n")

hist_linear <- function(data, col, fill_col, title, xlab) {
  x <- data[[col]][!is.na(data[[col]])]
  ggplot(data.frame(x = x), aes(x = x)) +
    geom_histogram(bins = 60, fill = fill_col, colour = "white", linewidth = 0.2) +
    labs(title = title, x = xlab, y = "Method Count") +
    theme_minimal(base_size = 12)
}

hist_loglog <- function(data, col, fill_col, title, xlab) {
  x <- data[[col]][!is.na(data[[col]]) & data[[col]] > 0]
  ggplot(data.frame(x = x), aes(x = x)) +
    geom_histogram(bins = 60, fill = fill_col, colour = "white", linewidth = 0.2) +
    scale_x_log10(labels = label_comma()) +
    scale_y_log10(labels = label_comma()) +
    labs(title = paste(title, "(log-log)"),
         x = paste(xlab, "(log scale)"), y = "Method Count (log scale)") +
    theme_minimal(base_size = 12)
}

ecdf_plot <- function(data, col, colour, title, xlab,
                      log_x = FALSE, vlines = NULL, vline_colours = NULL) {
  x <- data[[col]][!is.na(data[[col]]) & data[[col]] > 0]
  p <- ggplot(data.frame(x = x), aes(x = x)) +
    stat_ecdf(geom = "step", colour = colour, linewidth = 0.9) +
    scale_y_continuous(labels = percent_format()) +
    labs(title = paste("ECDF –", title),
         subtitle = "% of methods at or below each value",
         x = xlab, y = "Cumulative %") +
    theme_minimal(base_size = 12)
  if (log_x) p <- p + scale_x_log10(labels = label_comma())
  if (!is.null(vlines))
    for (i in seq_along(vlines))
      p <- p + geom_vline(xintercept = vlines[i], linetype = "dashed",
                          colour = vline_colours[i], linewidth = 0.6)
  p
}

# ── 3A. CYCLOMATIC COMPLEXITY ─────────────────────────────────────────────────

sp(hist_linear(df, "cc", "#1f77b4", "Cyclomatic Complexity Distribution", "CC"),
   DIR_DIST, "01a_cc_histogram_linear.png")
sp(hist_loglog(df, "cc", "#1f77b4", "Cyclomatic Complexity Distribution", "CC"),
   DIR_DIST, "01b_cc_histogram_loglog.png")
sp(ecdf_plot(df, "cc", "#1f77b4", "Cyclomatic Complexity", "CC",
             log_x = TRUE, vlines = BAND_BREAKS,
             vline_colours = BAND_COLOURS[-length(BAND_COLOURS)]),
   DIR_DIST, "01c_cc_ecdf.png")

# ── 3B. COGNITIVE COMPLEXITY ──────────────────────────────────────────────────

if (has_cog) {
  sp(hist_linear(df %>% filter(cognitive_complexity >= 0),
                 "cognitive_complexity", "#9467bd",
                 "Cognitive Complexity Distribution", "Cognitive Complexity"),
     DIR_DIST, "02a_cognitive_histogram_linear.png")
  sp(hist_loglog(df, "cognitive_complexity", "#9467bd",
                 "Cognitive Complexity Distribution", "Cognitive Complexity"),
     DIR_DIST, "02b_cognitive_histogram_loglog.png")
  sp(ecdf_plot(df, "cognitive_complexity", "#9467bd",
               "Cognitive Complexity", "Cognitive Complexity", log_x = TRUE),
     DIR_DIST, "02c_cognitive_ecdf.png")
  
  # overlay density: CC vs Cognitive
  overlay_df <- df %>%
    filter(cc > 0, cognitive_complexity > 0) %>%
    select(cc, cognitive_complexity) %>%
    pivot_longer(everything(), names_to = "metric", values_to = "value") %>%
    mutate(metric = recode(metric,
                           cc = "Cyclomatic", cognitive_complexity = "Cognitive"))
  
  p_overlay <- ggplot(overlay_df, aes(x = value, colour = metric, fill = metric)) +
    geom_density(alpha = 0.15, linewidth = 0.9, adjust = 1.5) +
    scale_x_log10(labels = label_comma()) +
    scale_colour_manual(values = c("Cyclomatic" = "#1f77b4", "Cognitive" = "#9467bd")) +
    scale_fill_manual(  values = c("Cyclomatic" = "#1f77b4", "Cognitive" = "#9467bd")) +
    labs(title = "Cyclomatic vs Cognitive Complexity — Density Overlay",
         subtitle = "Log scale — shows how the two metrics distribute relative to each other",
         x = "Complexity Score (log scale)", y = "Density",
         colour = NULL, fill = NULL) +
    theme_minimal(base_size = 12) + theme(legend.position = "top")
  sp(p_overlay, DIR_DIST, "02d_cc_vs_cognitive_density_overlay.png")
}

# ── 3C. LOC (NBNC) ────────────────────────────────────────────────────────────

if (has_loc) {
  sp(hist_linear(df, "loc", "#e377c2", "LOC (NBNC) Distribution", "Lines of Code"),
     DIR_DIST, "03a_loc_histogram_linear.png")
  sp(hist_loglog(df, "loc", "#e377c2", "LOC (NBNC) Distribution", "Lines of Code"),
     DIR_DIST, "03b_loc_histogram_loglog.png")
  sp(ecdf_plot(df, "loc", "#e377c2", "LOC (NBNC)", "Lines of Code",
               log_x = TRUE, vlines = 24, vline_colours = "red"),
     DIR_DIST, "03c_loc_ecdf.png")
}

# ── 3D. PHYSICAL LOC ─────────────────────────────────────────────────────────

if (has_loc_phys) {
  sp(hist_linear(df, "loc_physical", "#f7b6d2",
                 "Physical LOC Distribution", "Physical Lines of Code"),
     DIR_DIST, "04a_loc_physical_histogram_linear.png")
  sp(hist_loglog(df, "loc_physical", "#f7b6d2",
                 "Physical LOC Distribution", "Physical Lines of Code"),
     DIR_DIST, "04b_loc_physical_histogram_loglog.png")
  sp(ecdf_plot(df, "loc_physical", "#f7b6d2",
               "Physical LOC", "Physical Lines of Code", log_x = TRUE),
     DIR_DIST, "04c_loc_physical_ecdf.png")
}

# ── 3E. NESTING ───────────────────────────────────────────────────────────────

if (has_nest) {
  sp(hist_linear(df, "max_nesting", "#17becf",
                 "Max Nesting Depth Distribution", "Max Nesting Depth"),
     DIR_DIST, "05a_max_nesting_histogram_linear.png")
  sp(hist_loglog(df, "max_nesting", "#17becf",
                 "Max Nesting Depth Distribution", "Max Nesting Depth"),
     DIR_DIST, "05b_max_nesting_histogram_loglog.png")
  sp(ecdf_plot(df, "max_nesting", "#17becf",
               "Max Nesting Depth", "Max Nesting Depth"),
     DIR_DIST, "05c_max_nesting_ecdf.png")
  sp(hist_linear(df, "avg_nesting", "#9edae5",
                 "Average Nesting Depth Distribution", "Avg Nesting Depth"),
     DIR_DIST, "05d_avg_nesting_histogram_linear.png")
  sp(hist_loglog(df, "avg_nesting", "#9edae5",
                 "Average Nesting Depth Distribution", "Avg Nesting Depth"),
     DIR_DIST, "05e_avg_nesting_histogram_loglog.png")
}

# ── 3F. IDENTIFIER METRICS ────────────────────────────────────────────────────

if (has_id) {
  sp(hist_linear(df, "avg_id_words", "#e377c2",
                 "Avg Identifier Word Count Distribution", "Avg Words per Identifier"),
     DIR_DIST, "06a_avg_id_words_histogram_linear.png")
  sp(hist_loglog(df, "avg_id_words", "#e377c2",
                 "Avg Identifier Word Count Distribution", "Avg Words per Identifier"),
     DIR_DIST, "06b_avg_id_words_histogram_loglog.png")
  sp(ecdf_plot(df, "avg_id_words", "#e377c2",
               "Avg Identifier Word Count", "Avg Words per Identifier"),
     DIR_DIST, "06c_avg_id_words_ecdf.png")
  sp(hist_linear(df, "abbreviated_ratio", "#bcbd22",
                 "Abbreviated Identifier Ratio Distribution", "Abbreviated Ratio"),
     DIR_DIST, "07a_abbreviated_ratio_histogram_linear.png")
  sp(hist_loglog(df, "abbreviated_ratio", "#bcbd22",
                 "Abbreviated Identifier Ratio Distribution", "Abbreviated Ratio"),
     DIR_DIST, "07b_abbreviated_ratio_histogram_loglog.png")
  sp(hist_linear(df, "single_letter_ids", "#dbdb8d",
                 "Single-Letter Identifier Count Distribution", "Single-Letter ID Count"),
     DIR_DIST, "07c_single_letter_ids_histogram_linear.png")
  sp(hist_loglog(df, "single_letter_ids", "#dbdb8d",
                 "Single-Letter Identifier Count Distribution", "Single-Letter ID Count"),
     DIR_DIST, "07d_single_letter_ids_histogram_loglog.png")
  sp(hist_linear(df, "longest_id", "#8c6d31",
                 "Longest Identifier Length Distribution", "Characters"),
     DIR_DIST, "07e_longest_id_histogram_linear.png")
  sp(hist_loglog(df, "longest_id", "#8c6d31",
                 "Longest Identifier Length Distribution", "Characters"),
     DIR_DIST, "07f_longest_id_histogram_loglog.png")
}

# ── 3G. WORD COUNT ────────────────────────────────────────────────────────────

if ("total_words" %in% names(df)) {
  sp(hist_linear(df, "total_words", "#1f77b4",
                 "Total Word Count per Method", "Total Words"),
     DIR_DIST, "08a_total_words_histogram_linear.png")
  sp(hist_loglog(df, "total_words", "#1f77b4",
                 "Total Word Count per Method", "Total Words"),
     DIR_DIST, "08b_total_words_histogram_loglog.png")
}

# ── 3H. COMMENT METRICS ───────────────────────────────────────────────────────

if (has_comments) {
  sp(hist_linear(df, "comment_count", "#2ca02c",
                 "Comment Block Count per Method", "Comment Count"),
     DIR_DIST, "09a_comment_count_histogram_linear.png")
  sp(hist_loglog(df, "comment_count", "#2ca02c",
                 "Comment Block Count per Method", "Comment Count"),
     DIR_DIST, "09b_comment_count_histogram_loglog.png")
  sp(hist_linear(df, "comment_words", "#98df8a",
                 "Comment Word Count per Method", "Comment Words"),
     DIR_DIST, "09c_comment_words_histogram_linear.png")
  sp(hist_loglog(df, "comment_words", "#98df8a",
                 "Comment Word Count per Method", "Comment Words"),
     DIR_DIST, "09d_comment_words_histogram_loglog.png")
  
  comment_presence <- df %>%
    mutate(label = ifelse(has_comment_flag, "Has comments", "No comments")) %>%
    count(label) %>%
    mutate(pct = round(100 * n / sum(n), 1))
  p_cpres <- ggplot(comment_presence, aes(x = label, y = pct, fill = label)) +
    geom_col(show.legend = FALSE) +
    geom_text(aes(label = paste0(pct, "%")), vjust = -0.4, size = 4) +
    scale_fill_manual(values = c("Has comments" = "#2ca02c", "No comments" = "#d62728")) +
    labs(title = "Proportion of Methods With vs Without Comments",
         x = NULL, y = "% of Methods") +
    theme_minimal(base_size = 12)
  sp(p_cpres, DIR_DIST, "09e_comment_presence_bar.png", w = 6, h = 5)
}

# ── 3I. DERIVED METRICS ───────────────────────────────────────────────────────

if (has_loc) {
  sp(hist_linear(df %>% filter(!is.na(cc_per_loc)), "cc_per_loc", "#ff7f0e",
                 "CC per Line of Code Distribution", "CC / LOC"),
     DIR_DIST, "10a_cc_per_loc_histogram_linear.png")
  sp(hist_loglog(df %>% filter(!is.na(cc_per_loc)), "cc_per_loc", "#ff7f0e",
                 "CC per Line of Code Distribution", "CC / LOC"),
     DIR_DIST, "10b_cc_per_loc_histogram_loglog.png")
}

if (has_cog) {
  sp(hist_linear(df %>% filter(!is.na(cog_excess)), "cog_excess", "#9467bd",
                 "Cognitive Excess (Cognitive - Cyclomatic) Distribution",
                 "Cognitive - Cyclomatic"),
     DIR_DIST, "11a_cog_excess_histogram_linear.png")
  sp(hist_linear(df %>% filter(!is.na(cog_ratio), cog_ratio > 0),
                 "cog_ratio", "#c5b0d5",
                 "Cognitive / Cyclomatic Ratio Distribution", "Cog / CC Ratio"),
     DIR_DIST, "11b_cog_ratio_histogram_linear.png")
  sp(hist_loglog(df %>% filter(!is.na(cog_ratio), cog_ratio > 0),
                 "cog_ratio", "#c5b0d5",
                 "Cognitive / Cyclomatic Ratio Distribution", "Cog / CC Ratio"),
     DIR_DIST, "11c_cog_ratio_histogram_loglog.png")
}

if (has_id) {
  sp(hist_linear(df %>% filter(!is.na(naming_score)), "naming_score", "#ff7f0e",
                 "Naming Quality Score Distribution",
                 "Naming Score (avg_id_words * (1 - abbrev_ratio))"),
     DIR_DIST, "12a_naming_score_histogram_linear.png")
  sp(hist_loglog(df %>% filter(!is.na(naming_score), naming_score > 0),
                 "naming_score", "#ff7f0e",
                 "Naming Quality Score Distribution", "Naming Score"),
     DIR_DIST, "12b_naming_score_histogram_loglog.png")
}

# =============================================================================
# 4. CORRELATIONS  →  02_correlations
# =============================================================================

cat("Generating correlation plots...\n")

cor_cols <- intersect(
  c("cc", "cognitive_complexity", "loc", "loc_physical",
    "avg_nesting", "max_nesting", "avg_id_words", "abbreviated_ratio",
    "single_letter_ids", "longest_id", "total_words",
    "comment_count", "comment_words",
    "halstead_volume", "halstead_difficulty", "halstead_effort",
    "maintainability_index", "mi_normalized",
    "param_count", "return_count", "fan_out",
    "max_line_length", "avg_line_length",
    "cc_per_loc", "cog_ratio", "naming_score",
    "comment_density", "word_density", "blank_ratio"),
  names(df)
)

cor_data   <- df[, cor_cols] %>% drop_na()
cor_matrix <- cor(cor_data, use = "pairwise.complete.obs")
write_csv(as_tibble(cor_matrix, rownames = "metric"),
          file.path(DIR_TABLES, "correlation_matrix.csv"))

nice_names <- c(
  cc                   = "Cyclomatic CC",
  cognitive_complexity = "Cognitive CC",
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
  comment_words        = "Comment Words",
  halstead_volume      = "Halstead Volume",
  halstead_difficulty  = "Halstead Difficulty",
  halstead_effort      = "Halstead Effort",
  maintainability_index = "Maintainability Idx",
  mi_normalized        = "Maintainability (0-100)",
  param_count          = "Param Count",
  return_count         = "Return Count",
  fan_out              = "Fan-out",
  max_line_length      = "Max Line Length",
  avg_line_length      = "Avg Line Length",
  cc_per_loc           = "CC / LOC",
  cog_ratio            = "Cog/CC Ratio",
  naming_score         = "Naming Score",
  comment_density      = "Comment Density",
  word_density         = "Word Density",
  blank_ratio          = "Blank Line Ratio"
)

cor_long <- as_tibble(cor_matrix, rownames = "var1") %>%
  pivot_longer(-var1, names_to = "var2", values_to = "r") %>%
  mutate(
    var1  = recode(var1, !!!nice_names),
    var2  = recode(var2, !!!nice_names),
    label = sprintf("%.2f", r)  # every cell labelled
  )

n_vars     <- length(cor_cols)
tile_size  <- max(10, n_vars * 0.65)

p_corr <- ggplot(cor_long, aes(x = var1, y = var2, fill = r)) +
  geom_tile(colour = "white", linewidth = 0.3) +
  geom_text(aes(label = label), size = 2.4) +
  scale_fill_gradient2(low = "#d62728", mid = "white", high = "#1f77b4",
                       midpoint = 0, limits = c(-1, 1), name = "Pearson r") +
  labs(title = "Pearson Correlation Matrix — All Complexity Metrics",
       x = NULL, y = NULL) +
  theme_minimal(base_size = 10) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1),
        panel.grid  = element_blank())
sp(p_corr, DIR_CORR, "01_correlation_heatmap_full.png",
   w = tile_size, h = tile_size * 0.85)

# ── Focused heatmap: only the headline complexity metrics ─────────────────────
# The full matrix is comprehensive but busy. This trimmed version keeps just the
# core size/branching/structure metrics that matter most, so the strongest
# relationships are easy to read at a glance.
key_cor_cols <- intersect(
  c("cc", "cognitive_complexity", "loc", "max_nesting",
    "halstead_volume", "halstead_effort", "maintainability_index",
    "param_count", "fan_out"),
  rownames(cor_matrix)
)

if (length(key_cor_cols) >= 2) {
  key_matrix <- cor_matrix[key_cor_cols, key_cor_cols, drop = FALSE]
  key_long <- as_tibble(key_matrix, rownames = "var1") %>%
    pivot_longer(-var1, names_to = "var2", values_to = "r") %>%
    mutate(var1  = recode(var1, !!!nice_names),
           var2  = recode(var2, !!!nice_names),
           label = sprintf("%.2f", r))

  p_corr_key <- ggplot(key_long, aes(x = var1, y = var2, fill = r)) +
    geom_tile(colour = "white", linewidth = 0.4) +
    geom_text(aes(label = label), size = 3.6) +
    scale_fill_gradient2(low = "#d62728", mid = "white", high = "#1f77b4",
                         midpoint = 0, limits = c(-1, 1), name = "Pearson r") +
    labs(title = "Pearson Correlation — Key Complexity Metrics",
         subtitle = "Trimmed to the headline size, branching and structure metrics",
         x = NULL, y = NULL) +
    theme_minimal(base_size = 12) +
    theme(axis.text.x = element_text(angle = 45, hjust = 1),
          panel.grid  = element_blank())
  sp(p_corr_key, DIR_CORR, "01b_correlation_heatmap_key.png", w = 9, h = 8)
}

# ── Scatter: CC vs each other metric (hex + lm) ───────────────────────────────

scatter_pairs <- list(
  list(x="loc",               xlab="LOC (NBNC)",        col="#e377c2", file="02_cc_vs_loc.png"),
  list(x="loc_physical",      xlab="LOC (physical)",    col="#f7b6d2", file="03_cc_vs_loc_physical.png"),
  list(x="max_nesting",       xlab="Max Nesting Depth", col="#17becf", file="04_cc_vs_max_nesting.png"),
  list(x="avg_nesting",       xlab="Avg Nesting Depth", col="#9edae5", file="05_cc_vs_avg_nesting.png"),
  list(x="avg_id_words",      xlab="Avg ID Words",      col="#e377c2", file="06_cc_vs_avg_id_words.png"),
  list(x="abbreviated_ratio", xlab="Abbreviated Ratio", col="#bcbd22", file="07_cc_vs_abbreviated_ratio.png"),
  list(x="single_letter_ids", xlab="Single-letter IDs", col="#dbdb8d", file="08_cc_vs_single_letter_ids.png"),
  list(x="total_words",       xlab="Total Words",       col="#1f77b4", file="09_cc_vs_total_words.png"),
  list(x="comment_count",     xlab="Comment Count",     col="#2ca02c", file="10_cc_vs_comment_count.png"),
  list(x="comment_words",     xlab="Comment Words",     col="#98df8a", file="11_cc_vs_comment_words.png"),
  list(x="longest_id",        xlab="Longest Identifier",col="#8c6d31", file="12_cc_vs_longest_id.png"),
  list(x="naming_score",      xlab="Naming Score",      col="#ff7f0e", file="13_cc_vs_naming_score.png")
)

for (pair in scatter_pairs) {
  if (!(pair$x %in% names(df))) next
  r_val <- cor(df$cc, df[[pair$x]], use = "complete.obs")
  p <- ggplot(df %>% filter(!is.na(.data[[pair$x]]), .data[[pair$x]] > 0, cc > 0),
              aes(x = .data[[pair$x]], y = cc)) +
    geom_hex(bins = 70) +
    scale_fill_viridis_c(trans = "log10", name = "Methods") +
    geom_smooth(method = "lm", colour = "orange", se = TRUE,
                linewidth = 0.9, alpha = 0.3) +
    scale_x_log10(labels = label_comma()) +
    scale_y_log10(labels = label_comma()) +
    annotate("text", x = Inf, y = Inf, label = sprintf("r = %.3f", r_val),
             hjust = 1.1, vjust = 1.5, size = 4, family = "mono") +
    labs(title = sprintf("Cyclomatic CC vs %s", pair$xlab),
         x = sprintf("%s (log scale)", pair$xlab),
         y = "Cyclomatic CC (log scale)") +
    theme_minimal(base_size = 12)
  sp(p, DIR_CORR, pair$file)
}

if (has_cog) {
  r_cc_cog <- cor(df$cc, df$cognitive_complexity, use = "complete.obs")
  p_cc_cog <- ggplot(df %>% filter(cc > 0, cognitive_complexity > 0),
                     aes(x = cc, y = cognitive_complexity)) +
    geom_hex(bins = 70) +
    scale_fill_viridis_c(trans = "log10", name = "Methods") +
    geom_smooth(method = "lm", colour = "orange", se = TRUE,
                linewidth = 0.9, alpha = 0.3) +
    scale_x_log10(labels = label_comma()) +
    scale_y_log10(labels = label_comma()) +
    annotate("text", x = Inf, y = Inf, label = sprintf("r = %.3f", r_cc_cog),
             hjust = 1.1, vjust = 1.5, size = 4, family = "mono") +
    labs(title = "Cyclomatic CC vs Cognitive Complexity",
         x = "Cyclomatic CC (log scale)", y = "Cognitive Complexity (log scale)") +
    theme_minimal(base_size = 12)
  sp(p_cc_cog, DIR_CORR, "14_cc_vs_cognitive.png")
}

if (has_loc && has_loc_phys) {
  r_loc <- cor(df$loc, df$loc_physical, use = "complete.obs")
  p_locs <- ggplot(df %>% filter(loc > 0, loc_physical > 0),
                   aes(x = loc, y = loc_physical)) +
    geom_hex(bins = 70) +
    scale_fill_viridis_c(trans = "log10", name = "Methods") +
    geom_abline(slope = 1, intercept = 0, colour = "red",
                linetype = "dashed", linewidth = 0.8) +
    scale_x_log10(labels = label_comma()) +
    scale_y_log10(labels = label_comma()) +
    annotate("text", x = Inf, y = Inf,
             label = sprintf("r = %.3f\nred = equal", r_loc),
             hjust = 1.1, vjust = 1.5, size = 3.5, family = "mono") +
    labs(title = "LOC (NBNC) vs Physical LOC",
         subtitle = "Points above red line have more blank/comment lines",
         x = "LOC NBNC (log scale)", y = "Physical LOC (log scale)") +
    theme_minimal(base_size = 12)
  sp(p_locs, DIR_CORR, "15_loc_vs_loc_physical.png")
}

# =============================================================================
# 5. RISK BANDS  →  03_risk_bands
# =============================================================================

cat("Generating risk band plots...\n")

p_band_bar <- ggplot(band_counts, aes(x = risk_band, y = pct, fill = risk_band)) +
  geom_col(show.legend = FALSE) +
  geom_text(aes(label = paste0(pct, "%")), vjust = -0.4, size = 3.5) +
  scale_fill_manual(values = BAND_COLOURS) +
  labs(title = "Methods by CC Risk Band", x = "CC Band", y = "% of Methods") +
  theme_minimal(base_size = 12)
sp(p_band_bar, DIR_BANDS, "01_risk_band_distribution.png", w = 7, h = 5)

band_metric_plots <- list(
  list(col="loc",               ylab="LOC (NBNC)",          log_y=TRUE,  file="02_loc_by_cc_band.png"),
  list(col="loc_physical",      ylab="Physical LOC",        log_y=TRUE,  file="03_loc_physical_by_cc_band.png"),
  list(col="max_nesting",       ylab="Max Nesting Depth",   log_y=TRUE,  file="04_max_nesting_by_cc_band.png"),
  list(col="avg_nesting",       ylab="Avg Nesting Depth",   log_y=FALSE, file="05_avg_nesting_by_cc_band.png"),
  list(col="avg_id_words",      ylab="Avg ID Words",        log_y=FALSE, file="06_avg_id_words_by_cc_band.png"),
  list(col="abbreviated_ratio", ylab="Abbreviated Ratio",   log_y=FALSE, file="07_abbreviated_ratio_by_cc_band.png"),
  list(col="single_letter_ids", ylab="Single-letter IDs",   log_y=TRUE,  file="08_single_letter_ids_by_cc_band.png"),
  list(col="total_words",       ylab="Total Words",         log_y=TRUE,  file="09_total_words_by_cc_band.png"),
  list(col="comment_count",     ylab="Comment Count",       log_y=TRUE,  file="10_comment_count_by_cc_band.png"),
  list(col="comment_words",     ylab="Comment Words",       log_y=TRUE,  file="11_comment_words_by_cc_band.png"),
  list(col="naming_score",      ylab="Naming Score",        log_y=FALSE, file="12_naming_score_by_cc_band.png"),
  list(col="comment_density",   ylab="Comment Words / LOC", log_y=TRUE,  file="13_comment_density_by_cc_band.png"),
  list(col="cc_per_loc",        ylab="CC / LOC",            log_y=TRUE,  file="14_cc_per_loc_by_cc_band.png")
)

for (bm in band_metric_plots) {
  if (!(bm$col %in% names(df))) next
  plot_df <- df %>% filter(!is.na(risk_band), !is.na(.data[[bm$col]]))
  if (bm$log_y) plot_df <- plot_df %>% filter(.data[[bm$col]] > 0)
  meds <- plot_df %>%
    group_by(risk_band) %>%
    summarise(med = median(.data[[bm$col]], na.rm = TRUE), .groups = "drop")
  p <- ggplot(plot_df, aes(x = risk_band, y = .data[[bm$col]], fill = risk_band)) +
    geom_boxplot(outlier.size = 0.4, outlier.alpha = 0.2, alpha = 0.8) +
    geom_text(data = meds, aes(x = risk_band, y = med,
                               label = sprintf("%.2g", med)),
              vjust = -0.6, size = 2.8, inherit.aes = FALSE) +
    scale_fill_manual(values = BAND_COLOURS) +
    labs(title = sprintf("%s by CC Risk Band", bm$ylab),
         x = "CC Risk Band", y = bm$ylab) +
    theme_minimal(base_size = 12) +
    theme(legend.position = "none")
  if (bm$log_y) p <- p + scale_y_log10(labels = label_comma())
  sp(p, DIR_BANDS, bm$file, w = 8, h = 5)
}

# ridgeline
ridge_cols <- intersect(
  c("loc", "max_nesting", "avg_id_words", "abbreviated_ratio",
    "total_words", "comment_words", "cognitive_complexity"),
  names(df)
)
if (length(ridge_cols) >= 2) {
  ridge_df <- df %>%
    filter(!is.na(risk_band)) %>%
    select(risk_band, all_of(ridge_cols)) %>%
    pivot_longer(-risk_band, names_to = "metric", values_to = "value") %>%
    filter(!is.na(value), value > 0) %>%
    mutate(metric = recode(metric, !!!nice_names))
  p_ridge <- ggplot(ridge_df, aes(x = value, y = risk_band, fill = risk_band)) +
    geom_density_ridges(alpha = 0.7, scale = 1.2, rel_min_height = 0.01) +
    scale_fill_manual(values = BAND_COLOURS) +
    scale_x_log10(labels = label_comma()) +
    facet_wrap(~ metric, scales = "free_x", ncol = 2) +
    labs(title = "Metric Distributions by CC Risk Band (Ridgeline)",
         x = "Value (log scale)", y = "CC Risk Band") +
    theme_minimal(base_size = 11) +
    theme(legend.position = "none", strip.text = element_text(face = "bold"))
  sp(p_ridge, DIR_BANDS, "15_ridgeline_all_metrics_by_cc_band.png", w = 12, h = 14)
}

if (has_comments) {
  comment_rate <- df %>%
    filter(!is.na(risk_band)) %>%
    group_by(risk_band) %>%
    summarise(pct_commented = round(100 * mean(comment_count > 0, na.rm = TRUE), 1),
              .groups = "drop")
  write_csv(comment_rate, file.path(DIR_TABLES, "comment_rate_by_band.csv"))
  p_crate <- ggplot(comment_rate, aes(x = risk_band, y = pct_commented, fill = risk_band)) +
    geom_col(show.legend = FALSE) +
    geom_text(aes(label = paste0(pct_commented, "%")), vjust = -0.4, size = 3.5) +
    scale_fill_manual(values = BAND_COLOURS) +
    coord_cartesian(ylim = c(0, max(comment_rate$pct_commented) * 1.15)) +
    labs(title = "% of Methods With Comments by CC Risk Band",
         x = "CC Risk Band", y = "% Methods With Comments") +
    theme_minimal(base_size = 12)
  sp(p_crate, DIR_BANDS, "16_comment_rate_by_cc_band.png", w = 7, h = 5)
}

# metric agreement bands (both unfiltered and CC>=3)
if (has_cog) {
  classify_agree <- function(d) {
    d %>% mutate(
      agree_band = case_when(
        is.na(cog_ratio) ~ NA_character_,
        cog_ratio < 0.5  ~ "Cyclomatic much higher",
        cog_ratio < 0.8  ~ "Cyclomatic slightly higher",
        cog_ratio <= 1.2 ~ "Roughly equal",
        cog_ratio <= 2.0 ~ "Cognitive slightly higher",
        TRUE             ~ "Cognitive much higher"
      ),
      agree_band = factor(agree_band, levels = c(
        "Cyclomatic much higher", "Cyclomatic slightly higher",
        "Roughly equal", "Cognitive slightly higher", "Cognitive much higher"))
    )
  }
  agree_colours <- c(
    "Cyclomatic much higher"     = "#1f77b4",
    "Cyclomatic slightly higher" = "#aec7e8",
    "Roughly equal"              = "#98df8a",
    "Cognitive slightly higher"  = "#ffbb78",
    "Cognitive much higher"      = "#d62728"
  )
  
  for (filt in list(list(label="all_methods", min_cc=1),
                    list(label="cc3plus",      min_cc=3))) {
    df_a <- classify_agree(df %>% filter(!is.na(cog_ratio), cc >= filt$min_cc))
    agg  <- df_a %>% count(agree_band) %>% drop_na() %>%
      mutate(pct = round(100 * n / sum(n), 1))
    write_csv(agg, file.path(DIR_TABLES,
                             sprintf("metric_agreement_%s.csv", filt$label)))
    subtitle <- if (filt$min_cc == 1)
      "All methods; ratio = cognitive / cyclomatic"
    else
      "CC >= 3 only — low-CC methods trivially score 0 on cognitive"
    p_a <- ggplot(agg, aes(x = agree_band, y = pct, fill = agree_band)) +
      geom_col(show.legend = FALSE) +
      geom_text(aes(label = paste0(pct, "%")), vjust = -0.4, size = 3.5) +
      scale_fill_manual(values = agree_colours) +
      labs(title = "Agreement Between Cyclomatic and Cognitive Complexity",
           subtitle = subtitle, x = NULL, y = "% of Methods") +
      theme_minimal(base_size = 12) +
      theme(axis.text.x = element_text(angle = 20, hjust = 1))
    sp(p_a, DIR_BANDS,
       sprintf("17%s_metric_agreement_%s.png",
               ifelse(filt$min_cc == 1, "a", "b"), filt$label),
       w = 9, h = 5)
  }
}

# =============================================================================
# 6. PROJECT-LEVEL  →  04_projects
# =============================================================================

cat("Generating project-level plots...\n")

project_stats <- df %>%
  group_by(project) %>%
  summarise(
    n_methods   = n(),
    median_cc   = median(cc),
    mean_cc     = round(mean(cc), 2),
    sd_cc       = round(sd(cc), 2),
    max_cc      = max(cc),
    pct_cc_gt5  = round(100 * mean(cc > 5),  2),
    pct_cc_gt10 = round(100 * mean(cc > 10), 2),
    pct_cc_gt25 = round(100 * mean(cc > 25), 2),
    .groups = "drop"
  ) %>%
  arrange(desc(median_cc))

# add optional columns after grouping, not inside summarise
if (has_cog)
  project_stats$median_cognitive <- df %>% group_by(project) %>%
  summarise(v = median(cognitive_complexity, na.rm = TRUE), .groups = "drop") %>%
  { .$v[match(project_stats$project, .$project)] }

if (has_loc)
  project_stats$median_loc <- df %>% group_by(project) %>%
  summarise(v = median(loc, na.rm = TRUE), .groups = "drop") %>%
  { .$v[match(project_stats$project, .$project)] }

if (has_nest)
  project_stats$median_nesting <- df %>% group_by(project) %>%
  summarise(v = median(max_nesting, na.rm = TRUE), .groups = "drop") %>%
  { .$v[match(project_stats$project, .$project)] }

if (has_comments)
  project_stats$pct_commented <- df %>% group_by(project) %>%
  summarise(v = round(100 * mean(comment_count > 0, na.rm = TRUE), 1), .groups = "drop") %>%
  { .$v[match(project_stats$project, .$project)] }

write_csv(project_stats, file.path(DIR_TABLES, "project_summary.csv"))

if (!is.null(repos)) {
  project_stats <- project_stats %>%
    left_join(repos %>% select(project, stars, forks,
                               commit_count, size_kb, java_file_count),
              by = "project")
}

ps <- function(x) str_extract(x, "[^/]+$")

box_proj   <- top_projects(project_stats, "median_cc")
box_order  <- project_stats %>% filter(project %in% box_proj) %>%
  arrange(median_cc) %>% pull(project)
p_proj_box <- ggplot(df %>% filter(cc > 0, project %in% box_proj),
                     aes(x = factor(project, levels = box_order), y = cc)) +
  geom_boxplot(outlier.size = 0.4, outlier.alpha = 0.2, fill = "#4C72B0", alpha = 0.7) +
  coord_flip() +
  scale_y_log10(labels = label_comma()) +
  scale_x_discrete(labels = ps) +
  labs(title = "CC Distribution per Project (highest median CC)",
       subtitle = proj_subtitle(length(box_proj)),
       x = NULL, y = "Cyclomatic Complexity (log scale)") +
  theme_minimal(base_size = 8)
sp(p_proj_box, DIR_PROJ, "01_cc_boxplot_per_project.png",
   w = 12, h = proj_h(length(box_proj)))

bar_proj <- top_projects(project_stats, "median_cc")
p_proj_bar <- ggplot(project_stats %>% filter(project %in% bar_proj) %>% mutate(proj = ps(project)),
                     aes(x = reorder(proj, median_cc), y = median_cc)) +
  geom_col(fill = "#4C72B0", alpha = 0.8) +
  coord_flip() +
  labs(title = "Median Cyclomatic Complexity per Project",
       subtitle = proj_subtitle(length(bar_proj)), x = NULL, y = "Median CC") +
  theme_minimal(base_size = 8)
sp(p_proj_bar, DIR_PROJ, "02_median_cc_per_project.png",
   w = 10, h = proj_h(length(bar_proj)))

pct_proj <- top_projects(project_stats, "pct_cc_gt10")
p_proj_pct <- ggplot(project_stats %>% filter(project %in% pct_proj) %>% mutate(proj = ps(project)),
                     aes(x = reorder(proj, pct_cc_gt10), y = pct_cc_gt10)) +
  geom_col(fill = "#d62728", alpha = 0.8) +
  coord_flip() +
  labs(title = "% Methods with CC > 10 per Project",
       subtitle = proj_subtitle(length(pct_proj)), x = NULL, y = "% Methods CC > 10") +
  theme_minimal(base_size = 8)
sp(p_proj_pct, DIR_PROJ, "03_pct_high_cc_per_project.png",
   w = 10, h = proj_h(length(pct_proj)))

p_size_cc <- ggplot(project_stats, aes(x = n_methods, y = median_cc)) +
  geom_point(alpha = 0.6, size = 2, colour = "#4C72B0") +
  geom_smooth(method = "lm", colour = "orange", se = TRUE) +
  scale_x_log10(labels = label_comma()) +
  labs(title = "Project Size (Method Count) vs Median CC",
       x = "Number of Methods (log scale)", y = "Median CC") +
  theme_minimal(base_size = 12)
sp(p_size_cc, DIR_PROJ, "04_project_size_vs_median_cc.png")

if (!is.null(repos) && "commit_count" %in% names(project_stats)) {
  ps_commits <- project_stats %>% filter(!is.na(commit_count), commit_count > 0)
  if (nrow(ps_commits) > 0) {
    p_commits <- ggplot(ps_commits, aes(x = commit_count, y = median_cc, size = n_methods)) +
      geom_point(alpha = 0.6, colour = "#4C72B0") +
      geom_smooth(method = "lm", colour = "orange", se = TRUE, inherit.aes = FALSE,
                  data = ps_commits, aes(x = commit_count, y = median_cc)) +
      scale_x_log10(labels = label_comma()) +
      scale_size_continuous(name = "Methods", range = c(2, 8)) +
      labs(title = "Commit Count vs Median Project CC",
           x = "Commit Count (log scale)", y = "Median CC") +
      theme_minimal(base_size = 12)
    sp(p_commits, DIR_PROJ, "05_commits_vs_median_cc.png")
  }
}

# =============================================================================
# 7. NORMALITY & SHAPE  →  05_tables
# =============================================================================

cat("Running normality tests...\n")

norm_cols <- intersect(c("cc", "cognitive_complexity", "loc", "max_nesting",
                         "avg_id_words", "total_words"), names(df))

norm_results <- map_dfr(norm_cols, function(col) {
  x    <- df[[col]][!is.na(df[[col]]) & df[[col]] > 0]
  sw_s <- sample(x, min(5000, length(x)))
  sw   <- shapiro.test(sw_s)
  ks   <- ks.test(x, "plnorm", meanlog = mean(log(x)), sdlog = sd(log(x)))
  tibble(metric         = col,
         sw_W           = round(sw$statistic, 5),
         sw_p           = sw$p.value,
         ks_D           = round(ks$statistic, 5),
         ks_p           = ks$p.value,
         fits_lognormal = ks$p.value > 0.05)
})
print(norm_results)
write_csv(norm_results, file.path(DIR_TABLES, "normality_tests.csv"))

shape_stats <- map_dfr(norm_cols, function(col) {
  x <- df[[col]][!is.na(df[[col]]) & df[[col]] > 0]
  tibble(metric   = col,
         skewness = round(skewness(x), 3),
         kurtosis = round(kurtosis(x), 3),
         cv       = round(sd(x) / mean(x), 3))
})
write_csv(shape_stats, file.path(DIR_TABLES, "distributional_shape.csv"))

# =============================================================================
# 8. SUMMARY REPORT
# =============================================================================
report <- c(
  "================================================================",
  "  COMPLEXITY ANALYSIS SUMMARY",
  "================================================================",
  sprintf("  Generated : %s", format(Sys.time(), "%Y-%m-%d %H:%M:%S")),
  sprintf("  Methods   : %s", format(n, big.mark = ",")),
  sprintf("  Projects  : %d", n_proj),
  "",
  
  # ── CYCLOMATIC COMPLEXITY ──────────────────────────────────────
  "----------------------------------------------------------------",
  "  CYCLOMATIC COMPLEXITY (CC)",
  "----------------------------------------------------------------",
  sprintf("  Min      : %g",    min(df$cc)),
  sprintf("  P5       : %g",    quantile(df$cc, 0.05)),
  sprintf("  Q1       : %g",    quantile(df$cc, 0.25)),
  sprintf("  Median   : %g",    median(df$cc)),
  sprintf("  Mean     : %.2f",  mean(df$cc)),
  sprintf("  Q3       : %g",    quantile(df$cc, 0.75)),
  sprintf("  P95      : %g",    quantile(df$cc, 0.95)),
  sprintf("  Max      : %g",    max(df$cc)),
  sprintf("  SD       : %.2f",  sd(df$cc)),
  sprintf("  Skewness : %.2f",  skewness(df$cc)),
  sprintf("  Kurtosis : %.1f",  kurtosis(df$cc)),
  "",
  "  Risk Band Distribution:",
  paste(apply(band_counts, 1, function(r)
    sprintf("    CC %-6s  %5s%%   (%s methods)",
            r["risk_band"], r["pct"],
            format(as.integer(r["n"]), big.mark = ","))),
    collapse = "\n"),
  sprintf("  %% with CC > 5  : %.1f%%", 100 * mean(df$cc > 5)),
  sprintf("  %% with CC > 10 : %.1f%%", 100 * mean(df$cc > 10)),
  sprintf("  %% with CC > 25 : %.1f%%", 100 * mean(df$cc > 25)),
  "",
  
  # ── COGNITIVE COMPLEXITY ───────────────────────────────────────
  if (has_cog) "----------------------------------------------------------------",
  if (has_cog) "  COGNITIVE COMPLEXITY",
  if (has_cog) "----------------------------------------------------------------",
  if (has_cog) sprintf("  Min      : %g",    min(df$cognitive_complexity,  na.rm = TRUE)),
  if (has_cog) sprintf("  P5       : %g",    quantile(df$cognitive_complexity, 0.05, na.rm = TRUE)),
  if (has_cog) sprintf("  Median   : %g",    median(df$cognitive_complexity,   na.rm = TRUE)),
  if (has_cog) sprintf("  Mean     : %.2f",  mean(df$cognitive_complexity,     na.rm = TRUE)),
  if (has_cog) sprintf("  P95      : %g",    quantile(df$cognitive_complexity, 0.95, na.rm = TRUE)),
  if (has_cog) sprintf("  Max      : %g",    max(df$cognitive_complexity,      na.rm = TRUE)),
  if (has_cog) sprintf("  SD       : %.2f",  sd(df$cognitive_complexity,       na.rm = TRUE)),
  if (has_cog) sprintf("  Skewness : %.2f",  skewness(df$cognitive_complexity[!is.na(df$cognitive_complexity)])),
  if (has_cog) sprintf("  r(CC, Cognitive)  : %.3f", cor(df$cc, df$cognitive_complexity, use = "complete.obs")),
  if (has_cog) sprintf("  Median cog excess : %.2f  (cognitive - cyclomatic)", median(df$cog_excess, na.rm = TRUE)),
  if (has_cog) sprintf("  %% methods cog > cc : %.1f%%", 100 * mean(df$cog_excess > 0, na.rm = TRUE)),
  if (has_cog) "",
  
  # ── LOC ────────────────────────────────────────────────────────
  if (has_loc) "----------------------------------------------------------------",
  if (has_loc) "  LINES OF CODE (NBNC LOC)",
  if (has_loc) "----------------------------------------------------------------",
  if (has_loc) sprintf("  Min      : %g",    min(df$loc,            na.rm = TRUE)),
  if (has_loc) sprintf("  P5       : %g",    quantile(df$loc, 0.05, na.rm = TRUE)),
  if (has_loc) sprintf("  Median   : %g",    median(df$loc,         na.rm = TRUE)),
  if (has_loc) sprintf("  Mean     : %.2f",  mean(df$loc,           na.rm = TRUE)),
  if (has_loc) sprintf("  P95      : %g",    quantile(df$loc, 0.95, na.rm = TRUE)),
  if (has_loc) sprintf("  Max      : %g",    max(df$loc,            na.rm = TRUE)),
  if (has_loc) sprintf("  SD       : %.2f",  sd(df$loc,             na.rm = TRUE)),
  if (has_loc) sprintf("  Skewness : %.2f",  skewness(df$loc[!is.na(df$loc)])),
  if (has_loc) sprintf("  r(CC, LOC)        : %.3f", cor(df$cc, df$loc, use = "complete.obs")),
  if (has_loc) sprintf("  %% methods > 24 LOC : %.1f%%", 100 * mean(df$loc > 24, na.rm = TRUE)),
  if (has_loc && has_loc_phys) sprintf("  r(LOC, LOC_phys)  : %.3f", cor(df$loc, df$loc_physical, use = "complete.obs")),
  if (has_loc) "",
  
  # ── NESTING ────────────────────────────────────────────────────
  if (has_nest) "----------------------------------------------------------------",
  if (has_nest) "  NESTING DEPTH",
  if (has_nest) "----------------------------------------------------------------",
  if (has_nest) sprintf("  Max Nesting — Median : %g",   median(df$max_nesting, na.rm = TRUE)),
  if (has_nest) sprintf("  Max Nesting — Mean   : %.2f", mean(df$max_nesting,   na.rm = TRUE)),
  if (has_nest) sprintf("  Max Nesting — P95    : %g",   quantile(df$max_nesting, 0.95, na.rm = TRUE)),
  if (has_nest) sprintf("  Max Nesting — Max    : %g",   max(df$max_nesting,    na.rm = TRUE)),
  if (has_nest) sprintf("  Avg Nesting — Median : %.2f", median(df$avg_nesting, na.rm = TRUE)),
  if (has_nest) sprintf("  r(CC, max_nesting)   : %.3f", cor(df$cc, df$max_nesting, use = "complete.obs")),
  if (has_nest && has_cog) sprintf("  r(Cog, max_nesting)  : %.3f", cor(df$cognitive_complexity, df$max_nesting, use = "complete.obs")),
  if (has_nest) sprintf("  %% methods nesting=0  : %.1f%%", 100 * mean(df$max_nesting == 0, na.rm = TRUE)),
  if (has_nest) sprintf("  %% methods nesting>=3 : %.1f%%", 100 * mean(df$max_nesting >= 3, na.rm = TRUE)),
  if (has_nest) "",
  
  # ── IDENTIFIER / NAMING ────────────────────────────────────────
  if (has_id) "----------------------------------------------------------------",
  if (has_id) "  IDENTIFIER & NAMING METRICS",
  if (has_id) "----------------------------------------------------------------",
  if (has_id) sprintf("  Avg ID words — Median   : %.2f", median(df$avg_id_words,      na.rm = TRUE)),
  if (has_id) sprintf("  Avg ID words — Mean     : %.2f", mean(df$avg_id_words,        na.rm = TRUE)),
  if (has_id) sprintf("  Abbrev ratio — Median   : %.3f", median(df$abbreviated_ratio, na.rm = TRUE)),
  if (has_id) sprintf("  Abbrev ratio — Mean     : %.3f", mean(df$abbreviated_ratio,   na.rm = TRUE)),
  if (has_id) sprintf("  Single-letter IDs — Med : %g",   median(df$single_letter_ids, na.rm = TRUE)),
  if (has_id) sprintf("  Longest ID — Median     : %g",   median(df$longest_id,        na.rm = TRUE)),
  if (has_id) sprintf("  Naming score — Median   : %.3f", median(df$naming_score,      na.rm = TRUE)),
  if (has_id) sprintf("  r(CC, naming_score)     : %.3f", cor(df$cc, df$naming_score,  use = "complete.obs")),
  if (has_id) sprintf("  r(CC, abbrev_ratio)     : %.3f", cor(df$cc, df$abbreviated_ratio, use = "complete.obs")),
  if (has_id) "",
  
  # ── COMMENTS ───────────────────────────────────────────────────
  if (has_comments) "----------------------------------------------------------------",
  if (has_comments) "  COMMENT METRICS",
  if (has_comments) "----------------------------------------------------------------",
  if (has_comments) sprintf("  %% methods with comments    : %.1f%%", 100 * mean(df$has_comment_flag, na.rm = TRUE)),
  if (has_comments) sprintf("  Comment words — Median     : %g",   median(df$comment_words, na.rm = TRUE)),
  if (has_comments) sprintf("  Comment words — Mean       : %.2f", mean(df$comment_words,   na.rm = TRUE)),
  if (has_comments) sprintf("  Comment words — P95        : %g",   quantile(df$comment_words, 0.95, na.rm = TRUE)),
  if (has_comments) sprintf("  r(CC, comment_words)       : %.3f", cor(df$cc, df$comment_words, use = "complete.obs")),
  if (has_comments) {
    med_com   <- median(df$cc[df$has_comment_flag == TRUE],  na.rm = TRUE)
    med_nocom <- median(df$cc[df$has_comment_flag == FALSE], na.rm = TRUE)
    sprintf("  Median CC (commented)      : %g", med_com)
  },
  if (has_comments) {
    med_nocom <- median(df$cc[df$has_comment_flag == FALSE], na.rm = TRUE)
    sprintf("  Median CC (not commented)  : %g", med_nocom)
  },
  if (has_comments) "",
  
  # ── PROJECT-LEVEL ──────────────────────────────────────────────
  "----------------------------------------------------------------",
  "  PROJECT-LEVEL SUMMARY",
  "----------------------------------------------------------------",
  sprintf("  Median project method count : %g",   median(project_stats$n_methods)),
  sprintf("  Median project median CC    : %.2f", median(project_stats$median_cc)),
  sprintf("  Project with highest median CC : %s (median CC = %g)",
          str_extract(project_stats$project[which.max(project_stats$median_cc)], "[^/]+$"),
          max(project_stats$median_cc)),
  sprintf("  Project with lowest median CC  : %s (median CC = %g)",
          str_extract(project_stats$project[which.min(project_stats$median_cc)], "[^/]+$"),
          min(project_stats$median_cc)),
  sprintf("  Project with highest max CC    : %s (max CC = %g)",
          str_extract(project_stats$project[which.max(project_stats$max_cc)], "[^/]+$"),
          max(project_stats$max_cc)),
  "",
  
  # ── KEY CORRELATIONS ───────────────────────────────────────────
  "----------------------------------------------------------------",
  "  KEY CORRELATIONS WITH CC",
  "----------------------------------------------------------------",
  if (has_cog)  sprintf("  CC vs Cognitive CC   : r = %.3f", cor(df$cc, df$cognitive_complexity, use = "complete.obs")),
  if (has_loc)  sprintf("  CC vs LOC            : r = %.3f", cor(df$cc, df$loc,                  use = "complete.obs")),
  if (has_nest) sprintf("  CC vs max nesting    : r = %.3f", cor(df$cc, df$max_nesting,          use = "complete.obs")),
  if (has_id)   sprintf("  CC vs naming score   : r = %.3f", cor(df$cc, df$naming_score,         use = "complete.obs")),
  if (has_id)   sprintf("  CC vs abbrev ratio   : r = %.3f", cor(df$cc, df$abbreviated_ratio,    use = "complete.obs")),
  if (has_comments) sprintf("  CC vs comment words  : r = %.3f", cor(df$cc, df$comment_words,   use = "complete.obs")),
  if (has_cog && has_nest) sprintf("  Cognitive vs nesting : r = %.3f", cor(df$cognitive_complexity, df$max_nesting, use = "complete.obs")),
  "",
  
  # ── OUTPUT FOLDERS ─────────────────────────────────────────────
  "----------------------------------------------------------------",
  "  OUTPUT FOLDERS",
  "----------------------------------------------------------------",
  "  data_tables/             all CSV tables + raw program output + this report",
  "  graphs/01_distributions/ histograms (linear + log-log), ECDFs for every metric",
  "  graphs/02_correlations/  full correlation heatmap + CC vs each metric scatterplots",
  "  graphs/03_risk_bands/    boxplots per band, ridgelines, naming/comment by band",
  "  graphs/04_projects/      per-project CC profiles + small multiples grid",
  "  graphs/06_cc_vs_cognitive  CC vs cognitive comparisons and disagreement analysis",
  "  graphs/07_nesting_drivers  nesting depth as a complexity driver",
  "  graphs/08_loc_vs_complexity LOC-based plots and CC density by method length",
  "  graphs/09_modelling/     regression, partial correlations, PCA, redundancy",
  "================================================================"
)


writeLines(report[!sapply(report, is.null)], file.path(DATA_DIR, "summary_report.txt"))
cat("\nDone. Tables ->", DATA_DIR, " | Graphs ->", GRAPHS_DIR, "\n")

# =============================================================================
# 9. CC VS COGNITIVE  →  06_cc_vs_cognitive
# =============================================================================

if (has_cog) {
  cat("Generating CC vs Cognitive plots...\n")
  
  # 01: Per-project scatter — median CC vs median Cognitive
  proj_cog <- df %>%
    group_by(project) %>%
    summarise(
      median_cc  = median(cc),
      median_cog = median(cognitive_complexity, na.rm = TRUE),
      n_methods  = n(),
      .groups = "drop"
    ) %>%
    mutate(proj = str_extract(project, "[^/]+$"))
  
  r_proj_ccvscog <- cor(proj_cog$median_cc, proj_cog$median_cog, use = "complete.obs")
  
  p <- ggplot(proj_cog, aes(x = median_cc, y = median_cog, size = n_methods)) +
    geom_point(alpha = 0.65, colour = "#4C72B0") +
    geom_smooth(method = "lm", colour = "orange", se = TRUE,
                data = proj_cog, mapping = aes(x = median_cc, y = median_cog)) +
    geom_abline(slope = 1, intercept = 0, linetype = "dashed",
                colour = "red", linewidth = 0.7) +
    scale_size_continuous(name = "Methods", range = c(2, 8)) +
    annotate("text", x = Inf, y = -Inf,
             label = sprintf("r = %.3f\nred = equal", r_proj_ccvscog),
             hjust = 1.1, vjust = -0.5, size = 3.5, family = "mono") +
    labs(title = "Per-Project Median CC vs Median Cognitive Complexity",
         subtitle = "Projects above red line: cognitive scores higher than cyclomatic on average",
         x = "Median Cyclomatic CC", y = "Median Cognitive Complexity") +
    theme_minimal(base_size = 12)
  sp(p, DIR_CCVCOG, "01_project_median_cc_vs_cognitive.png")
  write_csv(proj_cog, file.path(DIR_TABLES, "project_cc_vs_cognitive.csv"))
  
  # 02: Side-by-side boxplots of CC and Cognitive by risk band
  ccvscog_long <- df %>%
    filter(!is.na(risk_band), cognitive_complexity >= 0) %>%
    select(risk_band, cc, cognitive_complexity) %>%
    pivot_longer(c(cc, cognitive_complexity),
                 names_to = "metric", values_to = "value") %>%
    mutate(metric = recode(metric,
                           cc                   = "Cyclomatic",
                           cognitive_complexity = "Cognitive"
    )) %>%
    filter(value > 0)
  
  p <- ggplot(ccvscog_long, aes(x = risk_band, y = value, fill = metric)) +
    geom_boxplot(outlier.size = 0.3, outlier.alpha = 0.15, alpha = 0.8,
                 position = position_dodge(width = 0.8)) +
    scale_fill_manual(values = c("Cyclomatic" = "#1f77b4", "Cognitive" = "#9467bd")) +
    scale_y_log10(labels = label_comma()) +
    labs(title = "Cyclomatic vs Cognitive Complexity by CC Risk Band",
         subtitle = "Side-by-side within each band; cognitive typically scores higher for complex methods",
         x = "CC Risk Band", y = "Score (log scale)", fill = NULL) +
    theme_minimal(base_size = 12) +
    theme(legend.position = "top")
  sp(p, DIR_CCVCOG, "02_cc_vs_cognitive_sidebyside_by_band.png")
  
  # 03: Cog excess (cog - cc) distribution by risk band
  p <- ggplot(df %>% filter(!is.na(risk_band), !is.na(cog_excess)),
              aes(x = risk_band, y = cog_excess, fill = risk_band)) +
    geom_boxplot(outlier.size = 0.3, outlier.alpha = 0.15, alpha = 0.8) +
    geom_hline(yintercept = 0, linetype = "dashed", colour = "red", linewidth = 0.8) +
    coord_cartesian(ylim = c(-10, 80)) +
    scale_fill_manual(values = BAND_COLOURS) +
    labs(title = "Cognitive Excess (Cognitive - Cyclomatic) by CC Risk Band",
         subtitle = "Above 0: cognitive penalises more; y-axis capped at 80 (outliers exist beyond)",
         x = "CC Risk Band", y = "Cognitive - Cyclomatic") +
    theme_minimal(base_size = 12) +
    theme(legend.position = "none")
  sp(p, DIR_CCVCOG, "03_cog_excess_by_cc_band.png")
  
  
  # 05: % of methods where cognitive > cyclomatic, by project
  proj_cog_pct <- df %>%
    filter(!is.na(cog_excess)) %>%
    group_by(project) %>%
    summarise(
      pct_cog_higher = round(100 * mean(cog_excess > 0), 1),
      median_cog_excess = median(cog_excess),
      .groups = "drop"
    ) %>%
    mutate(proj = str_extract(project, "[^/]+$"))
  write_csv(proj_cog_pct, file.path(DIR_TABLES, "project_cog_excess.csv"))
  
  proj_cog_top <- proj_cog_pct %>% slice_max(pct_cog_higher, n = MAX_PROJ_BARS, with_ties = FALSE)
  p <- ggplot(proj_cog_top, aes(x = reorder(proj, pct_cog_higher), y = pct_cog_higher)) +
    geom_col(fill = "#9467bd", alpha = 0.8) +
    geom_hline(yintercept = 50, linetype = "dashed", colour = "red", linewidth = 0.7) +
    coord_flip() +
    labs(title = "% of Methods Where Cognitive > Cyclomatic, by Project",
         subtitle = paste0(proj_subtitle(nrow(proj_cog_top)),
                           "; red line = 50% (above = cognitive scores higher)"),
         x = NULL, y = "% Methods where Cognitive > Cyclomatic") +
    theme_minimal(base_size = 8)
  sp(p, DIR_CCVCOG, "05_pct_cog_higher_by_project.png",
     w = 10, h = proj_h(nrow(proj_cog_top)))
}

# =============================================================================
# 10. NESTING AS A COMPLEXITY DRIVER  →  07_nesting_drivers
# =============================================================================

if (has_nest) {
  cat("Generating nesting driver plots...\n")
  
  
  # 02: % of methods exceeding CC > 10 at each nesting depth
  nest_cc_pct <- df %>%
    filter(max_nesting <= 12) %>%
    group_by(max_nesting) %>%
    summarise(
      n              = n(),
      pct_cc_gt10    = round(100 * mean(cc > 10), 1),
      pct_cc_gt5     = round(100 * mean(cc > 5),  1),
      pct_cc_gt25    = round(100 * mean(cc > 25), 1),
      median_cc      = median(cc),
      .groups = "drop"
    )
  write_csv(nest_cc_pct, file.path(DIR_TABLES, "nesting_vs_cc_pct.csv"))
  
  p <- ggplot(nest_cc_pct, aes(x = max_nesting)) +
    geom_line(aes(y = pct_cc_gt5,  colour = "CC > 5"),  linewidth = 1) +
    geom_line(aes(y = pct_cc_gt10, colour = "CC > 10"), linewidth = 1) +
    geom_line(aes(y = pct_cc_gt25, colour = "CC > 25"), linewidth = 1) +
    geom_point(aes(y = pct_cc_gt5,  colour = "CC > 5"),  size = 2.5) +
    geom_point(aes(y = pct_cc_gt10, colour = "CC > 10"), size = 2.5) +
    geom_point(aes(y = pct_cc_gt25, colour = "CC > 25"), size = 2.5) +
    scale_colour_manual(values = c("CC > 5"  = "#8fbc8f",
                                   "CC > 10" = "#ff7f0e",
                                   "CC > 25" = "#d62728")) +
    scale_x_continuous(breaks = 0:12) +
    labs(title = "% of Methods Exceeding CC Thresholds by Max Nesting Depth",
         subtitle = "Each point = all methods at that nesting depth",
         x = "Max Nesting Depth", y = "% of Methods", colour = NULL) +
    theme_minimal(base_size = 12) +
    theme(legend.position = "top")
  sp(p, DIR_NESTING, "02_pct_high_cc_by_nesting_depth.png")
  
  # 03: Median CC at each nesting depth (bar)
  p <- ggplot(nest_cc_pct, aes(x = max_nesting, y = median_cc)) +
    geom_col(fill = "#17becf", alpha = 0.85) +
    geom_text(aes(label = sprintf("%.1f", median_cc)), vjust = -0.4, size = 3) +
    scale_x_continuous(breaks = 0:12) +
    labs(title = "Median Cyclomatic CC at Each Max Nesting Depth",
         x = "Max Nesting Depth", y = "Median CC") +
    theme_minimal(base_size = 12)
  sp(p, DIR_NESTING, "03_median_cc_by_nesting_depth.png")
  
  # 04: Nesting depth distribution split: methods that exceed CC>10 vs those that don't
  p <- ggplot(df %>% filter(max_nesting <= 15),
              aes(x = max_nesting, fill = cc > 10, colour = cc > 10)) +
    geom_density(alpha = 0.3, adjust = 1.5, linewidth = 0.8, position = "identity") +
    scale_fill_manual(values  = c("TRUE" = "#d62728", "FALSE" = "#2ca02c"),
                      labels  = c("TRUE" = "CC > 10", "FALSE" = "CC <= 10")) +
    scale_colour_manual(values = c("TRUE" = "#d62728", "FALSE" = "#2ca02c"),
                        labels = c("TRUE" = "CC > 10", "FALSE" = "CC <= 10")) +
    labs(title = "Nesting Depth Distribution: High vs Low CC Methods",
         subtitle = "Do high-CC methods nest deeper?",
         x = "Max Nesting Depth", y = "Density",
         fill = NULL, colour = NULL) +
    theme_minimal(base_size = 12) +
    theme(legend.position = "top")
  sp(p, DIR_NESTING, "04_nesting_density_by_cc_group.png")
  
  if (has_cog) {
    # 05: Nesting depth vs cog excess — does nesting explain why cognitive > cyclomatic?
    p <- ggplot(df %>% filter(!is.na(cog_excess), max_nesting <= 12),
                aes(x = factor(max_nesting), y = cog_excess)) +
      geom_boxplot(fill = "#9467bd", alpha = 0.6,
                   outlier.size = 0.4, outlier.alpha = 0.2) +
      geom_hline(yintercept = 0, linetype = "dashed", colour = "red", linewidth = 0.8) +
      coord_cartesian(ylim = c(-5, 50)) +
      labs(title = "Cognitive Excess by Max Nesting Depth",
           subtitle = "Positive = cognitive scores higher; y-axis capped at 50 (outliers exist beyond)",
           x = "Max Nesting Depth", y = "Cognitive - Cyclomatic") +
      theme_minimal(base_size = 12)
    sp(p, DIR_NESTING, "05_cog_excess_by_nesting_depth.png")
  }
}

# =============================================================================
# 11. LOC VS COMPLEXITY  →  08_loc_vs_complexity
# =============================================================================

if (has_loc) {
  cat("Generating LOC vs complexity plots...\n")
  
  # 01: CC/LOC ratio by project — density/complexity per line
  proj_ccloc <- df %>%
    filter(!is.na(cc_per_loc), cc_per_loc > 0) %>%
    group_by(project) %>%
    summarise(
      median_cc_per_loc = median(cc_per_loc),
      median_cc         = median(cc),
      median_loc        = median(loc),
      n_methods         = n(),
      .groups = "drop"
    ) %>%
    mutate(proj = str_extract(project, "[^/]+$"))
  write_csv(proj_ccloc, file.path(DIR_TABLES, "project_cc_per_loc.csv"))
  
  proj_ccloc_top <- proj_ccloc %>% slice_max(median_cc_per_loc, n = MAX_PROJ_BARS, with_ties = FALSE)
  p <- ggplot(proj_ccloc_top, aes(x = reorder(proj, median_cc_per_loc),
                              y = median_cc_per_loc)) +
    geom_col(fill = "#ff7f0e", alpha = 0.85) +
    coord_flip() +
    labs(title = "Median CC / LOC by Project",
         subtitle = paste0(proj_subtitle(nrow(proj_ccloc_top)),
                           "; high = short methods densely packed with branches"),
         x = NULL, y = "Median CC per Line of Code") +
    theme_minimal(base_size = 8)
  sp(p, DIR_LOC, "01_cc_per_loc_by_project.png",
     w = 10, h = proj_h(nrow(proj_ccloc_top)))
  
  
  
  # 04: Methods above/below 24-line threshold — CC distribution comparison
  p <- ggplot(df %>% filter(!is.na(loc_band), cc > 0),
              aes(x = cc, fill = loc_band, colour = loc_band)) +
    geom_density(alpha = 0.25, adjust = 1.5, linewidth = 0.9) +
    scale_x_log10(labels = label_comma()) +
    scale_fill_manual(values  = c("<=24 LOC" = "#2ca02c", ">24 LOC" = "#d62728")) +
    scale_colour_manual(values = c("<=24 LOC" = "#2ca02c", ">24 LOC" = "#d62728")) +
    labs(title = "CC Distribution: Methods Above vs Below 24-Line Threshold",
         subtitle = "Long methods (>24 LOC) — are they also more complex?",
         x = "Cyclomatic CC (log scale)", y = "Density",
         fill = NULL, colour = NULL) +
    theme_minimal(base_size = 12) +
    theme(legend.position = "top")
  sp(p, DIR_LOC, "04_cc_density_by_loc_band.png")
  
  # stats for the two LOC groups
  loc_band_stats <- df %>%
    filter(!is.na(loc_band)) %>%
    group_by(loc_band) %>%
    summarise(n = n(), median_cc = median(cc), mean_cc = mean(cc),
              pct_cc_gt10 = round(100 * mean(cc > 10), 1), .groups = "drop")
  write_csv(loc_band_stats, file.path(DIR_TABLES, "cc_by_loc_band.csv"))

  # Spearman correlation — more appropriate than Pearson for these skewed distributions
  spearman_cc_loc <- cor.test(df$cc, df$loc, method = "spearman", exact = FALSE)
  cat(sprintf("Spearman correlation (CC vs LOC): rho = %.4f, p = %.4e\n",
              spearman_cc_loc$estimate, spearman_cc_loc$p.value))

  # Mann-Whitney U — tests whether CC is significantly different between the two LOC bands
  cc_short <- df$cc[df$loc_band == "<=24 LOC"]
  cc_long  <- df$cc[df$loc_band == ">24 LOC"]
  mw <- wilcox.test(cc_short, cc_long, alternative = "two.sided")

  # Effect size: with N this large p-values are meaningless, so report Cliff's
  # delta (= rank-biserial correlation) derived from the U statistic.
  n1 <- length(cc_short); n2 <- length(cc_long)
  cliffs_delta <- 2 * as.numeric(mw$statistic) / (n1 * n2) - 1

  cat(sprintf("Mann-Whitney U test (CC: <=24 vs >24 LOC):\n"))
  cat(sprintf("  W = %.0f, p = %.4e\n",         mw$statistic, mw$p.value))
  cat(sprintf("  Median CC (<=24 LOC) : %.1f\n", median(cc_short)))
  cat(sprintf("  Median CC  (>24 LOC) : %.1f\n", median(cc_long)))
  cat(sprintf("  n (<=24 LOC): %d,  n (>24 LOC): %d\n", n1, n2))
  cat(sprintf("  Cliff's delta (effect size): %.4f\n", cliffs_delta))

  write_csv(
    tibble(
      test        = c("Spearman (CC vs LOC)", "Mann-Whitney (CC: <=24 vs >24 LOC)"),
      statistic   = c(round(as.numeric(spearman_cc_loc$estimate), 4), round(as.numeric(mw$statistic), 0)),
      p_value     = c(spearman_cc_loc$p.value, mw$p.value),
      effect_size = c(round(as.numeric(spearman_cc_loc$estimate), 4), round(cliffs_delta, 4)),
      effect_type = c("Spearman rho", "Cliff's delta (rank-biserial)")
    ),
    file.path(DIR_TABLES, "statistical_tests.csv")
  )
}

# =============================================================================
# 12. NAMING QUALITY  →  03_risk_bands
# =============================================================================

if (has_id) {
  cat("Generating naming quality plots...\n")
  
  # 01: Abbreviated ratio vs avg_id_words scatter, coloured by CC band
  p <- ggplot(df %>% filter(!is.na(risk_band), !is.na(avg_id_words),
                            !is.na(abbreviated_ratio)) %>%
                sample_frac(min(1, 300000 / nrow(.))),
              aes(x = avg_id_words, y = abbreviated_ratio, colour = risk_band)) +
    geom_point(alpha = 0.12, size = 0.5) +
    scale_colour_manual(values = BAND_COLOURS) +
    scale_y_continuous(labels = percent_format()) +
    labs(title = "Abbreviated Ratio vs Avg ID Word Count, Coloured by CC Band",
         subtitle = "Bottom-right = long descriptive names; top-left = short cryptic names",
         x = "Avg Identifier Word Count", y = "Abbreviated Identifier Ratio",
         colour = "CC Band") +
    guides(colour = guide_legend(override.aes = list(alpha = 1, size = 2))) +
    theme_minimal(base_size = 12) +
    theme(legend.position = "top")
  sp(p, DIR_BANDS, "17_abbrev_ratio_vs_id_words_by_cc_band.png")
  
  
  # 03: Naming score violin by CC band
  p <- ggplot(df %>% filter(!is.na(risk_band), !is.na(naming_score)),
              aes(x = risk_band, y = naming_score, fill = risk_band)) +
    geom_violin(alpha = 0.4, trim = TRUE) +
    geom_boxplot(width = 0.1, outlier.size = 0.3, outlier.alpha = 0.15, alpha = 0.9) +
    scale_fill_manual(values = BAND_COLOURS) +
    labs(title = "Naming Quality Score by CC Risk Band",
         subtitle = "Does naming quality degrade as complexity increases?",
         x = "CC Risk Band", y = "Naming Score") +
    theme_minimal(base_size = 12) +
    theme(legend.position = "none")
  sp(p, DIR_BANDS, "18_naming_score_violin_by_cc_band.png", w = 8, h = 5)
  
  
  # naming band summary table
  naming_band_summary <- df %>%
    filter(!is.na(risk_band)) %>%
    group_by(risk_band) %>%
    summarise(
      median_naming     = round(median(naming_score,      na.rm = TRUE), 3),
      median_id_words   = round(median(avg_id_words,      na.rm = TRUE), 3),
      median_abbrev     = round(median(abbreviated_ratio, na.rm = TRUE), 3),
      median_single_ids = round(median(single_letter_ids, na.rm = TRUE), 1),
      .groups = "drop"
    )
  write_csv(naming_band_summary, file.path(DIR_TABLES, "naming_by_cc_band.csv"))
}

# =============================================================================
# 13. COMMENT BEHAVIOUR  →  03_risk_bands
# =============================================================================

if (has_comments) {
  cat("Generating comment behaviour plots...\n")
  
  # 01: CC density overlay by comment presence (cleaner than boxplot at this scale)
  p <- ggplot(df %>% filter(cc > 0, !is.na(has_comment_flag)),
              aes(x = cc, fill = has_comment_flag, colour = has_comment_flag)) +
    geom_density(alpha = 0.25, adjust = 1.5, linewidth = 0.9) +
    scale_x_log10(labels = label_comma()) +
    scale_fill_manual(values  = c("TRUE" = "#2ca02c", "FALSE" = "#d62728"),
                      labels  = c("TRUE" = "Has comments", "FALSE" = "No comments")) +
    scale_colour_manual(values = c("TRUE" = "#2ca02c", "FALSE" = "#d62728"),
                        labels = c("TRUE" = "Has comments", "FALSE" = "No comments")) +
    labs(title = "CC Distribution: Methods With vs Without Comments",
         subtitle = "Are higher-complexity methods more likely to be commented?",
         x = "Cyclomatic CC (log scale)", y = "Density",
         fill = NULL, colour = NULL) +
    theme_minimal(base_size = 12) +
    theme(legend.position = "top")
  sp(p, DIR_BANDS, "19_cc_density_by_comment_presence.png")
  
  # Wilcoxon test result + effect size saved to table.
  # Formula groups by factor(has_comment_flag): first level FALSE, so W is the
  # U statistic for the "no comments" group; Cliff's delta = 2W/(n1*n2) - 1.
  cmp_df  <- df %>% filter(!is.na(has_comment_flag))
  wtest   <- wilcox.test(cc ~ has_comment_flag, data = cmp_df)
  n_false <- sum(!cmp_df$has_comment_flag)
  n_true  <- sum(cmp_df$has_comment_flag)
  cliffs_delta_comment <- 2 * as.numeric(wtest$statistic) / (n_false * n_true) - 1
  write_csv(
    tibble(test = "Wilcoxon CC ~ has_comments",
           W    = wtest$statistic,
           p    = wtest$p.value,
           cliffs_delta          = round(cliffs_delta_comment, 4),
           median_cc_commented   = median(df$cc[df$has_comment_flag  == TRUE],  na.rm = TRUE),
           median_cc_uncommented = median(df$cc[df$has_comment_flag  == FALSE], na.rm = TRUE)),
    file.path(DIR_TABLES, "wilcoxon_cc_comment_presence.csv")
  )
  
  
  # 03: Comment rate trend across CC values (smoothed line)
  comment_by_cc <- df %>%
    filter(cc <= 50) %>%
    group_by(cc) %>%
    summarise(
      pct_commented = round(100 * mean(comment_count > 0, na.rm = TRUE), 1),
      n             = n(),
      .groups = "drop"
    ) %>%
    filter(n >= 50)  # only CC values with enough data
  
  p <- ggplot(comment_by_cc, aes(x = cc, y = pct_commented)) +
    geom_line(colour = "#2ca02c", linewidth = 0.8) +
    geom_point(aes(size = n), alpha = 0.5, colour = "#2ca02c") +
    geom_smooth(method = "loess", span = 0.4, colour = "orange",
                se = TRUE, linewidth = 0.9) +
    scale_size_continuous(range = c(1, 6), name = "Methods at CC") +
    scale_x_continuous(breaks = c(1, 5, 10, 15, 20, 25, 30, 40, 50)) +
    geom_vline(xintercept = BAND_BREAKS, linetype = "dashed",
               colour = BAND_COLOURS[-length(BAND_COLOURS)], linewidth = 0.5) +
    labs(title = "Comment Rate Across CC Values",
         subtitle = "% of methods with comments at each CC value (CC 1-50, min 50 methods per point)",
         x = "Cyclomatic CC", y = "% Methods With Comments") +
    theme_minimal(base_size = 12)
  sp(p, DIR_BANDS, "20_comment_rate_across_cc_values.png", w = 10, h = 6)
  
  write_csv(comment_by_cc, file.path(DIR_TABLES, "comment_rate_by_cc_value.csv"))
}

# =============================================================================
# 14. PROJECT DEEP DIVE  →  04_projects
# =============================================================================

cat("Generating project deep dive plots...\n")

# 01: Small multiples — CC density for each project (faceted)
# Keep only projects with enough methods to form a meaningful density, and cap
# the number of facets so the grid stays readable and within the device limit.
proj_counts <- df %>% count(project) %>% filter(n >= 100) %>%
  slice_max(n, n = MAX_PROJ_BARS, with_ties = FALSE)

p <- ggplot(df %>% filter(project %in% proj_counts$project, cc > 0),
            aes(x = cc, fill = after_stat(x))) +
  geom_histogram(bins = 30, colour = "white", linewidth = 0.1) +
  scale_x_log10(labels = label_comma()) +
  scale_y_log10(labels = label_comma()) +
  scale_fill_viridis_c(trans = "log10", guide = "none") +
  facet_wrap(~ str_extract(project, "[^/]+$"),
             scales = "free_y", ncol = 6) +
  labs(title = "CC Distribution — Small Multiples per Project",
       subtitle = sprintf("%d largest projects (>= 100 methods); y free (count, log), x fixed (CC, log)",
                          nrow(proj_counts)),
       x = "CC (log scale)", y = "Count (log scale)") +
  theme_minimal(base_size = 7) +
  theme(strip.text = element_text(size = 5.5, face = "bold"),
        axis.text  = element_text(size = 5))

n_shown <- nrow(proj_counts)
sp(p, DIR_PROJ,  "06_cc_small_multiples_per_project.png",
   w = 22, h = ceiling(n_shown / 6) * 2.5 + 2)

# =============================================================================
# 15. MODELLING: REGRESSION, PARTIAL CORRELATION, PCA, REDUNDANCY  →  09_modelling
# =============================================================================

cat("Running modelling / multivariate analysis...\n")

# ── 15A. MULTIPLE REGRESSION — what independently predicts cognitive load? ─────
# CC and LOC are confounded (longer methods have more branches), so a simple
# CC-vs-cognitive correlation overstates CC's role. Regressing cognitive
# complexity on CC, LOC and nesting together isolates each one's contribution.

reg_inputs <- c("cognitive_complexity", "cc", "loc", "max_nesting")
if (all(reg_inputs %in% names(df))) {
  model_df <- df %>% select(all_of(reg_inputs)) %>% drop_na()

  fit <- lm(cognitive_complexity ~ cc + loc + max_nesting, data = model_df)
  fit_glance <- broom::glance(fit)
  write_csv(broom::tidy(fit), file.path(DIR_TABLES, "regression_cognitive_coefficients.csv"))
  write_csv(fit_glance,       file.path(DIR_TABLES, "regression_cognitive_fit.csv"))

  cat(sprintf("  lm(cognitive ~ cc + loc + max_nesting): adj R^2 = %.3f\n",
              fit_glance$adj.r.squared))

  # Standardised coefficients make the predictors directly comparable.
  std_df  <- model_df %>% mutate(across(everything(), ~ as.numeric(scale(.))))
  fit_std <- lm(cognitive_complexity ~ cc + loc + max_nesting, data = std_df)
  std_coefs <- broom::tidy(fit_std) %>% filter(term != "(Intercept)") %>%
    mutate(term = recode(term, !!!nice_names))

  p_coef <- ggplot(std_coefs, aes(x = reorder(term, estimate), y = estimate)) +
    geom_col(fill = "#4C72B0", alpha = 0.85) +
    geom_errorbar(aes(ymin = estimate - 1.96 * std.error,
                      ymax = estimate + 1.96 * std.error), width = 0.2) +
    coord_flip() +
    labs(title = "Standardised Predictors of Cognitive Complexity",
         subtitle = sprintf("lm(cognitive ~ cc + loc + max_nesting); adj R² = %.3f",
                            fit_glance$adj.r.squared),
         x = NULL, y = "Standardised coefficient (95% CI)") +
    theme_minimal(base_size = 12)
  sp(p_coef, DIR_MODEL, "01_cognitive_regression_coefficients.png", w = 8, h = 5)
}

# ── 15B. PARTIAL CORRELATIONS — correlation with confounders held constant ─────
if (!requireNamespace("ppcor", quietly = TRUE)) install.packages("ppcor")

pcor_cols <- intersect(
  c("cc", "cognitive_complexity", "loc", "max_nesting", "halstead_volume", "fan_out"),
  names(df))

if (length(pcor_cols) >= 3) {
  pcor_df <- df %>% select(all_of(pcor_cols)) %>% drop_na()
  pcor_res <- tryCatch(
    ppcor::pcor(pcor_df, method = "spearman"),
    error = function(e) { cat("  Partial correlation failed:", conditionMessage(e), "\n"); NULL })

  if (!is.null(pcor_res)) {
    est <- pcor_res$estimate
    dimnames(est) <- list(pcor_cols, pcor_cols)
    write_csv(as_tibble(est, rownames = "metric"),
              file.path(DIR_TABLES, "partial_correlations.csv"))

    pcor_long <- as_tibble(est, rownames = "var1") %>%
      pivot_longer(-var1, names_to = "var2", values_to = "r") %>%
      mutate(var1 = recode(var1, !!!nice_names),
             var2 = recode(var2, !!!nice_names),
             label = sprintf("%.2f", r))
    p_pcor <- ggplot(pcor_long, aes(x = var1, y = var2, fill = r)) +
      geom_tile(colour = "white", linewidth = 0.3) +
      geom_text(aes(label = label), size = 3) +
      scale_fill_gradient2(low = "#d62728", mid = "white", high = "#1f77b4",
                           midpoint = 0, limits = c(-1, 1), name = "Partial rho") +
      labs(title = "Spearman Partial Correlations",
           subtitle = "Each cell controls for all other metrics in the set",
           x = NULL, y = NULL) +
      theme_minimal(base_size = 11) +
      theme(axis.text.x = element_text(angle = 45, hjust = 1), panel.grid = element_blank())
    sp(p_pcor, DIR_MODEL, "02_partial_correlation_heatmap.png", w = 8, h = 7)
  }
}

# ── 15C. PCA — how many independent dimensions do the metrics span? ────────────
pca_cols <- intersect(
  c("cc", "cognitive_complexity", "loc", "loc_physical", "avg_nesting", "max_nesting",
    "avg_id_words", "abbreviated_ratio", "single_letter_ids", "longest_id",
    "total_words", "comment_count", "comment_words",
    "halstead_volume", "halstead_difficulty", "halstead_effort",
    "maintainability_index", "param_count", "return_count", "fan_out",
    "max_line_length", "avg_line_length"),
  names(df))

pca_data <- df %>% select(all_of(pca_cols)) %>% drop_na()
pca_data <- pca_data[, vapply(pca_data, function(x) sd(x) > 0, logical(1)), drop = FALSE]

if (ncol(pca_data) >= 3 && nrow(pca_data) >= 10) {
  pca <- prcomp(pca_data, center = TRUE, scale. = TRUE)
  var_explained <- pca$sdev^2 / sum(pca$sdev^2)

  scree_df <- tibble(
    pc  = factor(paste0("PC", seq_along(var_explained)),
                 levels = paste0("PC", seq_along(var_explained))),
    var = var_explained,
    cum = cumsum(var_explained)
  ) %>% slice_head(n = min(12, nrow(.)))

  p_scree <- ggplot(scree_df, aes(x = pc)) +
    geom_col(aes(y = var), fill = "#4C72B0", alpha = 0.85) +
    geom_line(aes(y = cum, group = 1), colour = "orange", linewidth = 0.9) +
    geom_point(aes(y = cum), colour = "orange", size = 2) +
    scale_y_continuous(labels = percent_format()) +
    labs(title = "PCA Scree Plot — Variance Explained",
         subtitle = "Bars = per-component variance; line = cumulative",
         x = NULL, y = "Proportion of variance") +
    theme_minimal(base_size = 12)
  sp(p_scree, DIR_MODEL, "03_pca_scree.png", w = 9, h = 5)

  n_pc <- min(3, ncol(pca$rotation))
  loadings <- as_tibble(pca$rotation[, seq_len(n_pc), drop = FALSE], rownames = "metric")
  write_csv(loadings, file.path(DIR_TABLES, "pca_loadings.csv"))

  if (n_pc >= 2) {
    load_plot <- loadings %>% mutate(label = recode(metric, !!!nice_names))
    p_load <- ggplot(load_plot, aes(x = PC1, y = PC2)) +
      geom_segment(aes(x = 0, y = 0, xend = PC1, yend = PC2),
                   arrow = arrow(length = unit(0.18, "cm")), colour = "grey60") +
      geom_text(aes(label = label), size = 3, vjust = -0.4, check_overlap = TRUE) +
      geom_hline(yintercept = 0, linetype = "dashed", colour = "grey80") +
      geom_vline(xintercept = 0, linetype = "dashed", colour = "grey80") +
      labs(title = "PCA Variable Loadings (PC1 vs PC2)",
           subtitle = sprintf("PC1 = %.1f%%, PC2 = %.1f%% of variance",
                              100 * var_explained[1], 100 * var_explained[2]),
           x = "PC1 loading", y = "PC2 loading") +
      theme_minimal(base_size = 12)
    sp(p_load, DIR_MODEL, "04_pca_loadings.png", w = 9, h = 7)
  }

  # ── 15D. METRIC REDUNDANCY DENDROGRAM — which metrics collapse together? ─────
  # Distance = 1 - |Spearman rho|: metrics that move together cluster tightly.
  cor_spear <- cor(pca_data, method = "spearman", use = "pairwise.complete.obs")
  hc <- hclust(as.dist(1 - abs(cor_spear)), method = "average")
  hc$labels <- recode(hc$labels, !!!nice_names)

  png(file.path(DIR_MODEL, "05_metric_redundancy_dendrogram.png"),
      width = 1100, height = 750, res = 130)
  par(mar = c(3, 4, 4, 8))
  plot(as.dendrogram(hc), horiz = TRUE,
       main = "Metric Redundancy (1 - |Spearman rho|)",
       xlab = "Distance")
  dev.off()
}

cat("Modelling analysis complete.\n")