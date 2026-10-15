# =============================================================================
# 02_corpus.R
# Loads the October 2026 corpus (memory-careful: only the columns needed),
# validates it, applies and counts the filters, describes it, and draws the
# distribution figure. Saves compact working files for 03/06.
#
# Main corpus filter (decisions, reported with counts at every step):
#   - methods only        constructors are a different kind of code unit from the
#                         methods the survey snippets are, and earlier work measured
#                         methods only; constructors appear in the sensitivity runs
#   - with a body         abstract/interface methods have CC 1 by definition and
#                         carry no code to understand
#   - not nested          a method of a local/anonymous class is already counted
#                         inside its enclosing method
#   - not generated       generated parsers/lexers are not code people read and are
#                         the source of the most extreme outliers
# Duplicates (identical code in several repositories) are kept in the main
# analysis and handled in the sensitivity runs.
# =============================================================================

source("scripts/00_setup.R")

CORPUS <- file.path(PATHS$corpus_dir, "cc_data.csv")
REPOS <- file.path(PATHS$corpus_dir, "repos.csv")
SKIPPED <- file.path(PATHS$corpus_dir, "skipped.csv")
RUN_LOG <- file.path(PATHS$corpus_dir, "run_log.txt")
validate("corpus files exist", all(file.exists(c(CORPUS, REPOS, SKIPPED))))

harvest_complete <- file.exists(RUN_LOG) && any(grepl("^EXIT 0", readLines(RUN_LOG, warn = FALSE)))
validate("October harvest finished (EXIT 0): corpus results are final", harvest_complete,
         if (harvest_complete) "complete" else "HARVEST STILL RUNNING: corpus results are PROVISIONAL",
         stop_on_fail = FALSE)

KEY_COLS <- c("project", "kind", "has_body", "nested_in_method", "is_generated",
              "cc", "cognitive_complexity", "loc", "max_nesting")
header <- names(fread(CORPUS, nrows = 0))
validate("corpus has the expected columns",
         all(c(KEY_COLS, "body_hash", "file_path", "start_line", "has_javadoc", "recursive") %in% header),
         paste(setdiff(c(KEY_COLS, "body_hash"), header), collapse = ", "))
validate("excluded metrics are not used (maintainability index, naming score)", TRUE,
         "maintainability_index / mi_normalized are never loaded; naming_score is not computed")

d <- suppressWarnings(fread(CORPUS, select = KEY_COLS, showProgress = FALSE))
setnames(d, "cognitive_complexity", "cognitive")
n_raw <- nrow(d)
d[, row_id := .I]          # position in the file, so other columns can be read and aligned later

# ---- Integrity checks ----------------------------------------------------------------
n_na <- d[, sum(is.na(cc) | is.na(cognitive) | is.na(loc) | is.na(max_nesting))]
validate("no missing key metric values", n_na == 0, paste(n_na, "rows with a missing key metric"),
         stop_on_fail = harvest_complete)
if (n_na > 0) d <- d[!is.na(cc) & !is.na(cognitive) & !is.na(loc) & !is.na(max_nesting)]
validate("metric ranges are valid (CC >= 1, others >= 0)",
         d[, min(cc) >= 1 && min(cognitive) >= 0 && min(loc) >= 0 && min(max_nesting) >= 0])
validate("kind is method or constructor", all(d$kind %in% c("method", "constructor")))
validate("flag columns are 0/1", d[, all(has_body %in% 0:1) && all(nested_in_method %in% 0:1) && all(is_generated %in% 0:1)])
validate("bodyless methods have CC 1 (sanity check on has_body)", d[has_body == 0, all(cc == 1)])

# ---- Repository join ----------------------------------------------------------------
repos <- fread(REPOS)
setnames(repos, "full_name", "project")
orphans <- setdiff(unique(d$project), repos$project)
validate("every corpus project is in repos.csv", length(orphans) == 0,
         sprintf("%d projects with methods but no repository row%s", length(orphans),
                 if (harvest_complete) "" else " (repos still being processed)"),
         stop_on_fail = harvest_complete)
