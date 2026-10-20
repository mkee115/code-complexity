# =============================================================================
# 04_tables_and_export.R
# Report-ready tables, then the report numbers, figure index, validation log, session info and privacy scan.
#
# Each section runs in its own local() block, so its variables do not leak into the
# next one. Intermediate results pass between sections as files in output/_pipeline/.
# =============================================================================

source("scripts/00_setup.R")

# -----------------------------------------------------------------------------
# SECTION 13_tables
# Report-ready tables rendered as PNG (the section folders under output/, as tbl_*.png). The full numbers
# are in the CSV files next to them.
# -----------------------------------------------------------------------------
local({
  rq1s <- readRDS(file.path(PATHS$work, "rq1_survey.rds"))
  rq1c <- readRDS(file.path(PATHS$work, "rq1_corpus_concordance.rds"))
  pca_c <- readRDS(file.path(PATHS$work, "rq1_corpus_pca.rds"))
  rq2 <- readRDS(file.path(PATHS$work, "rq2_results.rds"))
  grids <- readRDS(file.path(PATHS$work, "rq2_grids.rds"))
  rq3 <- readRDS(file.path(PATHS$work, "rq3_results.rds"))
  meta <- readRDS(file.path(PATHS$work, "corpus_meta.rds"))
  prov <- if (meta$complete) NULL else "PROVISIONAL: corpus harvest still running"
  snip <- read_csv(PATHS$snippets, show_col_types = FALSE)

  # ---- RQ1: survey concordance counts (the six metric pairs) --------------------------------------
  conc_tbl <- rq1s$concordance |>
    mutate(class = factor(class, levels = CONCORDANCE_LEVELS)) |>
    select(metric_pair, class, n) |>
    pivot_wider(names_from = class, values_from = n) |>
    transmute(`Metric pair` = metric_pair, Concordant, `One ties, other separates` = `One ties, other separates`,
              `Both tie`, Discordant, Total = Concordant + `One ties, other separates` + `Both tie` + Discordant)
  save_table(conc_tbl, "tbl_rq1_concordance_survey_counts")
  table_png(conc_tbl, "rq1_concordance_survey", title = "How the metrics order the 44 survey pairs",
            subtitle = "Number of pairs in each category, for each pair of metrics")

  # ---- RQ1: corpus concordance (non-trivial and all) -----------------------------------------------
  cc_tbl <- rq1c$conc |>
    mutate(cell = sprintf("%s", pct(prop, 1)), class = factor(class, levels = CONCORDANCE_LEVELS)) |>
    select(source, metric_pair, class, cell) |>
    pivot_wider(names_from = class, values_from = cell) |>
    rename(Sample = source, `Metric pair` = metric_pair)
  save_table(cc_tbl, "tbl_rq1_concordance_corpus_shares")
  table_png(cc_tbl, "rq1_concordance_corpus", title = "How the metrics order pairs of corpus methods",
            subtitle = prov, left_cols = 2,
            wrap_note = "1,000,000 random method pairs per sample. Uncertainty from pair sampling is tiny; it says nothing about how representative the corpus is.")

  # ---- RQ1: resolution --------------------------------------------------------------------------------
  rs <- rq1s$resolution; rc <- rq1c$resolution
  res_tbl <- tibble::tibble(
    Metric = rs$metric,
    `Distinct values (corpus)` = format(rc$distinct_values, big.mark = ","),
    `Most common value` = sprintf("%s (%s of methods)", rc$modal_value, pct(rc$share_at_modal_value, 0)),
    `Two random methods tie` = pct(rc$pair_tie_rate_random, 0),
    `Distinct values (34 snippets)` = rs$distinct_values_34_snippets,
    `Survey pairs tied` = sprintf("%d/44 (%s)", rs$pairs_tied, pct(rs$prop_pairs_tied, 0)),
    `Survey responses on a tied pair` = sprintf("%d/750 (%s)", rs$responses_tied, pct(rs$prop_responses_tied, 0)))
  save_table(res_tbl, "tbl_rq1_resolution")
  table_png(res_tbl, "rq1_resolution", title = "Resolution: how many different values each metric takes and how often it ties", subtitle = prov)

  # ---- RQ1: PCA variance --------------------------------------------------------------------------------
  pv <- bind_rows(pca_c$key_var, rq1s$pca_var |> filter(grepl("key metrics \\(log1p", dataset))) |>
    transmute(Dataset = dataset, Component = component, `Variance explained` = pct(variance, 1), Cumulative = pct(cumulative, 1)) |>
    mutate(Dataset = sub(" \\(.*", "", Dataset))
  table_png(pv, "rq1_pca_variance", title = "Variance explained by each principal component (four key metrics)",
            subtitle = prov, wrap_note = "Corpus: log(1 + x), standardised. Survey: 34 deliberately constructed snippets, not a random sample of Java methods.")

  # ---- RQ2: agreement summary ---------------------------------------------------------------------------
  ag <- rq2$agreement; kp <- rq2$kappa; dr <- rq2$direction
  dec <- rq2$decomp |> filter(decomp == "Metric ties, participant takes a side") |> select(metric_label, tie_side = prop)
  ag_tbl <- tibble::tibble(
    Metric = as.character(ag$metric_label),
    `Agreement, all responses` = sprintf("%s (%d/%d)", fmt_ci(ag$agree_all, ag$all_low, ag$all_high), ag$n_agree, ag$n_all),
    `Cohen's kappa` = sprintf("%.2f (%.2f–%.2f)", kp$kappa, kp$kappa_low, kp$kappa_high),
    `Metric ties, participant takes a side` = pct(dec$tie_side[match(ag$metric_label, dec$metric_label)], 0),
    `Right way round when both take a side` = sprintf("%s (%d/%d)", pct(dr$prop_right, 0), dr$right, dr$n),
    `Decisive-only agreement` = fmt_ci(ag$agree_decisive, ag$dec_low, ag$dec_high))
  save_table(ag_tbl, "tbl_rq2_agreement_summary")
  table_png(ag_tbl, "rq2_agreement_summary", title = "Agreement between each metric and participants' judgements",
            wrap_note = "95% CIs from resampling participants (10,000 resamples). A metric tie agrees only with 'No difference'; the decisive-only column drops 'No difference' responses.")

  # ---- RQ2: comparing metrics --------------------------------------------------------------------------------
  cmp_tbl <- rq2$paired |>
    transmute(Comparison = comparison, `Difference in agreement` = sprintf("%+.1f points (%+.1f to %+.1f)", 100 * diff, 100 * low, 100 * high),
              `Only first agrees` = only_first_agrees, `Only second agrees` = only_second_agrees, `Holm p` = fmt_p(p_holm))
  save_table(cmp_tbl, "tbl_rq2_metric_comparisons")
  table_png(cmp_tbl, "rq2_metric_comparisons", title = "Direct comparisons of the metrics on the same responses",
            wrap_note = "Difference = second metric minus first. CI: participant bootstrap. p: exact McNemar test (independence assumed), Holm-corrected over six comparisons.")

  # ---- RQ2: grid tests --------------------------------------------------------------------------------------
  gt <- grids$tests |>
    transmute(`Metric pair` = metric_pair, Cells = group, `Distinct pairs` = pairs, `Decisive responses` = decisive,
              `On the separating metric's side` = ifelse(decisive > 0, sprintf("%d (%s)", favouring, pct(prop, 0)), "–"),
              `Holm p` = fmt_p(p_holm))
  save_table(gt, "tbl_rq2_grid_tests")
  table_png(gt, "rq2_grid_tests", title = "Where two metrics disagree: whose side did participants take?",
            subtitle = "Decisive responses only (No difference excluded)", left_cols = 2,
            wrap_note = "Exact binomial test against 50%, treating responses as independent. Many cells rest on only a few distinct pairs; empty rows mean the survey has no such pair.")

  # ---- RQ2: pairs where all four metrics tie ------------------------------------------------------------------------
  at <- rq2$all_tie |>
    transmute(Pair = paste(method_a_id, "vs", method_b_id), Responses = n, `Chose A` = chose_A, `No difference` = no_difference, `Chose B` = chose_B,
              `Expressed a preference` = pct(prop_preference, 0))
  at <- bind_rows(at, tibble::tibble(Pair = "All pairs", Responses = sum(at$Responses), `Chose A` = sum(at$`Chose A`),
                                     `No difference` = sum(at$`No difference`), `Chose B` = sum(at$`Chose B`),
                                     `Expressed a preference` = pct(1 - sum(at$`No difference`) / sum(at$Responses), 0)))
  save_table(at, "tbl_rq2_all_tie_pairs")
  table_png(at, "rq2_all_tie_pairs", title = "Pairs on which CC, CogC, LOC and MaxNest all tie",
            subtitle = "What participants said when no key metric could tell the two methods apart",
            wrap_note = "These pairs differ only in comments, Javadoc or naming. A is always the earlier version.")

  # ---- RQ2: position ----------------------------------------------------------------------------------------------
  ps <- rq2$position |>
    transmute(Subset = subset, Pairs = pairs, `Chose A (left)` = chose_A, `Chose B (right)` = chose_B, `No difference` = no_difference,
              `Share choosing B` = fmt_ci(prop_B, propB_low, propB_high),
              `B minus A (points)` = sprintf("%+.1f (%+.1f to %+.1f)", 100 * diff_B_minus_A, 100 * diff_low, 100 * diff_high))
  save_table(ps, "tbl_position_lean")
  table_png(ps, "position_lean", title = "Preference for the left or right method",
            subtitle = "Decisive responses; 95% CI from resampling participants")

  # ---- RQ3 -----------------------------------------------------------------------------------------------------------
  op <- rq3$orig_pairs |>
    arrange(desc(share_prefer_refactor)) |>
    transmute(Refactor = method_b_id, `Prefer refactor` = prefer_refactor, `Prefer original` = prefer_original, `No difference` = no_difference,
              `Share preferring refactor (95% CI)` = fmt_ci(share_prefer_refactor, ci_low, ci_high, 0),
              `Holm p` = fmt_p(p_holm), Outcome = outcome)
  save_table(op, "tbl_rq3_original_vs_refactor")
  table_png(op, "rq3_original_vs_refactor", title = "Each refactor against its original",
            wrap_note = sprintf("Exact binomial test on decisive responses, Holm-corrected over %d pairs; CI: Wilson. Responses treated as independent; pairs have %d to %d responses.",
                              nrow(rq3$orig_pairs), min(rq3$orig_pairs$n), max(rq3$orig_pairs$n)))

  ft <- rq3$factor_tbl |>
    transmute(`Kind of change` = factor, Variants = variants, Responses = responses,
              `Mean net preference for refactor` = sprintf("%+.2f", mean_net_preference),
              `Decisive responses preferring refactor` = pct(share_refactor_decisive, 0))
  save_table(ft, "tbl_rq3_type_of_change")
  table_png(ft, "rq3_type_of_change", title = "Perceived effect by kind of change (descriptive)",
            wrap_note = "Net preference = mean(rating − 3), positive when the refactor is judged less complex. Each kind of change rests on one to four variants.")

  rc3 <- rq3$red_cor |> transmute(Metric = as.character(metric_label), `Spearman rho` = sprintf("%.2f", rho), Pairs = pairs, `Holm p` = fmt_p(p_holm))
  table_png(rc3, "rq3_reduction_vs_preference", title = "Reduction in a measurement vs perceived improvement",
            subtitle = "Spearman correlation across the 24 original-vs-refactor pairs")

  # ---- Snippet measurements (appendix material) ---------------------------------------------------------------------
  sn <- snip |> transmute(Snippet = id, Method = method, CC = cc, CogC = cognitive, LOC = loc, MaxNest = max_nesting)
  save_table(sn, "tbl_survey_snippet_measurements")
  table_png(sn |> slice(1:17), "survey_snippet_measurements_1", title = "Measurements of the survey snippets (1 of 2)")
  table_png(sn |> slice(18:34), "survey_snippet_measurements_2", title = "Measurements of the survey snippets (2 of 2)")

  save_numbers("13_tables")
  cat("Tables written\n")
})

