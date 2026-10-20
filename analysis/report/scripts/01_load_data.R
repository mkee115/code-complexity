# =============================================================================
# 01_load_data.R
# Load and validate the two datasets: the Qualtrics survey and the GitHub corpus.
#
# Each section runs in its own local() block, so its variables do not leak into the
# next one. Intermediate results pass between sections as files in output/_pipeline/.
# =============================================================================

source("scripts/00_setup.R")

# -----------------------------------------------------------------------------
# SECTION 01_load_survey
# Reads the Qualtrics export, removes identifying columns, applies the
# inclusion rule (completed responses only), and builds one row per response
# joined to the pair map and the snippet measurements. Every data check is
# recorded in the validation log; a failed check stops the pipeline.
#
# Outputs (output/_pipeline/): participants.rds, responses.rds, scored.rds
#   responses: one row per participant x comparison
#   scored:    responses x 4 key metrics, with the metric's prediction and
#              whether it agrees with the participant
# -----------------------------------------------------------------------------
local({
  RATING_LEVELS <- c("Method A is much less complex", "Method A is slightly less complex",
                     "No difference", "Method B is slightly less complex",
                     "Method B is much less complex")
  JAVA_CORRECT <- c(`Java Q1` = "C", `Java Q2` = "2", `Java Q3` = "24")

  # ---- Read and de-identify -----------------------------------------------------
  # Qualtrics writes three header rows: names, question text, ImportId JSON
  raw <- read_csv(PATHS$survey_raw, col_types = cols(.default = col_character()),
                  show_col_types = FALSE)[-(1:2), ]
  identifying <- c("IPAddress", "LocationLatitude", "LocationLongitude",
                   "RecipientLastName", "RecipientFirstName", "RecipientEmail", "ExternalReference")
  raw <- raw |> select(-any_of(identifying))
  validate("identifying survey columns removed on load", !any(identifying %in% names(raw)))

  n_rows_total <- nrow(raw)
  n_preview <- sum(raw$Status == "Survey Preview")

  # ---- Inclusion rule: completed responses only -------------------------------
  kept <- raw |>
    filter(Status != "Survey Preview", Progress == "100", Finished %in% c("True", "1")) |>
    mutate(pid = sprintf("P%02d", row_number()))

  participants <- kept |>
    transmute(
      pid,
      degree = `Demographic Q1`,
      experience = factor(`Demographic Q2`, levels = c(
        "None", "Written tiny programs (Up to 100 lines)", "Written small programs (100-500 lines)",
        "Written medium programs (500-2000 lines)", "Written large programs (2000+ lines)")),
      java_q1_correct = `Java Q1` == JAVA_CORRECT[["Java Q1"]],   # chained ternary
      java_q2_correct = `Java Q2` == JAVA_CORRECT[["Java Q2"]],   # modulo
      java_q3_correct = `Java Q3` == JAVA_CORRECT[["Java Q3"]],   # recursion
      java_correct = java_q1_correct + java_q2_correct + java_q3_correct,
      duration_min = as.numeric(`Duration (in seconds)`) / 60
    )

  # ---- One row per response ----------------------------------------------------
  pairs <- read_csv(PATHS$pairs, show_col_types = FALSE)
  snip <- read_csv(PATHS$snippets, show_col_types = FALSE)

  validate("every pair's rating column exists in the export", all(pairs$rating_column %in% names(kept)),
           paste(setdiff(pairs$rating_column, names(kept)), collapse = ", "))

  responses <- kept |>
    select(pid, all_of(pairs$rating_column)) |>
    pivot_longer(-pid, names_to = "rating_column", values_to = "rating_text") |>
    filter(!is.na(rating_text)) |>
    inner_join(pairs, by = "rating_column") |>
    mutate(
      rating = match(rating_text, RATING_LEVELS),
      human = sign(rating - 3),                  # -1 = A judged less complex, +1 = B judged less complex
      strength = factor(c("No difference", "Slightly", "Much")[abs(rating - 3) + 1],
                        levels = c("No difference", "Slightly", "Much")),
      vv_pair = method_a != "ORIG"               # neither side is the original
    ) |>
    select(pid, item, group, task, method_a, method_b, method_a_id, method_b_id,
           rating, human, strength, vv_pair)
  validate("every rating text matches the 5-point scale", !any(is.na(responses$rating)))

  # ---- Join measurements: one row per response x metric -----------------------
  long_metrics <- snip |>
    select(id, all_of(METRICS)) |>
    pivot_longer(-id, names_to = "metric", values_to = "value")

  scored <- responses |>
    tidyr::crossing(metric = METRICS) |>
    left_join(long_metrics, by = c("method_a_id" = "id", "metric")) |>
    rename(value_a = value) |>
    left_join(long_metrics, by = c("method_b_id" = "id", "metric")) |>
    rename(value_b = value) |>
    mutate(
      predicted = sign(value_a - value_b),   # +1: A has the higher measurement, so B is predicted less complex
      agree = predicted == human,            # a metric tie agrees only with "No difference"
      gap = abs(value_a - value_b),
      metric_label = metric_factor(metric)
    )

  # ---- Validation ------------------------------------------------------------------
  per_person <- count(responses, pid)
  per_pair <- count(responses, item)
  validate("participants = 75 (completed, non-preview)", nrow(participants) == 75, nrow(participants))
  validate("comparisons = 750", nrow(responses) == 750, nrow(responses))
  validate("exactly 10 responses per participant", all(per_person$n == 10),
           paste(range(per_person$n), collapse = "-"))
  validate("44 distinct pairs have responses", n_distinct(responses$item) == 44, n_distinct(responses$item))
  validate("pair map covers the 44 pairs once", nrow(pairs) == 44 && !anyDuplicated(pairs$item))
  validate("34 snippets have measurements", nrow(snip) == 34 && !anyDuplicated(snip$id), nrow(snip))
  validate("every pair's two snippets have measurements",
           all(c(pairs$method_a_id, pairs$method_b_id) %in% snip$id))
  validate("no missing metric values after the join", !anyNA(scored$value_a) && !anyNA(scored$value_b))
  validate("each participant saw one pair per task",
           all(count(responses, pid, group)$n == 1))
  validate("Q4A seen by every participant", sum(responses$item == "Q4A") == 75)
  validate("10-V3 absent from the pair map and snippets",
           !any(grepl("10-V3", c(pairs$method_a_id, pairs$method_b_id, snip$id))))
  validate("Q10C is V1 vs V2", with(pairs[pairs$item == "Q10C", ], method_a == "V1" && method_b == "V2"))

  # Hand-checks of the agreement coding on constructed cases
  code_agree <- function(value_a, value_b, rating) sign(value_a - value_b) == sign(rating - 3)
  validate("coding: A lower, participant says A less complex -> agree", code_agree(2, 5, 1))
  validate("coding: A lower, participant says B less complex -> disagree", !code_agree(2, 5, 4))
  validate("coding: metric tie agrees with No difference", code_agree(3, 3, 3))
  validate("coding: metric tie does not agree with a stated preference", !code_agree(3, 3, 5))
  validate("coding: metric separates, participant says No difference -> disagree", !code_agree(2, 5, 3))
  real <- scored |> filter(item == "Q3A", metric == "cc", rating == 4) |> slice(1)   # 03-ORIG (CC 3) vs 03-V1 (CC 2)
  validate("coding on real data: Q3A CC 3 vs 2, 'B slightly less complex' -> agree",
           nrow(real) == 1 && real$agree && real$predicted == 1)

  check_tbl <- tibble::tribble(
    ~check, ~result,
    "rows in export", n_rows_total,
    "survey previews removed", n_preview,
    "real submissions", n_rows_total - n_preview,
    "participants (completed)", nrow(participants),
    "comparisons", nrow(responses),
    "responses per pair (min)", min(per_pair$n),
    "responses per pair (max)", max(per_pair$n))
  save_table(check_tbl, "survey_counts")

  saveRDS(participants, file.path(PATHS$work, "participants.rds"))
  saveRDS(responses, file.path(PATHS$work, "responses.rds"))
  saveRDS(scored, file.path(PATHS$work, "scored.rds"))

  record("participants", nrow(participants), n = nrow(participants), section = "Method: survey",
         note = "completed responses only, previews removed")
  record("comparisons", nrow(responses), n = nrow(responses), section = "Method: survey")
  record("real submissions (non-preview)", n_rows_total - n_preview, section = "Method: survey")
  record("distinct pairs", n_distinct(responses$item), section = "Method: survey")
  record("median duration (min)", median(participants$duration_min), section = "Method: survey")
  record("responses per pair (min)", min(per_pair$n), section = "Method: survey")
  record("responses per pair (max)", max(per_pair$n), section = "Method: survey")
  record("responses per pair (median)", median(per_pair$n), ci_low = unname(quantile(per_pair$n, 0.25)),
         ci_high = unname(quantile(per_pair$n, 0.75)), n = nrow(per_pair), section = "Method: survey",
         note = "interval = interquartile range across the 44 pairs, not a confidence interval")
  record("all three screening questions correct", sum(participants$java_correct == 3),
         n = nrow(participants), section = "Method: survey")
  for (v in c("java_q1_correct", "java_q2_correct", "java_q3_correct"))
    record(paste0("screening question correct: ", v), sum(participants[[v]]), n = nrow(participants),
           section = "Method: survey")
  save_numbers("01_load_survey")
  save_validation("01_load_survey")
  cat("Survey loaded:", nrow(participants), "participants,", nrow(responses), "comparisons\n")
})