validate("repos.csv has no duplicate repositories", !anyDuplicated(repos$project))
validate("repo identifying/contributor columns present",
         all(c("contributors", "head_sha", "stars", "forks", "commit_count", "created_at") %in% names(repos)))
n_repos_methods <- d[, uniqueN(project)]
validate("repositories contributing methods <= repositories harvested", n_repos_methods <= nrow(repos),
         stop_on_fail = harvest_complete)

# Duplicate-row check (a repository processed twice would repeat file/line pairs)
loc_id <- suppressWarnings(fread(CORPUS, select = c("project", "file_path", "start_line"), nrows = n_raw, showProgress = FALSE))
# A repository processed twice would have about half its rows share a file/line with another
# row. A small share is normal: several short methods can sit on one line (one-line enums
# or records), so the check looks for a repository-level share near 50%.
loc_id[, same_line := duplicated(loc_id, by = c("project", "file_path", "start_line"))]
share_by_repo <- loc_id[, .(share = mean(same_line), n = .N), by = project]
validate("no repository processed twice (share of rows on a shared file/line is small in every repo)",
         share_by_repo[, max(share)] < 0.4,
         sprintf("%d rows share a file/line overall (%.4f%%); highest repository share %.1f%%",
                 loc_id[, sum(same_line)], 100 * loc_id[, mean(same_line)], 100 * share_by_repo[, max(share)]))
rm(loc_id); invisible(gc())

# Code fingerprints: flag every row after the first with identical code
h <- fread(CORPUS, select = "body_hash", colClasses = "character", nrows = n_raw, showProgress = FALSE)$body_hash
dup_all <- duplicated(h) | h == ""
d[, dup := dup_all[row_id]]
rm(h, dup_all); invisible(gc())

# ---- Filters with counts ----------------------------------------------------------------
repo_levels <- sort(unique(d$project))
d[, `:=`(repo = match(project, repo_levels), is_ctor = kind == "constructor",
         bodyless = has_body == 0, nested = nested_in_method == 1, generated = is_generated == 1)]
d[, c("project", "kind", "has_body", "nested_in_method", "is_generated") := NULL]
d[, main := !is_ctor & !bodyless & !nested & !generated]

steps <- list(
  "All methods and constructors harvested" = rep(TRUE, nrow(d)),
  "Methods only (constructors excluded)" = !d$is_ctor,
  "... with a body (abstract/interface excluded)" = !d$is_ctor & !d$bodyless,
  "... not nested in another method" = !d$is_ctor & !d$bodyless & !d$nested,
  "... not generated code (main corpus)" = d$main)
waterfall <- tibble::tibble(
  step = names(steps), n = vapply(steps, sum, numeric(1))) |>
  mutate(removed = lag(n) - n, pct_of_all = n / first(n),
         repositories = vapply(steps, function(k) uniqueN(d$repo[k]), numeric(1)))
validate("main corpus is non-empty and the filter steps nest", all(diff(waterfall$n) <= 0) && last(waterfall$n) > 0,
         paste(waterfall$n, collapse = " > "))
save_table(waterfall, "corpus_filter_counts")

prevalence <- tibble::tibble(
  attribute = c("Constructors", "Methods without a body", "Nested in another method",
                "Generated code", "Duplicate code (identical to an earlier method)"),
  n = c(sum(d$is_ctor), sum(d$bodyless), sum(d$nested), sum(d$generated), sum(d$dup))) |>
  mutate(share = n / nrow(d))
save_table(prevalence, "corpus_flag_prevalence")
for (i in seq_len(nrow(prevalence)))
  record(paste0("corpus share: ", prevalence$attribute[i]), prevalence$share[i], n = prevalence$n[i],
         denominator = nrow(d), section = "RQ1: corpus", subset = "all harvested rows")
