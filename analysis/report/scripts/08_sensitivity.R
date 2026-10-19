# =============================================================================
# 08_sensitivity.R  (sensitivity and robustness; none of these change the main rules)
#
# 9.1 Excluding participants who failed screening questions (C, 2, 24)
# 9.2 Decisive responses only (structurally penalises metrics that tie)
# 9.3 Excluding metric-tied comparisons (and No difference responses)
# 9.4 Self-reported programming experience (original categories)
# 9.5 Corpus filtering choices
# =============================================================================

source("scripts/00_setup.R")
participants <- readRDS(file.path(PATHS$work, "participants.rds"))
scored <- readRDS(file.path(PATHS$work, "scored_rq2.rds"))
pids <- participants$pid
P <- length(pids)
boot_mean_ci <- boot_helpers(pids)$mean_ci

agree_ci <- function(d) {
  ci <- boot_mean_ci(d$agree, d$pid)
  tibble::tibble(n = nrow(d), n_agree = sum(d$agree), agree = mean(d$agree), low = ci[["low"]], high = ci[["high"]],
                 people = n_distinct(d$pid), pairs = n_distinct(d$item))
}

# ---- Main result (for the comparisons) -----------------------------------------------
main <- scored |> group_by(metric_label) |> group_modify(~ agree_ci(.x)) |> ungroup() |>
  mutate(analysis = "Main analysis: all 750 responses")

# ---- 9.1 Screening questions ----------------------------------------------------------------
strict_ids <- participants$pid[participants$java_correct == 3]
strict <- scored |> filter(pid %in% strict_ids) |> group_by(metric_label) |> group_modify(~ agree_ci(.x)) |> ungroup() |>
  mutate(analysis = "Only participants with all 3 screening questions correct")
validate("screening subset: 10 responses for every retained participant",
         length(strict_ids) == sum(participants$java_correct == 3) && all(strict$n == 10 * length(strict_ids)),
         paste(length(strict_ids), "participants"))
record("screening sensitivity: participants retained", length(strict_ids), n = length(strict_ids), denominator = P, section = "Sensitivity 9.1")
record("screening sensitivity: responses retained", length(strict_ids) * 10, n = length(strict_ids) * 10, denominator = 750, section = "Sensitivity 9.1")

# ---- 9.2 Decisive responses only --------------------------------------------------------------
decisive <- scored |> filter(human != 0) |> group_by(metric_label) |> group_modify(~ agree_ci(.x)) |> ungroup() |>
  mutate(analysis = "Decisive responses only (No difference excluded)")

# ---- 9.3 Excluding metric-tied comparisons and No difference --------------------------------------
tie_free <- scored |> filter(human != 0, predicted != 0) |> group_by(metric_label) |> group_modify(~ agree_ci(.x)) |> ungroup() |>
  mutate(analysis = "Metric separates and participant chooses a side")
overall_ties <- scored |> group_by(metric_label) |> summarise(share_metric_tie = mean(predicted == 0), .groups = "drop")

sens <- bind_rows(main, strict, decisive, tie_free) |>
  mutate(analysis = factor(analysis, levels = unique(analysis)))
sens <- sens |> left_join(main |> select(metric_label, main_agree = agree), by = "metric_label") |>
  mutate(diff_from_main = agree - main_agree) |>
  left_join(overall_ties, by = "metric_label")
save_table(sens, "sensitivity_agreement")
for (i in seq_len(nrow(sens))) {
  r <- sens[i, ]
  record(paste0(r$metric_label, " agreement: ", r$analysis), r$agree, r$low, r$high, n = r$n_agree, denominator = r$n,
         test = "participant cluster bootstrap 95% CI", section = "Sensitivity 9.1-9.3", subset = as.character(r$analysis),
         note = sprintf("%d participants; difference from main %+.1f points", r$people, 100 * r$diff_from_main))
}
note_9_3 <- paste(strwrap(paste("The subset differs between metrics (each drops the pairs where it ties), so these percentages are not",
                                "comparable as if from one sample. A diagnostic of direction accuracy, not a ranking of the metrics.",
                                "Where the counts differ between metrics they are listed in the order CC / CogC / LOC / MaxNest."),
                          width = 150), collapse = "\n")