# -----------------------------------------------------------------------------
# SECTION 02_load_corpus
# Loads the October 2026 corpus (memory-careful: only the columns needed),
# validates it, applies and counts the filters, and describes it. Saves compact
# working files for the RQ1, sensitivity and figure scripts.
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
#                         the source of the most extreme outliers. Flagged at harvest, plus
#                         general name/path rules added afterwards (see "Added generated-code
#                         rules" below)
# Duplicates (identical code in several repositories) are kept in the main
# analysis and handled in the sensitivity runs.
# -----------------------------------------------------------------------------
local({
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
  validate("excluded metrics are never loaded (maintainability index)",
           !any(c("maintainability_index", "mi_normalized") %in% KEY_COLS))

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

  # Code fingerprints (body_hash): flag every row after the first copy of identical code
  h <- fread(CORPUS, select = "body_hash", colClasses = "character", nrows = n_raw, showProgress = FALSE)$body_hash
  dup_all <- h != "" & duplicated(h)      # every row after the first with identical code
  d[, dup := dup_all[row_id]]
  rm(h, dup_all); invisible(gc())

  # ---- Added generated-code rules ------------------------------------------------------------
  # The harvest flags a file as generated from its path (a folder with "generated" in its name) and its
  # header text, which missed some parser-generator output. These general rules use only columns
  # already in the corpus and are applied to every row, not to particular methods:
  #   - ANTLR 3 lookahead code: classes named DFA<number>, and methods named specialStateTransition
  #   - JavaCC lookahead code: methods whose name starts with jj_
  #   - source folders for generated code: src-gen/ and generated-sources/
  #   - file-level propagation: every method in a file that holds a DFA / specialStateTransition / jj_
  #     method (generators write the signature methods and the production methods into the same file)
  # The header-marker rules (ANTLR "$ANTLR" / "Generated from ... by ANTLR", JavaCC "Generated By:JavaCC")
  # need the file text, which the corpus does not keep; they are in the calculator for the next harvest.
  # /tests/ paths (test code outside src/test) are not excluded here; a sensitivity run reports their effect.
  nm <- fread(CORPUS, select = c("class_name", "method_name", "file_path"), nrows = n_raw,
              colClasses = "character", showProgress = FALSE)
  path <- gsub("\\", "/", nm$file_path, fixed = TRUE)
  f_dfa <- grepl("(^|[.$])DFA[0-9]+$", nm$class_name) | nm$method_name == "specialStateTransition"
  f_jj <- startsWith(nm$method_name, "jj_")
  f_path <- grepl("(^|/)(src-gen|generated-sources)/", path)
  f_test <- grepl("(^|/)tests/", path)

  # ---- Filters with counts ----------------------------------------------------------------
  repo_levels <- sort(unique(d$project))
  d[, `:=`(repo = match(project, repo_levels), is_ctor = kind == "constructor",
           bodyless = has_body == 0, nested = nested_in_method == 1, generated = is_generated == 1,
           gen_dfa = f_dfa[row_id], gen_jj = f_jj[row_id], gen_path = f_path[row_id], test_path = f_test[row_id])]
  # File-level propagation: a file is generated if it holds any method that is generator output by
  # the DFA / specialStateTransition / jj_ rules; then every method in that file is generated. Parser
  # generators emit the signature methods and the production methods together, in the same file.
  d[, file_key := path[row_id]]
  d[, gen_file := any(gen_dfa | gen_jj), by = .(project, file_key)]
  d[, file_key := NULL]
  rm(path); invisible(gc())
  d[, gen_rules_basic := gen_dfa | gen_jj | gen_path]            # the name and path rules alone
  d[, gen_rules := gen_rules_basic | gen_file]                   # all added rules, including propagation
  d[, c("project", "kind", "has_body", "nested_in_method", "is_generated") := NULL]
  d[, main := !is_ctor & !bodyless & !nested & !generated & !gen_rules]

  # What the added rules removed: all rows matching, those not already flagged at harvest, those removed from the
  # pre-rule main corpus, and those removed only because of this rule (not matched by any other added rule)
  pre_main <- !d$is_ctor & !d$bodyless & !d$nested & !d$generated        # main corpus before the added rules
  rule_flags <- list(
    "DFA<number> classes / specialStateTransition" = d$gen_dfa,
    "jj_ methods (JavaCC)" = d$gen_jj,
    "src-gen/ or generated-sources/ paths" = d$gen_path,
    "File-level propagation (file holds a DFA / specialStateTransition / jj_ method)" = d$gen_file,
    "Any added rule" = d$gen_rules)
  # "Only by this rule": a name or path rule is compared with the other two name/path rules; file-level
  # propagation (which covers every DFA / jj_ row by construction) is compared with all three name/path rules.
  basic_rules <- names(rule_flags)[1:3]
  rules_effect <- purrr::imap_dfr(rule_flags, function(f, nm_r) {
    others <- if (nm_r == "Any added rule") rep(FALSE, nrow(d))
              else if (nm_r %in% basic_rules) Reduce(`|`, rule_flags[setdiff(basic_rules, nm_r)])
              else Reduce(`|`, rule_flags[basic_rules])
    tibble::tibble(rule = nm_r, all_rows = sum(f), not_flagged_at_harvest = sum(f & !d$generated),
                   removed_from_main = sum(f & pre_main),
                   removed_only_by_this_rule = if (nm_r == "Any added rule") NA_integer_ else sum(f & pre_main & !others))
  })
  save_table(rules_effect, "corpus_generated_rules_effect")
  for (i in seq_len(nrow(rules_effect))) {
    record(paste0("added generated-code rule: ", rules_effect$rule[i], ", methods removed from the main corpus"),
           rules_effect$removed_from_main[i], denominator = sum(pre_main), section = "RQ1: corpus",
           note = sprintf("%d rows match in all; %d of them not already flagged generated at harvest",
                          rules_effect$all_rows[i], rules_effect$not_flagged_at_harvest[i]))
    if (!is.na(rules_effect$removed_only_by_this_rule[i]))
      record(paste0("added generated-code rule: ", rules_effect$rule[i], ", methods removed only by this rule"),
             rules_effect$removed_only_by_this_rule[i], denominator = sum(pre_main), section = "RQ1: corpus",
             note = "not matched by any other added rule")
  }
  validate("added generated-code rules remove methods and none are left in the main corpus",
           rules_effect$removed_from_main[nrow(rules_effect)] > 0 && !any(d$main & d$gen_rules))

  steps <- list(
    "All methods and constructors harvested" = rep(TRUE, nrow(d)),
    "Methods only (constructors excluded)" = !d$is_ctor,
    "... with a body (abstract/interface excluded)" = !d$is_ctor & !d$bodyless,
    "... not nested in another method" = !d$is_ctor & !d$bodyless & !d$nested,
    "... not flagged generated at harvest" = pre_main,
    "... not matching the added generated-code rules (main corpus)" = d$main)
  waterfall <- tibble::tibble(
    step = names(steps), n = vapply(steps, sum, numeric(1))) |>
    mutate(removed = lag(n) - n, pct_of_all = n / first(n),
           repositories = vapply(steps, function(k) uniqueN(d$repo[k]), numeric(1)))
  validate("main corpus is non-empty and the filter steps nest", all(diff(waterfall$n) <= 0) && last(waterfall$n) > 0,
           paste(waterfall$n, collapse = " > "))
  save_table(waterfall, "corpus_filter_counts")

  prevalence <- tibble::tibble(
    attribute = c("Constructors", "Methods without a body", "Nested in another method",
                  "Generated code", "Generated code (added rules, not flagged at harvest)",
                  "Duplicate code (identical to an earlier method)"),
    n = c(sum(d$is_ctor), sum(d$bodyless), sum(d$nested), sum(d$generated), sum(d$gen_rules & !d$generated),
          sum(d$dup))) |>
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

  # Parse failures as a share of all Java files, and a rough estimate of the methods they cost.
  # java_file_count is the number of .java files outside Maven src/test and src/it in each harvested repository;
  # the 8 repositories that failed to clone are not in repos.csv, so their files are not in the total.
  n_java_files <- sum(repos$java_file_count)
  n_unparsed <- skipped[type == "file", .N]
  n_partial <- skipped[type == "file_partial", .N]
  rows_per_parsed_file <- n_raw / (n_java_files - n_unparsed)
  rp <- merge(d[, .(rows = .N), by = repo][, project := repo_levels[repo]], repos[, .(project, java_file_count)], by = "project")
  rp[, rows_per_file := rows / java_file_count]
  unp <- skipped[type == "file", .(n = .N), by = .(project = repo)]
  unp <- merge(unp, rp[, .(project, rows_per_file)], by = "project", all.x = TRUE)
  est_global <- n_unparsed * rows_per_parsed_file
  est_repo <- sum(unp$n * unp$rows_per_file, na.rm = TRUE)
  record("Java files in the harvested repositories (outside Maven test directories)", n_java_files, section = "RQ1: corpus",
         note = "sum of java_file_count in repos.csv; excludes the repositories that failed to clone")
  record("files not parsed: share of all Java files", n_unparsed / n_java_files, n = n_unparsed, denominator = n_java_files,
         section = "RQ1: corpus", note = "the file column of skipped.csv holds only the file name, so distinct names undercount (384 of 412)")
  record("files parsed with errors (methods kept): share of all Java files", n_partial / n_java_files, n = n_partial,
         denominator = n_java_files, section = "RQ1: corpus", note = "rows in skipped.csv of type file_partial")
  record("estimated methods lost in unparsed files: mean methods per parsed file", est_global, n = n_unparsed, section = "RQ1: corpus",
         note = sprintf("%d unparsed files x %.2f rows per parsed file; %.3f%% of the rows harvested", n_unparsed, rows_per_parsed_file, 100 * est_global / n_raw))
  record("estimated methods lost in unparsed files: same-repository mean", est_repo, n = n_unparsed, section = "RQ1: corpus",
         note = sprintf("each unparsed file given its repository's rows per file; %.3f%% of the rows harvested", 100 * est_repo / n_raw))

  # ---- Descriptive statistics of the key metrics (main corpus) -----------------------------
  m <- d[main == TRUE]
  desc <- purrr::map_dfr(METRICS, function(k) {
    x <- m[[k]]
    tibble::tibble(metric = METRIC_LABELS[k], n = length(x), median = median(x), mean = mean(x),
                   p95 = unname(quantile(x, 0.95)), p99 = unname(quantile(x, 0.99)),
                   p999 = unname(quantile(x, 0.999)), max = max(x),
                   share_zero = mean(x == 0), share_at_minimum = mean(x == min(x)),
                   distinct_values = uniqueN(x))
  })
  save_table(desc, "corpus_descriptives")
  table_png(desc |> transmute(Metric = metric, Median = median, Mean = sprintf("%.2f", mean), `95th pct` = p95,
                              `99th pct` = p99, `99.9th pct` = format(p999, big.mark = ","),
                              `Share at 0` = pct(share_zero, 1), `Distinct values` = format(distinct_values, big.mark = ",")),
            "corpus_descriptives", title = "Key metric distributions in the main corpus",
            subtitle = sprintf("%s methods%s", format(nrow(m), big.mark = ","), if (harvest_complete) "" else " (PROVISIONAL)"))
  for (i in seq_len(nrow(desc))) {
    r <- desc[i, ]
    record(paste0(r$metric, ": median, main corpus"), r$median, n = r$n, section = "RQ1: corpus")
    record(paste0(r$metric, ": 95th percentile, main corpus"), r$p95, n = r$n, section = "RQ1: corpus")
    record(paste0(r$metric, ": 99.9th percentile, main corpus"), r$p999, n = r$n, section = "RQ1: corpus")
    record(paste0(r$metric, ": share of methods at 0, main corpus"), r$share_zero, n = r$n, section = "RQ1: corpus")
    record(paste0(r$metric, ": distinct values, main corpus"), r$distinct_values, n = r$n, section = "RQ1: corpus")
  }
  record("methods with CC > 10 (share of main corpus)", mean(m$cc > 10), n = sum(m$cc > 10), denominator = nrow(m),
         section = "RQ1: corpus")
  record("methods with CC = 1 (share of main corpus)", mean(m$cc == 1), n = sum(m$cc == 1), denominator = nrow(m),
         section = "RQ1: corpus")

  # ---- The 50 highest CC and CogC methods, before and after the added rules --------------------------------
  # Listed so the survivors can be read for generated code the rules still miss.
  top_list <- function(keep, col, n = 50) {
    idx <- which(keep)
    top <- idx[order(-d[[col]][idx], idx)][seq_len(n)]
    tibble::tibble(rank = seq_len(n), project = repo_levels[d$repo[top]],
                   class_name = nm$class_name[d$row_id[top]], method_name = nm$method_name[d$row_id[top]],
                   cc = d$cc[top], cognitive = d$cognitive[top], loc = d$loc[top],
                   file_path = nm$file_path[d$row_id[top]], removed_by_added_rules = d$gen_rules[top])
  }
  for (col in c("cc", "cognitive")) {
    short <- if (col == "cc") "cc" else "cogc"
    before <- top_list(pre_main, col)
    save_table(before, paste0("corpus_top50_", short, "_before_added_rules"))
    save_table(top_list(d$main, col) |> select(-removed_by_added_rules), paste0("corpus_top50_", short, "_main"))
    record(paste0("added generated-code rules: how many of the 50 highest ", METRIC_LABELS[col], " methods they removed"),
           sum(before$removed_by_added_rules), n = 50, section = "RQ1: corpus",
           note = "top 50 of the pre-rule main corpus (methods, with a body, not nested, not flagged generated at harvest)")
  }
  rm(nm); invisible(gc())

  # ---- Compact working files for later scripts -----------------------------------------------
  saveRDS(d, file.path(PATHS$work, "corpus_key.rds"))
  saveRDS(list(repo_levels = repo_levels, complete = harvest_complete, n_raw = n_raw, repos = as.data.frame(repos[, .(project, stars, forks, contributors, commit_count)])),
          file.path(PATHS$work, "corpus_meta.rds"))
  save_numbers("02_load_corpus")
  save_validation("02_load_corpus")
  cat("Corpus loaded:", format(n_raw, big.mark = ","), "rows;", format(sum(d$main), big.mark = ","), "in the main corpus\n")
})
