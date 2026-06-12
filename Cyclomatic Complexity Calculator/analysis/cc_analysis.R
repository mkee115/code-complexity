library(tidyverse)
library(ggplot2)
library(scales)
library(moments)

# 0. CONFIGURATION

INPUT_FILE  <- "cc_data.csv"
OUTPUT_DIR  <- "output"
CC_COL      <- "cc"

# Risk band upper bounds (final band catches everything above the last value)
BAND_BREAKS  <- c(5, 10, 15, 25)
BAND_LABELS  <- c("1-5", "6-10", "11-15", "16-25", "25+")
BAND_COLOURS <- c("#2ca02c", "#8fbc8f", "#ff7f0e", "#d62728", "#9467bd")

dir.create(OUTPUT_DIR, showWarnings = FALSE)

# 1. DATA LOADING & VALIDATION

cat("Loading data...\n")
df <- read_csv(INPUT_FILE, show_col_types = FALSE)

required_cols <- c("method_name", "class_name", "project", CC_COL)
missing <- setdiff(required_cols, names(df))
if (length(missing) > 0) {
  stop("Missing required columns: ", paste(missing, collapse = ", "))
}

df <- df %>%
  filter(!is.na(.data[[CC_COL]]), .data[[CC_COL]] >= 1)

# TEMP: fake cogcc for testing — remove once Java tool has been re-run
df$cogcc <- df$cc + sample(-2:2, nrow(df), replace = TRUE)

cc <- df[[CC_COL]]
n  <- nrow(df)

cat(sprintf("Loaded %d methods across %d projects.\n", n, n_distinct(df$project)))

# 2. DESCRIPTIVE STATISTICS

cat("\n-- Descriptive Statistics (CC) --\n")

desc_stats <- tibble(
  Statistic = c("n", "Min", "Q1", "Median", "Mean", "Q3",
                "Max", "SD", "Skewness", "Kurtosis",
                paste0("% CC > ", BAND_BREAKS)),
  Value = c(
    n,
    min(cc), quantile(cc, 0.25), median(cc), mean(cc),
    quantile(cc, 0.75), max(cc), sd(cc),
    skewness(cc), kurtosis(cc),
    sapply(BAND_BREAKS, function(t) round(100 * mean(cc > t), 2))
  )
)
print(desc_stats, n = Inf)
write_csv(desc_stats, file.path(OUTPUT_DIR, "descriptive_stats.csv"))

# 3. RISK BAND CLASSIFICATION

df <- df %>%
  mutate(risk_band = cut(
    .data[[CC_COL]],
    breaks = c(0, BAND_BREAKS, Inf),
    labels = BAND_LABELS,
    right  = TRUE
  ))

band_summary <- df %>%
  count(risk_band) %>%
  mutate(pct = round(100 * n / sum(n), 2))

cat("\n-- Risk Band Distribution --\n")
print(band_summary)
write_csv(band_summary, file.path(OUTPUT_DIR, "risk_band_summary.csv"))

# 4. PER-PROJECT SUMMARY

project_summary <- df %>%
  group_by(project) %>%
  summarise(
    n_methods    = n(),
    median_cc    = median(.data[[CC_COL]]),
    mean_cc      = round(mean(.data[[CC_COL]]), 2),
    sd_cc        = round(sd(.data[[CC_COL]]), 2),
    max_cc       = max(.data[[CC_COL]]),
    pct_above_5  = round(100 * mean(.data[[CC_COL]] > 5),  2),
    pct_above_10 = round(100 * mean(.data[[CC_COL]] > 10), 2),
    pct_above_25 = round(100 * mean(.data[[CC_COL]] > 25), 2),
    .groups = "drop"
  ) %>%
  arrange(desc(median_cc))

cat("\n-- Per-Project Summary --\n")
print(project_summary, n = Inf)
write_csv(project_summary, file.path(OUTPUT_DIR, "project_summary.csv"))