for (i in seq_len(nrow(waterfall)))
  record(paste0("corpus filter step: ", waterfall$step[i]), waterfall$n[i], denominator = nrow(d),
         section = "RQ1: corpus", note = paste(waterfall$repositories[i], "repositories"))
record("corpus provisional (1 = harvest not finished)", as.numeric(!harvest_complete), section = "RQ1: corpus")

table_png(waterfall |>
            transmute(Step = step, Methods = format(n, big.mark = ","),
                      Removed = ifelse(is.na(removed), "", format(removed, big.mark = ",")),
                      `% of all` = pct(pct_of_all, 1), Repositories = format(repositories, big.mark = ",")),
          "corpus_filter_counts", title = "Corpus filtering",
          subtitle = if (harvest_complete) NULL else "PROVISIONAL: harvest still running")

# ---- Corpus summary (repositories) ---------------------------------------------------------
repos[, created := as.Date(substr(created_at, 1, 10))]
skipped <- fread(SKIPPED)
rs <- function(x) sprintf("%s (%s–%s)", format(round(median(x, na.rm = TRUE)), big.mark = ","),
                          format(round(quantile(x, 0.25, na.rm = TRUE)), big.mark = ","),
                          format(round(quantile(x, 0.75, na.rm = TRUE)), big.mark = ","))
n_contrib_known <- repos[contributors >= 0, .N]
summary_tbl <- tibble::tribble(
  ~Item, ~Value,
  "Repositories harvested", format(nrow(repos), big.mark = ","),
  "Repositories contributing methods", format(n_repos_methods, big.mark = ","),
  "Methods and constructors measured", format(n_raw, big.mark = ","),
  "Main corpus (after filters)", format(sum(d$main), big.mark = ","),
  "Stars: median (IQR)", rs(repos$stars),
  "Forks: median (IQR)", rs(repos$forks),
  "Commits: median (IQR)", rs(repos$commit_count),
  "Contributors: median (IQR)", rs(repos$contributors[repos$contributors >= 0]),
  "Java files per repository: median (IQR)", rs(repos$java_file_count),
  "Repositories created", paste(format(min(repos$created), "%b %Y"), "to", format(max(repos$created), "%b %Y")),
  "Files parsed with errors (methods kept)", format(skipped[type == "file_partial", .N], big.mark = ","),
  "Files that could not be parsed", format(skipped[type == "file", .N], big.mark = ","),
  "Repositories that failed", format(skipped[type == "repo", .N], big.mark = ","))
save_table(summary_tbl, "corpus_summary")
table_png(summary_tbl, "corpus_summary", title = "The corpus",
          subtitle = if (harvest_complete) NULL else "PROVISIONAL: harvest still running")
record("repositories harvested", nrow(repos), section = "RQ1: corpus")
record("repositories contributing methods", n_repos_methods, section = "RQ1: corpus")
record("methods and constructors measured", n_raw, section = "RQ1: corpus")
record("main corpus methods", sum(d$main), section = "RQ1: corpus")
record("repository stars (median)", median(repos$stars), section = "RQ1: corpus")
record("repository contributors (median)", median(repos$contributors[repos$contributors >= 0]), section = "RQ1: corpus")
record("files parsed with errors", skipped[type == "file_partial", .N], section = "RQ1: corpus")
record("files not parsed", skipped[type == "file", .N], section = "RQ1: corpus")