# -----------------------------------------------------------------------------
# SECTION 14_export
# Combines everything: report_numbers.csv, the validation log, the figure index,
# sessionInfo.txt; then a privacy scan of every output file.
# -----------------------------------------------------------------------------
local({
  # ---- report_numbers.csv --------------------------------------------------------------------
  parts <- list.files(PATHS$work, pattern = "^numbers_.*\\.csv$", full.names = TRUE)
  numbers <- bind_rows(lapply(parts, read_csv, show_col_types = FALSE, col_types = cols(.default = "c"))) |>
    mutate(across(c(value, ci_low, ci_high, n, denominator, p), ~ suppressWarnings(as.numeric(.x))))
  validate("report_numbers: every number has a name and a section", !anyNA(numbers$name) && !anyNA(numbers$section))
  key <- c("name", "subset", "section", "denominator", "n")
  validate("report_numbers: no duplicated entries", !anyDuplicated(numbers[key]),
           paste(sum(duplicated(numbers[key])), "duplicates"))
  write_csv(numbers, "output/report_numbers.csv")
  cat(nrow(numbers), "numbers recorded from", length(parts), "scripts\n")

  # ---- Figure index ----------------------------------------------------------------------------------
  fparts <- list.files(PATHS$work, pattern = "^figures_.*\\.csv$", full.names = TRUE)
  index <- bind_rows(lapply(fparts, read_csv, show_col_types = FALSE, col_types = cols(.default = "c")))
  tk_file <- "scripts/figure_takeaways.csv"
  if (file.exists(tk_file)) {
    index <- index |> left_join(read_csv(tk_file, show_col_types = FALSE, col_types = cols(.default = "c")), by = "figure")
  } else {
    index$takeaway <- NA
    index$suggested_use <- NA
  }
  index <- index |> arrange(folder, desc(importance), figure)
  on_disk <- basename(list.files(file.path(PATHS$out, SECTIONS), pattern = "^(fig|diag).*[.]png$", recursive = TRUE))
  validate("every figure on disk is in the figure index", all(on_disk %in% index$figure), paste(setdiff(on_disk, index$figure), collapse = ", "))
  validate("every figure has a suggested takeaway", !anyNA(index$takeaway), paste(index$figure[is.na(index$takeaway)], collapse = ", "),
           stop_on_fail = FALSE)
  write_csv(index, "output/figure_index.csv")

  # Every main and supporting figure exists in its section folder and has a title-free version in figures_no_titles/
  chk <- index |> filter(suggested_use %in% c("main", "supporting")) |>
    mutate(src = file.path(PATHS$out, folder, importance, figure), src_nt = file.path(PATHS$out, "figures_no_titles", folder, figure))
  validate("main and supporting figures: every source file exists", all(file.exists(chk$src)), paste(chk$figure[!file.exists(chk$src)], collapse = ", "))
  validate("main and supporting figures: every title-free version exists", all(file.exists(chk$src_nt)),
           paste(chk$figure[!file.exists(chk$src_nt)], collapse = ", "))

  # ---- Session info -------------------------------------------------------------------------------------
  writeLines(capture.output(sessionInfo()), "output/sessionInfo.txt")

  # ---- Privacy scan: no identifying survey information anywhere in the outputs ----------------------------
  bad_cols <- c("IPAddress", "LocationLatitude", "LocationLongitude", "RecipientEmail", "RecipientFirstName",
                "RecipientLastName", "ResponseId", "ExternalReference")
  files <- list.files("output", pattern = "\\.(csv|txt)$", recursive = TRUE, full.names = TRUE)
  files <- files[!grepl("sessionInfo", files)]
  ip_pattern <- "(^|[^0-9.])[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}($|[^0-9.])"
  hits <- character()
  for (f in files) {
    if (any(grepl(ip_pattern, readLines(f, warn = FALSE)))) hits <- c(hits, paste(f, "(IP-like value)"))
    if (grepl("\\.csv$", f) && any(bad_cols %in% names(read_csv(f, n_max = 0, show_col_types = FALSE))))
      hits <- c(hits, paste(f, "(identifying column)"))
  }
  validate("no identifying survey columns or IP addresses in any output file", length(hits) == 0, paste(hits, collapse = "; "))

  # ---- Validation log: all scripts plus the checks above ---------------------------------------------------
  vparts <- list.files(PATHS$work, pattern = "^validation_[0-9].*\\.csv$", full.names = TRUE)
  vlog <- bind_rows(c(lapply(vparts, read_csv, show_col_types = FALSE, col_types = cols(.default = "c")),
                         lapply(.checks$rows, function(x) mutate(x, passed = as.character(passed))))) |>
    mutate(passed = as.character(passed) == "TRUE")
  write_csv(vlog, file.path(PATHS$work, "validation_log.csv"))
  cat(sprintf("Validation log: %d checks, %d not passed\n", nrow(vlog), sum(!vlog$passed)))
  if (any(!vlog$passed)) print(vlog |> filter(!passed) |> select(check, detail))
  cat("Export complete\n")
})