# 5. TOP COMPLEX METHODS

top_methods <- df %>%
  select(project, class_name, method_name, all_of(CC_COL)) %>%
  arrange(desc(.data[[CC_COL]])) %>%
  slice_head(n = 50)

write_csv(top_methods, file.path(OUTPUT_DIR, "top50_complex_methods.csv"))

# 6. PLOTS

cat("\nGenerating plots...\n")

project_order <- project_summary %>% arrange(median_cc) %>% pull(project)

# 6a. Histogram (all data, binwidth = 1)
p_hist <- ggplot(df, aes(x = .data[[CC_COL]])) +
  geom_histogram(binwidth = 1, fill = "#4C72B0", colour = "white", linewidth = 0.2) +
  geom_vline(xintercept = BAND_BREAKS,
             linetype  = "dashed",
             colour    = BAND_COLOURS[-length(BAND_COLOURS)],
             linewidth = 0.7) +
  labs(title = "Distribution of Cyclomatic Complexity",
       x = "Cyclomatic Complexity", y = "Method Count") +
  theme_minimal(base_size = 12)

ggsave(file.path(OUTPUT_DIR, "01_cc_histogram.png"), p_hist,
       width = 8, height = 5, dpi = 150)

# 6b. Risk band bar chart
p_band <- ggplot(band_summary, aes(x = risk_band, y = pct, fill = risk_band)) +
  geom_col(show.legend = FALSE) +
  geom_text(aes(label = paste0(pct, "%")), vjust = -0.4, size = 3.5) +
  scale_fill_manual(values = BAND_COLOURS) +
  labs(title = "Methods by CC Risk Band",
       x = "CC Band", y = "Percentage of Methods (%)") +
  theme_minimal(base_size = 12)

ggsave(file.path(OUTPUT_DIR, "02_risk_bands.png"), p_band,
       width = 7, height = 5, dpi = 150)

# 6c. Boxplot per project (all data)
p_box <- ggplot(df, aes(x = factor(project, levels = project_order),
                        y = .data[[CC_COL]])) +
  geom_boxplot(outlier.size = 0.8, outlier.alpha = 0.4,
               fill = "#4C72B0", alpha = 0.7) +
  coord_flip() +
  geom_hline(yintercept = BAND_BREAKS,
             linetype  = "dashed",
             colour    = BAND_COLOURS[-length(BAND_COLOURS)],
             linewidth = 0.5) +
  labs(title = "CC Distribution per Project",
       x = "Project", y = "Cyclomatic Complexity") +
  theme_minimal(base_size = 11)

ggsave(file.path(OUTPUT_DIR, "03_project_boxplots.png"), p_box,
       width = 9, height = max(5, n_distinct(df$project) * 0.4 + 2), dpi = 150)

# 6d. Empirical CDF (all data)
# For any CC value on the x-axis, shows what % of methods score at or below it.
p_ecdf <- ggplot(df, aes(x = .data[[CC_COL]])) +
  stat_ecdf(geom = "step", colour = "#4C72B0", linewidth = 0.9) +
  geom_vline(xintercept = BAND_BREAKS,
             linetype  = "dashed",
             colour    = BAND_COLOURS[-length(BAND_COLOURS)],
             linewidth = 0.5) +
  scale_y_continuous(labels = percent_format()) +
  labs(title    = "Empirical CDF of Cyclomatic Complexity",
       subtitle = "For a given CC value, shows what % of methods score at or below it",
       x = "Cyclomatic Complexity", y = "% of Methods") +
  theme_minimal(base_size = 12)

ggsave(file.path(OUTPUT_DIR, "04_ecdf.png"), p_ecdf,
       width = 8, height = 5, dpi = 150)

# 7. NORMALITY TESTS

cat("\n-- Normality Tests --\n")

