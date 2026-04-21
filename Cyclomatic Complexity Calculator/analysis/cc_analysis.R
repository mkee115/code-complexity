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
cat("\nDone\n")