# Participants and responses: one number when every metric uses the same responses, otherwise one per metric
# (CC / CogC / LOC / MaxNest), so the table never shows one metric's counts for another.
counts_by_analysis <- sens |>
  group_by(analysis) |>
  summarise(Participants = if (n_distinct(people) == 1) as.character(first(people)) else paste(people, collapse = " / "),
            Responses = if (n_distinct(n) == 1) as.character(first(n)) else paste(n, collapse = " / "), .groups = "drop")
validate("sensitivity table lists each metric's own response count where they differ",
         identical(as.character(sens$metric_label[sens$analysis == levels(sens$analysis)[4]]), c("CC", "CogC", "LOC", "MaxNest")) &&
           identical(counts_by_analysis$Responses[4], paste(sens$n[sens$analysis == levels(sens$analysis)[4]], collapse = " / ")),
         counts_by_analysis$Responses[4])
sens_tbl <- sens |>
  mutate(cell = sprintf("%s (%s)", pct(agree, 1), pct(diff_from_main, 1) |> sub(pattern = "^(?=[0-9])", replacement = "+", perl = TRUE))) |>
  select(analysis, metric_label, cell) |>
  pivot_wider(names_from = metric_label, values_from = cell) |>
  left_join(counts_by_analysis, by = "analysis") |>
  transmute(Analysis = as.character(analysis), Participants, Responses, CC, CogC, LOC, MaxNest)
table_png(sens_tbl, "sensitivity_agreement", title = "Agreement under alternative inclusion rules",
          subtitle = "Agreement % (difference from the main analysis in percentage points)", wrap_note = note_9_3)

# ---- 9.4 Self-reported programming experience -------------------------------------------------------
exp_tbl <- scored |>
  left_join(participants |> select(pid, experience), by = "pid") |>
  group_by(experience, metric_label) |>
  group_modify(~ agree_ci(.x)) |>
  ungroup()
save_table(exp_tbl, "sensitivity_experience")
for (i in seq_len(nrow(exp_tbl))) {
  r <- exp_tbl[i, ]
  record(paste0(r$metric_label, " agreement, experience: ", r$experience), r$agree, r$low, r$high, n = r$n_agree,
         denominator = r$n, test = "participant cluster bootstrap 95% CI", section = "Sensitivity 9.4",
         note = sprintf("%d participants", r$people))
}
# Per-participant agreement (10 responses each) against experience (ordered 0-4), per metric
person <- scored |>
  left_join(participants |> select(pid, experience), by = "pid") |>
  group_by(pid, metric_label, experience) |> summarise(agree = mean(agree), .groups = "drop")