sw_sample <- sample(cc, min(5000, length(cc)))
sw <- shapiro.test(sw_sample)
cat(sprintf("Shapiro-Wilk (n=%d sample): W = %.4f, p = %.4e\n",
            length(sw_sample), sw$statistic, sw$p.value))

log_mean <- mean(log(cc))
log_sd   <- sd(log(cc))
ks <- ks.test(cc, "plnorm", meanlog = log_mean, sdlog = log_sd)
cat(sprintf("KS test vs log-normal fit: D = %.4f, p = %.4e\n",
            ks$statistic, ks$p.value))

# 8. SUMMARY REPORT

report_lines <- c(
  "# CC Analysis Summary",
  sprintf("Generated: %s", Sys.time()),
  sprintf("Total methods: %d", n),
  sprintf("Projects: %d", n_distinct(df$project)),
  "",
  "## Overall CC",
  sprintf("  Median:   %g",   median(cc)),
  sprintf("  Mean:     %.2f", mean(cc)),
  sprintf("  SD:       %.2f", sd(cc)),
  sprintf("  Max:      %g",   max(cc)),
  sprintf("  Skewness: %.2f", skewness(cc)),
  "",
  "## Risk band proportions",
  paste(apply(band_summary, 1, function(r)
    sprintf("  CC %s: %s%%", r["risk_band"], r["pct"])), collapse = "\n")
)

writeLines(report_lines, file.path(OUTPUT_DIR, "summary_report.txt"))

# 9. LOC ANALYSIS

cat("\nGenerating LOC plots...\n")

loc <- df$loc

# Descriptive stats for LOC
loc_stats <- tibble(
  Statistic = c("n", "Min", "Q1", "Median", "Mean", "Q3", "Max", "SD",
                "% LOC > 24"),
  Value = c(
    nrow(df), min(loc), quantile(loc, 0.25), median(loc), mean(loc),
    quantile(loc, 0.75), max(loc), sd(loc),
    round(100 * mean(loc > 24), 2)
  )
)
cat("\n-- Descriptive Statistics (LOC) --\n")
print(loc_stats, n = Inf)
write_csv(loc_stats, file.path(OUTPUT_DIR, "loc_descriptive_stats.csv"))

# 9a. LOC histogram with 24-line threshold
p_loc_hist <- ggplot(df, aes(x = loc)) +
  geom_histogram(binwidth = 1, fill = "#e377c2", colour = "white", linewidth = 0.2) +
  geom_vline(xintercept = 24, linetype = "dashed", colour = "red", linewidth = 0.8) +
  annotate("text", x = 26, y = Inf, label = "24-line threshold",
           colour = "red", hjust = 0, vjust = 1.5, size = 3.5) +
  labs(title = "Distribution of LOC per Method",
       x = "Lines of Code", y = "Method Count") +
  theme_minimal(base_size = 12)

ggsave(file.path(OUTPUT_DIR, "05_loc_histogram.png"), p_loc_hist,
       width = 8, height = 5, dpi = 150)

# 9b. CC vs LOC scatter plot
p_scatter <- ggplot(df, aes(x = loc, y = cc)) +
  geom_point(alpha = 0.2, size = 0.8, colour = "#4C72B0") +
  geom_vline(xintercept = 24, linetype = "dashed", colour = "red", linewidth = 0.7) +
  geom_smooth(method = "lm", colour = "orange", se = TRUE) +
  labs(title = "Cyclomatic Complexity vs Lines of Code",
       x = "Lines of Code", y = "Cyclomatic Complexity") +
  theme_minimal(base_size = 12)

ggsave(file.path(OUTPUT_DIR, "06_cc_vs_loc_scatter.png"), p_scatter,
       width = 8, height = 5, dpi = 150)

# 9c. Box plots of CC split by above/below 24-line threshold
df <- df %>%
  mutate(loc_band = ifelse(loc <= 24, "≤24 lines", ">24 lines"))

