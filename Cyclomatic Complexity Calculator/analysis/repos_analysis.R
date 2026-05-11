library(tidyverse)
library(ggplot2)
library(scales)

# 0. CONFIGURATION

INPUT_FILE <- "repos.csv"
OUTPUT_DIR <- "output"

dir.create(OUTPUT_DIR, showWarnings = FALSE)

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

writeLines(report_lines, file.path(OUTPUT_DIR, "repos_summary.txt"))

# 4. PLOTS

cat("\nGenerating plots...\n")

# 4a. Stars histogram (log scale)
p_stars <- suppressWarnings(
  ggplot(df, aes(x = stars)) +
    geom_histogram(fill = "#4C72B0", colour = "white", linewidth = 0.2, bins = 40) +
    scale_x_log10(labels = label_comma()) +
    labs(title = "Repository Star Count Distribution",
         x = "Stars (log scale)", y = "Count") +
    theme_minimal(base_size = 12)
)
ggsave(file.path(OUTPUT_DIR, "repos_01_stars_hist.png"), p_stars,
       width = 8, height = 5, dpi = 150)

# 4b. Forks histogram (log scale)
p_forks <- suppressWarnings(
  ggplot(df %>% filter(forks > 0), aes(x = forks)) +
    geom_histogram(fill = "#4C72B0", colour = "white", linewidth = 0.2, bins = 40) +
    scale_x_log10(labels = label_comma()) +
    labs(title = "Repository Fork Count Distribution",
         x = "Forks (log scale)", y = "Count") +
    theme_minimal(base_size = 12)
)
ggsave(file.path(OUTPUT_DIR, "repos_02_forks_hist.png"), p_forks,
       width = 8, height = 5, dpi = 150)

# 4c. Size histogram (log scale)
p_size <- suppressWarnings(
  ggplot(df %>% filter(size_kb > 0), aes(x = size_kb)) +
    geom_histogram(fill = "#4C72B0", colour = "white", linewidth = 0.2, bins = 40) +
    scale_x_log10(labels = label_comma()) +
    labs(title = "Repository Size Distribution",
         x = "Size (KB, log scale)", y = "Count") +
    theme_minimal(base_size = 12)
)
ggsave(file.path(OUTPUT_DIR, "repos_03_size_hist.png"), p_size,
       width = 8, height = 5, dpi = 150)

# 4d. Commit count histogram (log scale, exclude -1)
p_commits <- suppressWarnings(
  ggplot(df %>% filter(commit_count > 0), aes(x = commit_count)) +
    geom_histogram(fill = "#4C72B0", colour = "white", linewidth = 0.2, bins = 40) +
    scale_x_log10(labels = label_comma()) +
    labs(title = "Repository Commit Count Distribution",
         x = "Commits (log scale)", y = "Count") +
    theme_minimal(base_size = 12)
)
ggsave(file.path(OUTPUT_DIR, "repos_04_commits_hist.png"), p_commits,
       width = 8, height = 5, dpi = 150)

# 4e. Repo age histogram (linear)
p_age <- ggplot(df, aes(x = age_days)) +
  geom_histogram(fill = "#4C72B0", colour = "white", linewidth = 0.2, bins = 40) +
  labs(title = "Repository Age Distribution",
       x = "Age (days)", y = "Count") +
  theme_minimal(base_size = 12)
ggsave(file.path(OUTPUT_DIR, "repos_05_age_hist.png"), p_age,
       width = 8, height = 5, dpi = 150)

# 4f. Stars vs forks scatter (both log scale)
p_sf <- suppressWarnings(
  ggplot(df %>% filter(stars > 0, forks > 0), aes(x = stars, y = forks)) +
    geom_point(alpha = 0.4, size = 0.8, colour = "#4C72B0") +
    scale_x_log10(labels = label_comma()) +
    scale_y_log10(labels = label_comma()) +
    labs(title = "Stars vs Forks",
         x = "Stars (log scale)", y = "Forks (log scale)") +
    theme_minimal(base_size = 12)
)
ggsave(file.path(OUTPUT_DIR, "repos_06_stars_vs_forks.png"), p_sf,
       width = 8, height = 5, dpi = 150)

# 4g. Commits vs Java file count scatter (both log scale)
p_cj <- suppressWarnings(
  ggplot(df %>% filter(commit_count > 0, java_file_count > 0),
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

cat("\nDone\n")