exp_tests <- purrr::map_dfr(levels(scored$metric_label), function(ml) {
  d <- person |> filter(metric_label == ml)
  ct <- suppressWarnings(cor.test(as.numeric(d$experience), d$agree, method = "spearman", exact = FALSE))
  kw <- kruskal.test(agree ~ experience, data = d)
  tibble::tibble(metric = ml, rho = unname(ct$estimate), p_spearman = ct$p.value, p_kw = kw$p.value, participants = nrow(d))
}) |> mutate(p_spearman_holm = p.adjust(p_spearman, "holm"), p_kw_holm = p.adjust(p_kw, "holm"))
save_table(exp_tests, "sensitivity_experience_tests")
for (i in seq_len(nrow(exp_tests))) {
  r <- exp_tests[i, ]
  record(paste0(r$metric, ": Spearman, experience level vs participant's agreement rate"), r$rho, n = r$participants,
         test = "Spearman over participants (each participant's agreement rate), Holm across 4 metrics", p = r$p_spearman_holm,
         section = "Sensitivity 9.4", note = "a non-significant result does not show experience has no effect")
}
# Does the metric effect differ by experience? Likelihood-ratio test of the metric x experience interaction
glmm_exp <- tryCatch({
  d <- scored |> left_join(participants |> select(pid, experience), by = "pid") |>
    mutate(exp_num = as.numeric(experience) - 1)
  f0 <- lme4::glmer(agree ~ metric_label + exp_num + (1 | pid) + (1 | item), data = d, family = binomial,
                    control = lme4::glmerControl(optimizer = "bobyqa"))
  f1 <- lme4::glmer(agree ~ metric_label * exp_num + (1 | pid) + (1 | item), data = d, family = binomial,
                    control = lme4::glmerControl(optimizer = "bobyqa"))
  an <- anova(f0, f1)
  list(p = an$`Pr(>Chisq)`[2], chisq = an$Chisq[2], b_exp = unname(lme4::fixef(f0)["exp_num"]))
}, error = function(e) NULL)
if (!is.null(glmm_exp)) {
  record("mixed model: experience (per level) log-odds of agreement", glmm_exp$b_exp, n = 750,
         test = "glmer agree ~ metric + experience + (1|participant) + (1|pair)", section = "Sensitivity 9.4")
  record("mixed model: metric x experience interaction (likelihood-ratio chi-squared)", glmm_exp$chisq, n = 750,
         test = "likelihood-ratio test", p = glmm_exp$p, section = "Sensitivity 9.4",
         note = "tests whether the metrics' agreement differs across experience levels")
}
exp_counts <- participants |> count(experience) |> mutate(experience = as.character(experience))
save_table(exp_counts, "sensitivity_experience_group_sizes")

# ---- 9.5 Corpus filtering ---------------------------------------------------------------------------
d <- readRDS(file.path(PATHS$work, "corpus_key.rds"))
meta <- readRDS(file.path(PATHS$work, "corpus_meta.rds"))
prov <- if (meta$complete) "" else " (PROVISIONAL)"
variants <- list(
  "Main corpus (methods, with body, not nested, not generated)" = d$main,
  "+ constructors" = !d$bodyless & !d$nested & !d$generated & !d$gen_rules,
  "+ methods without a body" = !d$is_ctor & !d$nested & !d$generated & !d$gen_rules,
  "+ nested methods" = !d$is_ctor & !d$bodyless & !d$generated & !d$gen_rules,
  "+ generated code" = !d$is_ctor & !d$bodyless & !d$nested,
  "Without file-level propagation (name and path rules only)" = !d$is_ctor & !d$bodyless & !d$nested & !d$generated & !d$gen_rules_basic,
  "Without the added generated-code rules (harvest flag only)" = !d$is_ctor & !d$bodyless & !d$nested & !d$generated,
  "Also excluding /tests/ paths" = d$main & !d$test_path,
  "Duplicates removed (first copy kept)" = d$main & !d$dup,
  "No filtering at all" = rep(TRUE, nrow(d)))
N_PAIR_S <- 3e5      # sampled pairs per filtering variant (fewer than the main 1e6 because there are 10 variants)
corpus_sens <- purrr::map_dfr(names(variants), function(nm) {
  m <- d[variants[[nm]]]
  X <- as.matrix(m[, ..METRICS]); colnames(X) <- METRIC_LABELS[METRICS]
  rho <- cor(apply(X, 2, frank, ties.method = "average"))
  ev <- eigen(cor(log1p(X)), symmetric = TRUE)$values
  pr <- sample_pairs(nrow(X), N_PAIR_S)
  S <- apply(X, 2, function(x) sign(x[pr$i] - x[pr$j]))
  rows <- purrr::map_dfr(METRIC_PAIRS, function(mp) {
    cls <- concordance_class(S[, METRIC_LABELS[mp[1]]], S[, METRIC_LABELS[mp[2]]])
    tibble::tibble(metric_pair = metric_pair_label(mp[1], mp[2]),
                   rho = rho[METRIC_LABELS[mp[1]], METRIC_LABELS[mp[2]]],
                   concordant = mean(cls == "Concordant"), discordant = mean(cls == "Discordant"),
                   one_ties = mean(cls == "One ties, other separates"), both_tie = mean(cls == "Both tie"))
  })
  rows |> mutate(filter = nm, methods = nrow(X), cc_equals_1 = mean(m$cc == 1), pc1_share = ev[1] / sum(ev),
                 tie_cc = mean(S[, "CC"] == 0), tie_cogc = mean(S[, "CogC"] == 0),
                 tie_loc = mean(S[, "LOC"] == 0), tie_maxnest = mean(S[, "MaxNest"] == 0))
}) |>
  mutate(filter = factor(filter, levels = names(variants)))