p_loc_cc_box <- ggplot(df, aes(x = loc_band, y = cc, fill = loc_band)) +
  geom_boxplot(outlier.size = 0.8, outlier.alpha = 0.4, alpha = 0.7) +
  scale_fill_manual(values = c("≤24 lines" = "#2ca02c", ">24 lines" = "#d62728")) +
  labs(title = "CC Distribution: Methods Above vs Below 24-Line Threshold",
       x = "", y = "Cyclomatic Complexity") +
  theme_minimal(base_size = 12) +
  theme(legend.position = "none")

ggsave(file.path(OUTPUT_DIR, "07_cc_by_loc_band.png"), p_loc_cc_box,
       width = 6, height = 5, dpi = 150)

# Pearson and Spearman correlations (CC vs LOC)
cat(sprintf("\nPearson correlation  (CC vs LOC): r   = %.4f\n", cor(df$cc, df$loc)))
spearman_cc_loc <- cor.test(df$cc, df$loc, method = "spearman", exact = FALSE)
cat(sprintf("Spearman correlation (CC vs LOC): rho = %.4f, p = %.4e\n",
            spearman_cc_loc$estimate, spearman_cc_loc$p.value))

# 9d. CC vs LOC on log-log scale (reveals structure hidden by outliers in 9b)
p_scatter_log <- ggplot(df %>% filter(loc >= 1, cc >= 1), aes(x = loc, y = cc)) +
  geom_point(alpha = 0.2, size = 0.8, colour = "#4C72B0") +
  geom_vline(xintercept = 24, linetype = "dashed", colour = "red", linewidth = 0.7) +
  geom_smooth(method = "lm", colour = "orange", se = TRUE) +
  scale_x_log10() +
  scale_y_log10() +
  annotation_logticks(sides = "bl", colour = "grey60", linewidth = 0.3) +
  labs(title    = "CC vs LOC (log-log scale)",
       subtitle = "Log scales reduce distortion from extreme outliers",
       x = "Lines of Code (log scale)", y = "Cyclomatic Complexity (log scale)") +
  theme_minimal(base_size = 12)

ggsave(file.path(OUTPUT_DIR, "11_cc_vs_loc_log_scatter.png"), p_scatter_log,
       width = 8, height = 5, dpi = 150)

# 10. STATISTICAL TESTS

cat("\n-- Statistical Tests --\n")

# Mann-Whitney U: is CC significantly different between ≤24 and >24 LOC methods?
cc_short <- df$cc[df$loc_band == "≤24 lines"]
cc_long  <- df$cc[df$loc_band == ">24 lines"]

mw <- wilcox.test(cc_short, cc_long, alternative = "two.sided")
cat(sprintf("Mann-Whitney U test (CC: ≤24 vs >24 LOC):\n"))
cat(sprintf("  W = %.0f, p = %.4e\n",        mw$statistic, mw$p.value))
cat(sprintf("  Median CC (≤24 LOC): %.1f\n", median(cc_short)))
cat(sprintf("  Median CC  (>24 LOC): %.1f\n", median(cc_long)))
cat(sprintf("  n (≤24 LOC): %d,  n (>24 LOC): %d\n",
            length(cc_short), length(cc_long)))

test_results <- tibble(
  test      = c("Spearman rho (CC vs LOC)", "Mann-Whitney W (CC: ≤24 vs >24 LOC)"),
  statistic = c(round(as.numeric(spearman_cc_loc$estimate), 4), round(mw$statistic, 0)),
  p_value   = c(spearman_cc_loc$p.value, mw$p.value)
)
write_csv(test_results, file.path(OUTPUT_DIR, "statistical_tests.csv"))

# 11. COGNITIVE COMPLEXITY ANALYSIS

