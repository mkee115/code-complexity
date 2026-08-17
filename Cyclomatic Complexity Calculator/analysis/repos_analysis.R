library(tidyverse)
library(ggplot2)
library(scales)

# 0. CONFIGURATION

# CSV inputs/tables live in data_tables/; plots go to graphs/.
DATA_DIR   <- "data_tables"
OUTPUT_DIR <- "graphs"          # plots
INPUT_FILE <- file.path(DATA_DIR, "repos.csv")

dir.create(DATA_DIR, showWarnings = FALSE, recursive = TRUE)
dir.create(OUTPUT_DIR, showWarnings = FALSE, recursive = TRUE)

# 1. DATA LOADING

cat("Loading data...\n")
df <- read_csv(INPUT_FILE, show_col_types = FALSE)

df <- df %>%
  mutate(
    created_at = as.POSIXct(created_at, format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    pushed_at  = as.POSIXct(pushed_at,  format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    scraped_at = as.Date(scraped_at)
  ) %>%
  mutate(
    age_days        = as.numeric(scraped_at - as.Date(created_at)),
    days_since_push = as.numeric(scraped_at - as.Date(pushed_at))
  )

n <- nrow(df)
cat(sprintf("Loaded %d repositories.\n", n))

# 2. SUMMARY STATS

summarise_col <- function(x, label) {
  x <- x[!is.na(x)]
  cat(sprintf("\n-- %s --\n", label))
  cat(sprintf("  Min:    %g\n",   min(x)))
  cat(sprintf("  Q1:     %g\n",   quantile(x, 0.25)))
  cat(sprintf("  Median: %g\n",   median(x)))
  cat(sprintf("  Mean:   %.2f\n", mean(x)))
  cat(sprintf("  Q3:     %g\n",   quantile(x, 0.75)))
  cat(sprintf("  Max:    %g\n",   max(x)))
  cat(sprintf("  SD:     %.2f\n", sd(x)))
}

cat(sprintf("\nTotal repos:       %d\n", n))
cat(sprintf("Total Java files:  %d\n", sum(df$java_file_count, na.rm = TRUE)))

summarise_col(df$stars,          "Stars")
summarise_col(df$forks,          "Forks")
summarise_col(df$size_kb,        "Size (KB)")
summarise_col(df$commit_count[df$commit_count >= 0], "Commit Count")
summarise_col(df$java_file_count, "Java File Count")
summarise_col(df$age_days,        "Repo Age (days)")
summarise_col(df$days_since_push, "Days Since Last Push")

cat("\n-- Top 10 by Stars --\n")
top_stars <- df %>% arrange(desc(stars)) %>% slice_head(n = 10) %>%
  select(full_name, stars)
print(top_stars, n = Inf)

cat("\n-- Top 10 by Commit Count --\n")
top_commits <- df %>% filter(commit_count >= 0) %>%
  arrange(desc(commit_count)) %>% slice_head(n = 10) %>%
  select(full_name, commit_count)
print(top_commits, n = Inf)

cat("\n-- Top 10 by Java File Count --\n")
top_java <- df %>% arrange(desc(java_file_count)) %>% slice_head(n = 10) %>%
  select(full_name, java_file_count)
print(top_java, n = Inf)

# 3. WRITE SUMMARY REPORT

report_lines <- c(
  "# Repos Analysis Summary",
  sprintf("Generated: %s", Sys.time()),
  sprintf("Total repos: %d", n),
  sprintf("Total Java files: %d", sum(df$java_file_count, na.rm = TRUE)),
  "",
  "## Stars",
  sprintf("  Min: %g  Q1: %g  Median: %g  Mean: %.2f  Q3: %g  Max: %g  SD: %.2f",
          min(df$stars), quantile(df$stars, 0.25), median(df$stars),
          mean(df$stars), quantile(df$stars, 0.75), max(df$stars), sd(df$stars)),
  "",
  "## Forks",
  sprintf("  Min: %g  Q1: %g  Median: %g  Mean: %.2f  Q3: %g  Max: %g  SD: %.2f",
          min(df$forks), quantile(df$forks, 0.25), median(df$forks),
          mean(df$forks), quantile(df$forks, 0.75), max(df$forks), sd(df$forks)),
  "",
  "## Size (KB)",
  sprintf("  Min: %g  Q1: %g  Median: %g  Mean: %.2f  Q3: %g  Max: %g  SD: %.2f",
          min(df$size_kb), quantile(df$size_kb, 0.25), median(df$size_kb),
          mean(df$size_kb), quantile(df$size_kb, 0.75), max(df$size_kb), sd(df$size_kb)),
  "",
  "## Commit Count (excluding -1)",
  {
    cc <- df$commit_count[df$commit_count >= 0]
    sprintf("  Min: %g  Q1: %g  Median: %g  Mean: %.2f  Q3: %g  Max: %g  SD: %.2f",
            min(cc), quantile(cc, 0.25), median(cc),
            mean(cc), quantile(cc, 0.75), max(cc), sd(cc))
  },
  "",
  "## Java File Count",
  sprintf("  Min: %g  Q1: %g  Median: %g  Mean: %.2f  Q3: %g  Max: %g  SD: %.2f",
          min(df$java_file_count), quantile(df$java_file_count, 0.25),
          median(df$java_file_count), mean(df$java_file_count),
          quantile(df$java_file_count, 0.75), max(df$java_file_count),
          sd(df$java_file_count)),
  "",
  "## Repo Age (days)",
  sprintf("  Min: %g  Median: %g  Mean: %.2f  Max: %g",
          min(df$age_days, na.rm = TRUE), median(df$age_days, na.rm = TRUE),
          mean(df$age_days, na.rm = TRUE), max(df$age_days, na.rm = TRUE)),
  "",
  "## Days Since Last Push",
  sprintf("  Min: %g  Median: %g  Mean: %.2f  Max: %g",
          min(df$days_since_push, na.rm = TRUE), median(df$days_since_push, na.rm = TRUE),
          mean(df$days_since_push, na.rm = TRUE), max(df$days_since_push, na.rm = TRUE)),
  "",
  "## Top 10 by Stars",
  paste(sprintf("  %s (%d)", top_stars$full_name, top_stars$stars), collapse = "\n"),
  "",
  "## Top 10 by Commit Count",
  paste(sprintf("  %s (%d)", top_commits$full_name, top_commits$commit_count), collapse = "\n"),
  "",
  "## Top 10 by Java File Count",
  paste(sprintf("  %s (%d)", top_java$full_name, top_java$java_file_count), collapse = "\n")
)

writeLines(report_lines, file.path(DATA_DIR, "repos_summary.txt"))

# 4. PLOTS

cat("\nGenerating plots...\n")

# repos_01: Stars histogram (log-log)
suppressWarnings(
  p_stars <- ggplot(df, aes(x = stars)) +
    geom_histogram(fill = "#4C72B0", colour = "white", linewidth = 0.2, bins = 40) +
    scale_x_log10(labels = label_comma()) +
    scale_y_log10(labels = label_comma()) +
    labs(title = "Repository Star Count Distribution",
         x = "Stars (log scale)", y = "Count (log scale)") +
    theme_minimal(base_size = 12)
)
ggsave(file.path(OUTPUT_DIR, "repos_01_stars_hist.png"), p_stars,
       width = 8, height = 5, dpi = 150)

# repos_02: Forks histogram (log-log)
suppressWarnings(
  p_forks <- ggplot(df %>% filter(forks > 0), aes(x = forks)) +
    geom_histogram(fill = "#4C72B0", colour = "white", linewidth = 0.2, bins = 40) +
    scale_x_log10(labels = label_comma()) +
    scale_y_log10(labels = label_comma()) +
    labs(title = "Repository Fork Count Distribution",
         x = "Forks (log scale)", y = "Count (log scale)") +
    theme_minimal(base_size = 12)
)
ggsave(file.path(OUTPUT_DIR, "repos_02_forks_hist.png"), p_forks,
       width = 8, height = 5, dpi = 150)

# repos_03: Size histogram (log-log)
suppressWarnings(
  p_size <- ggplot(df %>% filter(size_kb > 0), aes(x = size_kb)) +
    geom_histogram(fill = "#4C72B0", colour = "white", linewidth = 0.2, bins = 40) +
    scale_x_log10(labels = label_comma()) +
    scale_y_log10(labels = label_comma()) +
    labs(title = "Repository Size Distribution",
         x = "Size (KB, log scale)", y = "Count (log scale)") +
    theme_minimal(base_size = 12)
)
ggsave(file.path(OUTPUT_DIR, "repos_03_size_hist.png"), p_size,
       width = 8, height = 5, dpi = 150)

# repos_04: Commit count histogram (log-log)
suppressWarnings(
  p_commits <- ggplot(df %>% filter(commit_count > 0), aes(x = commit_count)) +
    geom_histogram(fill = "#4C72B0", colour = "white", linewidth = 0.2, bins = 40) +
    scale_x_log10(labels = label_comma()) +
    scale_y_log10(labels = label_comma()) +
    labs(title = "Repository Commit Count Distribution",
         x = "Commits (log scale)", y = "Count (log scale)") +
    theme_minimal(base_size = 12)
)
ggsave(file.path(OUTPUT_DIR, "repos_04_commits_hist.png"), p_commits,
       width = 8, height = 5, dpi = 150)

# repos_05: Repo age histogram (log y)
suppressWarnings(
  p_age <- ggplot(df, aes(x = age_days)) +
    geom_histogram(fill = "#4C72B0", colour = "white", linewidth = 0.2, bins = 40) +
    scale_y_log10(labels = label_comma()) +
    labs(title = "Repository Age Distribution",
         x = "Age (days)", y = "Count (log scale)") +
    theme_minimal(base_size = 12)
)
ggsave(file.path(OUTPUT_DIR, "repos_05_age_hist.png"), p_age,
       width = 8, height = 5, dpi = 150)

# repos_06: Stars vs forks scatter (both log scale)
suppressWarnings(
  p_sf <- ggplot(df %>% filter(stars > 0, forks > 0), aes(x = stars, y = forks)) +
    geom_point(alpha = 0.4, size = 0.8, colour = "#4C72B0") +
    scale_x_log10(labels = label_comma()) +
    scale_y_log10(labels = label_comma()) +
    labs(title = "Stars vs Forks",
         x = "Stars (log scale)", y = "Forks (log scale)") +
    theme_minimal(base_size = 12)
)
ggsave(file.path(OUTPUT_DIR, "repos_06_stars_vs_forks.png"), p_sf,
       width = 8, height = 5, dpi = 150)

# repos_07: Commits vs Java file count scatter (both log scale)
suppressWarnings(
  p_cj <- ggplot(df %>% filter(commit_count > 0, java_file_count > 0),
                 aes(x = commit_count, y = java_file_count)) +
    geom_point(alpha = 0.4, size = 0.8, colour = "#4C72B0") +
    scale_x_log10(labels = label_comma()) +
    scale_y_log10(labels = label_comma()) +
    labs(title = "Commit Count vs Java File Count",
         x = "Commits (log scale)", y = "Java Files (log scale)") +
    theme_minimal(base_size = 12)
)
ggsave(file.path(OUTPUT_DIR, "repos_07_commits_vs_javafiles.png"), p_cj,
       width = 8, height = 5, dpi = 150)

# 5. COMPLEXITY STRATIFIED BY REPO AGE & RECENCY
# Joins per-method complexity (cc_data.csv) back to repo metadata so we can ask:
# does code complexity differ between old vs young, or stale vs actively-pushed
# repositories?

CC_DATA_FILE <- file.path(DATA_DIR, "cc_data.csv")

if (file.exists(CC_DATA_FILE)) {
  cat("\nStratifying complexity by repo age / recency...\n")

  cc <- read_csv(CC_DATA_FILE, show_col_types = FALSE)

  # aggregate to one row per project (full_name)
  agg_cols <- intersect(c("cc", "cognitive_complexity", "loc",
                          "maintainability_index", "halstead_volume"), names(cc))
  proj_cc <- cc %>%
    group_by(project) %>%
    summarise(across(all_of(agg_cols),
                     ~ median(as.numeric(.), na.rm = TRUE),
                     .names = "median_{.col}"),
              n_methods = n(), .groups = "drop")

  joined <- df %>%
    select(full_name, age_days, days_since_push, stars) %>%
    inner_join(proj_cc, by = c("full_name" = "project")) %>%
    mutate(
      age_band = cut(age_days,
                     breaks = c(-Inf, 365, 1095, 1825, Inf),
                     labels = c("<1y", "1-3y", "3-5y", "5y+")),
      recency_band = cut(days_since_push,
                         breaks = c(-Inf, 30, 180, 365, Inf),
                         labels = c("<30d", "30-180d", "180-365d", "1y+"))
    )

  if (nrow(joined) > 0 && "median_cc" %in% names(joined)) {

    band_box <- function(data, band_col, title, file) {
      d <- data %>% filter(!is.na(.data[[band_col]]))
      meds <- d %>% group_by(.data[[band_col]]) %>%
        summarise(med = median(median_cc, na.rm = TRUE), .groups = "drop")
      p <- ggplot(d, aes(x = .data[[band_col]], y = median_cc)) +
        geom_boxplot(outlier.size = 0.5, outlier.alpha = 0.3,
                     fill = "#4C72B0", alpha = 0.75) +
        geom_text(data = meds, aes(x = .data[[band_col]], y = med,
                                   label = sprintf("%.1f", med)),
                  vjust = -0.6, size = 3, inherit.aes = FALSE) +
        labs(title = title, x = NULL, y = "Project Median Cyclomatic CC") +
        theme_minimal(base_size = 12)
      ggsave(file.path(OUTPUT_DIR, file), p, width = 8, height = 5, dpi = 150)
    }

    band_box(joined, "age_band",
             "Project Median CC by Repository Age", "repos_08_cc_by_age_band.png")
    band_box(joined, "recency_band",
             "Project Median CC by Days Since Last Push", "repos_09_cc_by_recency_band.png")

    # Kruskal-Wallis across bands + Spearman vs the raw continuous variables.
    strat_tests <- tibble(
      test = c("Kruskal-Wallis (median CC ~ age_band)",
               "Kruskal-Wallis (median CC ~ recency_band)",
               "Spearman (median CC vs age_days)",
               "Spearman (median CC vs days_since_push)",
               "Spearman (median CC vs stars)"),
      statistic = c(
        kruskal.test(median_cc ~ age_band, data = joined)$statistic,
        kruskal.test(median_cc ~ recency_band, data = joined)$statistic,
        cor(joined$median_cc, joined$age_days,        method = "spearman", use = "complete.obs"),
        cor(joined$median_cc, joined$days_since_push, method = "spearman", use = "complete.obs"),
        cor(joined$median_cc, joined$stars,           method = "spearman", use = "complete.obs")
      ),
      p_value = c(
        kruskal.test(median_cc ~ age_band, data = joined)$p.value,
        kruskal.test(median_cc ~ recency_band, data = joined)$p.value,
        cor.test(joined$median_cc, joined$age_days,        method = "spearman", exact = FALSE)$p.value,
        cor.test(joined$median_cc, joined$days_since_push, method = "spearman", exact = FALSE)$p.value,
        cor.test(joined$median_cc, joined$stars,           method = "spearman", exact = FALSE)$p.value
      )
    )
    write_csv(strat_tests, file.path(DATA_DIR, "repos_stratification_tests.csv"))
    write_csv(joined,      file.path(DATA_DIR, "repos_complexity_joined.csv"))
    print(strat_tests, n = Inf)
  } else {
    cat("  No overlap between repos.csv and cc_data.csv projects; skipping.\n")
  }
} else {
  cat("\nNote: cc_data.csv not found; skipping age/recency stratification.\n")
}

cat("\nDone\n")