# ---- Descriptive statistics of the key metrics (main corpus) -----------------------------
m <- d[main == TRUE]
desc <- purrr::map_dfr(METRICS, function(k) {
  x <- m[[k]]
  tibble::tibble(metric = METRIC_LABELS[k], n = length(x), median = median(x), mean = mean(x),
                 p95 = unname(quantile(x, 0.95)), p99 = unname(quantile(x, 0.99)), max = max(x),
                 share_zero = mean(x == 0), share_at_minimum = mean(x == min(x)),
                 distinct_values = uniqueN(x))
})
save_table(desc, "corpus_descriptives")
table_png(desc |> transmute(Metric = metric, Median = median, Mean = sprintf("%.2f", mean), `95th pct` = p95,
                            `99th pct` = p99, Max = format(max, big.mark = ","),
                            `Share at 0` = pct(share_zero, 1), `Distinct values` = format(distinct_values, big.mark = ",")),
          "corpus_descriptives", title = "Key metric distributions in the main corpus",
          subtitle = sprintf("%s methods%s", format(nrow(m), big.mark = ","), if (harvest_complete) "" else " (PROVISIONAL)"))
for (i in seq_len(nrow(desc))) {
  r <- desc[i, ]
  record(paste0(r$metric, ": median, main corpus"), r$median, n = r$n, section = "RQ1: corpus")
  record(paste0(r$metric, ": 95th percentile, main corpus"), r$p95, n = r$n, section = "RQ1: corpus")
  record(paste0(r$metric, ": share of methods at 0, main corpus"), r$share_zero, n = r$n, section = "RQ1: corpus")
  record(paste0(r$metric, ": distinct values, main corpus"), r$distinct_values, n = r$n, section = "RQ1: corpus")
}
record("methods with CC > 10 (share of main corpus)", mean(m$cc > 10), n = sum(m$cc > 10), denominator = nrow(m),
       section = "RQ1: corpus")
record("methods with CC = 1 (share of main corpus)", mean(m$cc == 1), n = sum(m$cc == 1), denominator = nrow(m),
       section = "RQ1: corpus")

# ---- Log-log frequency plot (descriptive; no distribution is fitted) ---------------------
freq <- rbindlist(lapply(METRICS, function(k)
  m[, .N, by = .(value = get(k))][value >= 1][, metric := METRIC_LABELS[k]]))
freq[, metric := factor(metric, levels = METRIC_LABELS)]
zero_note <- paste(sprintf("%s: %s of methods are 0", METRIC_LABELS[c("cognitive", "max_nesting")],
                           pct(desc$share_zero[desc$metric %in% METRIC_LABELS[c("cognitive", "max_nesting")]], 0)),
                   collapse = "; ")
p_loglog <- ggplot(freq, aes(value, N, colour = metric)) +
  geom_point(size = 0.9, alpha = 0.8) +
  facet_wrap(~ metric, nrow = 2, scales = "free_x") +
  scale_x_log10(labels = scales::label_comma()) +
  scale_y_log10(labels = scales::label_comma()) +
  scale_colour_manual(values = METRIC_COLOURS, guide = "none") +
  labs(title = "Most methods have small measurements; a few have very large ones",
       subtitle = paste(strwrap(sprintf("Main corpus, %s methods. Log scales on both axes. Values of 0 are not shown (%s).%s",
                          format(nrow(m), big.mark = ","), zero_note,
                          if (harvest_complete) "" else " PROVISIONAL."), 105), collapse = "
"),
       x = "Measurement (log scale)", y = "Number of methods (log scale)") +
  theme_report()
save_fig(p_loglog, "fig01_corpus_loglog_distributions", height_cm = 10, rq = "RQ1",
         purpose = "Shows the heavily skewed distributions and the concentration of methods at small values")

# ---- Compact working files for later scripts -----------------------------------------------
saveRDS(d, file.path(PATHS$work, "corpus_key.rds"))
saveRDS(list(repo_levels = repo_levels, complete = harvest_complete, n_raw = n_raw, repos = as.data.frame(repos[, .(project, stars, forks, contributors, commit_count)])),
        file.path(PATHS$work, "corpus_meta.rds"))
save_numbers("02_corpus")
save_validation("02_corpus")
save_figure_registry("02_corpus")
cat("Corpus loaded:", format(n_raw, big.mark = ","), "rows;", format(sum(d$main), big.mark = ","), "in the main corpus\n")