if ("cogcc" %in% names(df)) {

  cat("\nGenerating cognitive complexity plots...\n")

  df_cog <- df %>% filter(!is.na(cogcc))
  cogcc  <- df_cog$cogcc

  # Descriptive stats
  cogcc_stats <- tibble(
    Statistic = c("n", "Min", "Q1", "Median", "Mean", "Q3", "Max", "SD",
                  "Skewness", "Kurtosis",
                  paste0("% CogCC > ", BAND_BREAKS)),
    Value = c(
      length(cogcc),
      min(cogcc), quantile(cogcc, 0.25), median(cogcc), mean(cogcc),
      quantile(cogcc, 0.75), max(cogcc), sd(cogcc),
      skewness(cogcc), kurtosis(cogcc),
      sapply(BAND_BREAKS, function(t) round(100 * mean(cogcc > t), 2))
    )
  )
  cat("\n-- Descriptive Statistics (CogCC) --\n")
  print(cogcc_stats, n = Inf)
  write_csv(cogcc_stats, file.path(OUTPUT_DIR, "cogcc_descriptive_stats.csv"))

  cat(sprintf("\nCorrelation (CogCC vs CC):  %.4f\n", cor(cogcc, df_cog[[CC_COL]])))
  cat(sprintf("Correlation (CogCC vs LOC): %.4f\n", cor(cogcc, df_cog$loc)))

  # 10a. CogCC histogram
  p_cogcc_hist <- ggplot(df_cog, aes(x = cogcc)) +
    geom_histogram(binwidth = 1, fill = "#dd8452", colour = "white", linewidth = 0.2) +
    geom_vline(xintercept = BAND_BREAKS,
               linetype  = "dashed",
               colour    = BAND_COLOURS[-length(BAND_COLOURS)],
               linewidth = 0.7) +
    labs(title = "Distribution of Cognitive Complexity",
         x = "Cognitive Complexity", y = "Method Count") +
    theme_minimal(base_size = 12)

  ggsave(file.path(OUTPUT_DIR, "08_cogcc_histogram.png"), p_cogcc_hist,
         width = 8, height = 5, dpi = 150)

  # 10b. CC vs CogCC scatter — dashed 1:1 line shows where they diverge
  p_cc_cogcc <- ggplot(df_cog, aes(x = .data[[CC_COL]], y = cogcc)) +
    geom_point(alpha = 0.15, size = 0.8, colour = "#4C72B0") +
    geom_abline(slope = 1, intercept = 0, linetype = "dashed",
                colour = "red", linewidth = 0.7) +
    geom_smooth(method = "lm", colour = "orange", se = TRUE) +
    labs(title    = "Cognitive Complexity vs Cyclomatic Complexity",
         subtitle = "Red dashed = 1:1 reference; orange = linear fit",
         x = "Cyclomatic Complexity", y = "Cognitive Complexity") +
    theme_minimal(base_size = 12)

  ggsave(file.path(OUTPUT_DIR, "09_cc_vs_cogcc_scatter.png"), p_cc_cogcc,
         width = 8, height = 5, dpi = 150)

  # 10c. CogCC split by above/below 24-line threshold (mirrors graph 07)
  p_cogcc_loc_box <- ggplot(df_cog, aes(x = loc_band, y = cogcc, fill = loc_band)) +
    geom_boxplot(outlier.size = 0.8, outlier.alpha = 0.4, alpha = 0.7) +
    scale_fill_manual(values = c("≤24 lines" = "#2ca02c", ">24 lines" = "#d62728")) +
    labs(title = "Cognitive Complexity: Methods Above vs Below 24-Line Threshold",
         x = "", y = "Cognitive Complexity") +
    theme_minimal(base_size = 12) +
    theme(legend.position = "none")

  ggsave(file.path(OUTPUT_DIR, "10_cogcc_by_loc_band.png"), p_cogcc_loc_box,
         width = 6, height = 5, dpi = 150)

} else {
  cat("\nNote: 'cogcc' column not found — skipping cognitive complexity plots.\n")
  cat("Re-run the Java tool to generate a CSV with the cogcc column.\n")
}

cat("\nDone\n")