save_table(corpus_sens, "sensitivity_corpus_filters")
main_rows <- corpus_sens |> filter(filter == names(variants)[1]) |> select(metric_pair, main_rho = rho, main_conc = concordant)
corpus_diff <- corpus_sens |> left_join(main_rows, by = "metric_pair") |>
  group_by(filter) |>
  summarise(methods = first(methods), cc_equals_1 = first(cc_equals_1), pc1_share = first(pc1_share),
            max_abs_rho_change = max(abs(rho - main_rho)), max_abs_concordant_change = max(abs(concordant - main_conc)),
            min_rho = min(rho), .groups = "drop")
save_table(corpus_diff, "sensitivity_corpus_filters_summary")
for (i in seq_len(nrow(corpus_diff))) {
  r <- corpus_diff[i, ]
  record(paste0("corpus filter '", r$filter, "': largest change in any key Spearman correlation vs main"), r$max_abs_rho_change,
         n = r$methods, section = "Sensitivity 9.5", note = paste0("PC1 share ", pct(r$pc1_share, 1), "; CC = 1 share ", pct(r$cc_equals_1, 1), prov))
  record(paste0("corpus filter '", r$filter, "': largest change in concordant share vs main"), r$max_abs_concordant_change,
         n = r$methods, section = "Sensitivity 9.5", note = prov)
}
# The /tests/ exclusion is broader than the main filter (test code outside src/test), so it is only a check
record("sensitivity: methods under /tests/ paths removed from the main corpus", sum(d$main & d$test_path),
       denominator = sum(d$main), section = "Sensitivity 9.5", note = "sensitivity check only; not part of the main filter")
for (nm_v in c("Main corpus (methods, with body, not nested, not generated)",
               "Without file-level propagation (name and path rules only)",
               "Without the added generated-code rules (harvest flag only)", "Also excluding /tests/ paths")) {
  mv <- d[variants[[nm_v]]]
  record(paste0("largest CC, '", nm_v, "'"), max(mv$cc), n = nrow(mv), section = "Sensitivity 9.5")
  record(paste0("largest CogC, '", nm_v, "'"), max(mv$cognitive), n = nrow(mv), section = "Sensitivity 9.5")
}
table_png(corpus_diff |> transmute(Filter = as.character(filter), Methods = format(methods, big.mark = ","),
                                   `CC = 1` = pct(cc_equals_1, 0), `PC1 share` = pct(pc1_share, 0),
                                   `Lowest Spearman` = sprintf("%.2f", min_rho),
                                   `Max change in Spearman` = sprintf("%.3f", max_abs_rho_change),
                                   `Max change in concordant` = pct(max_abs_concordant_change, 1)),
          "sensitivity_corpus_filters", title = "Do the corpus conclusions depend on the filtering?",
          subtitle = paste0("Changes are relative to the main corpus; 300,000 sampled pairs per filter", prov))

saveRDS(list(sens = sens, exp = exp_tbl, exp_tests = exp_tests, corpus = corpus_sens, corpus_diff = corpus_diff),
        file.path(PATHS$work, "sensitivity_results.rds"))
save_numbers("08_sensitivity")
save_validation("08_sensitivity")
