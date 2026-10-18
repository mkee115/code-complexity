# =============================================================================
# 05_rq2_agreement.R  (RQ2: which metrics agree most closely with programmers?)
#
# 0. Independent re-computation of agreement (validation)
# a. Agreement per metric over all 750 responses (headline), participant-level
#    cluster bootstrap CIs
# b. Cohen's kappa (agreement beyond chance)
# c. Decomposition: does the metric take a side, and is it the right way round?
# d. Comparing metrics directly: bootstrap difference, exact McNemar, Holm,
#    mixed-effects logistic regression
# e. Agreement by tie status and side of the lower measurement
# f. Measurement gap vs strength of preference
# g. Pair-level relationship (each of the 44 pairs counted once)
# h. Pairs where all four key metrics tie
# i. Position diagnostics (Method A was always the earlier version)
# The 3x3 metric-comparison grids are in 06_rq2_grids.R.
# =============================================================================

source("scripts/00_setup.R")
participants <- readRDS(file.path(PATHS$work, "participants.rds"))
responses <- readRDS(file.path(PATHS$work, "responses.rds"))
scored <- readRDS(file.path(PATHS$work, "scored.rds"))
snip <- read_csv(PATHS$snippets, show_col_types = FALSE)

pids <- participants$pid
P <- length(pids)
bh <- boot_helpers(pids)
W <- bh$W; psum <- bh$psum; boot_mean_ci <- bh$mean_ci
GAP_BOOT <- 2000      # resamples for the gap-vs-strength Spearman CI (a per-resample correlation is slower than a ratio)

# ---- 0. Independent re-computation of agreement (validation) ----------------------------
for (mk in METRICS) {
  a <- snip[[mk]][match(responses$method_a_id, snip$id)]
  b <- snip[[mk]][match(responses$method_b_id, snip$id)]
  pred <- ifelse(a < b, "A", ifelse(a > b, "B", "none"))           # which method the metric says is less complex
  said <- ifelse(responses$rating < 3, "A", ifelse(responses$rating > 3, "B", "none"))
  indep <- sum(pred == said)
  here <- sum(scored$agree[scored$metric == mk])
  validate(paste0("agreement for ", METRIC_LABELS[mk], " matches an independent re-computation"), indep == here,
           sprintf("%d vs %d", indep, here))
}

# ---- a. Agreement -------------------------------------------------------------
agreement <- scored |>
  group_by(metric, metric_label) |>
  group_modify(function(d, k) {
    ci_all <- boot_mean_ci(d$agree, d$pid)
    dec <- d$human != 0
    ci_dec <- boot_ratio_ci(W, psum(d$agree & dec, d$pid), psum(dec, d$pid))
    tibble::tibble(
      n_agree = sum(d$agree), n_all = nrow(d), agree_all = mean(d$agree),
      all_low = ci_all["low"], all_high = ci_all["high"],
      n_agree_decisive = sum(d$agree[dec]), n_decisive = sum(dec), agree_decisive = mean(d$agree[dec]),
      dec_low = ci_dec["low"], dec_high = ci_dec["high"])
  }) |>
  ungroup() |>
  arrange(metric_label)
save_table(agreement, "rq2_agreement")
for (i in seq_len(nrow(agreement))) {
  r <- agreement[i, ]
  record(paste0(r$metric_label, ": agreement, all responses"), r$agree_all, r$all_low, r$all_high,
         n = r$n_agree, denominator = r$n_all, test = "participant cluster bootstrap 95% CI (10,000)", section = "RQ2",
         note = "headline measure: a metric tie agrees only with No difference")
  record(paste0(r$metric_label, ": agreement, decisive responses only"), r$agree_decisive, r$dec_low, r$dec_high,
         n = r$n_agree_decisive, denominator = r$n_decisive, test = "participant cluster bootstrap 95% CI", section = "RQ2",
         note = "No difference responses excluded; a tie can then never agree, so this penalises tying metrics")
}

# ---- b. Cohen's kappa -----------------------------------------------------------
# 3 x 3 table of prediction (-1, 0, 1) x participant choice (-1, 0, 1). Per-participant
# cell counts let the whole table be bootstrapped at once.
kappa_from_cells <- function(cells) {               # rows = tables, 9 columns
  n <- rowSums(cells)
  m <- array(cells, c(nrow(cells), 3, 3))           # [table, human, prediction]
  po <- (m[, 1, 1] + m[, 2, 2] + m[, 3, 3]) / n
  pe <- rowSums(apply(m, c(1, 3), sum) * apply(m, c(1, 2), sum)) / n^2
  (po - pe) / (1 - pe)
}
kappa_tbl <- scored |>
  group_by(metric, metric_label) |>
  group_modify(function(d, k) {
    cell <- (d$predicted + 1) * 3 + (d$human + 1) + 1   # 1..9, human varies fastest
    cells <- sapply(1:9, function(j) psum(cell == j, d$pid))
    est <- kappa_from_cells(matrix(colSums(cells), nrow = 1))
    boot <- kappa_from_cells(W %*% cells)
    validate(paste0("kappa for ", k$metric_label, " matches irr::kappa2"),
             abs(irr::kappa2(data.frame(d$predicted, d$human))$value - est) < 1e-9)
    q <- quantile(boot, c(0.025, 0.975), na.rm = TRUE)
    # Agreement expected by chance: if the metric's answers (A / equal / B) were unrelated to the
    # participant's, how often would they match, given how often each side gives each answer?
    tab <- table(factor(d$predicted, levels = -1:1), factor(d$human, levels = -1:1))
    pe <- sum(rowSums(tab) * colSums(tab)) / sum(tab)^2
    tibble::tibble(kappa = est, kappa_low = q[1], kappa_high = q[2], observed_agreement = mean(d$agree),
                   expected_by_chance = pe, n = nrow(d))
  }) |>
  ungroup() |>
  arrange(metric_label)
save_table(kappa_tbl, "rq2_kappa")
for (i in seq_len(nrow(kappa_tbl))) {
  r <- kappa_tbl[i, ]
  record(paste0(r$metric_label, ": Cohen's kappa vs participants"), r$kappa, r$kappa_low, r$kappa_high,
         n = r$n, test = "three-category Cohen's kappa, participant cluster bootstrap 95% CI", section = "RQ2",
         note = if (r$kappa_low <= 0) "CI includes 0: agreement beyond chance not established" else "CI excludes 0")
  record(paste0(r$metric_label, ": agreement expected by chance"), r$expected_by_chance, n = r$n, section = "RQ2",
         test = "from the 3x3 table of the metric's answers and participants' answers (independence)",
         note = "kappa = (observed - expected) / (1 - expected)")
}

# ---- c. Decomposition: resolution vs direction -----------------------------------
DECOMP_LEVELS <- c("Both take a side and agree", "Both take a side but disagree",
                   "Metric ties, participant takes a side",
                   "Metric takes a side, participant says no difference", "Both say no difference")
scored <- scored |>
  mutate(decomp = factor(case_when(
    predicted != 0 & human != 0 & agree ~ DECOMP_LEVELS[1],
    predicted != 0 & human != 0 ~ DECOMP_LEVELS[2],
    predicted == 0 & human != 0 ~ DECOMP_LEVELS[3],
    predicted != 0 & human == 0 ~ DECOMP_LEVELS[4],
    TRUE ~ DECOMP_LEVELS[5]), levels = DECOMP_LEVELS))
decomp <- scored |>
  count(metric_label, decomp, .drop = FALSE) |>
  group_by(metric_label) |>
  mutate(total = sum(n), prop = n / total) |>
  ungroup()
validate("decomposition categories are exclusive and sum to 750 for every metric", all(decomp |> group_by(metric_label) |> summarise(s = sum(n)) |> pull(s) == 750))
validate("'both agree' + 'both say no difference' equals overall agreement for every metric",
         all(abs((decomp |> filter(decomp %in% DECOMP_LEVELS[c(1, 5)]) |> group_by(metric_label) |> summarise(s = sum(n)) |> pull(s)) -
                   agreement$n_agree) < 1e-9))
save_table(decomp, "rq2_decomposition")
for (i in seq_len(nrow(decomp)))
  record(paste0(decomp$metric_label[i], ": ", decomp$decomp[i]), decomp$prop[i], n = decomp$n[i],
         denominator = decomp$total[i], section = "RQ2", note = "share of all 750 responses")

DECISIVE_LEVELS <- c("Metric agrees", "Metric points the other way", "Metric ties")
decisive_break <- scored |>
  filter(human != 0) |>
  mutate(outcome = factor(case_when(predicted == 0 ~ "Metric ties", agree ~ "Metric agrees",
                                    TRUE ~ "Metric points the other way"), levels = DECISIVE_LEVELS)) |>
  count(metric_label, outcome, .drop = FALSE) |>
  group_by(metric_label) |>
  mutate(total = sum(n), prop = n / total) |>
  ungroup()
validate("decisive breakdown sums to 675 responses for every metric", all(decisive_break |> group_by(metric_label) |> summarise(s = sum(n)) |> pull(s) == 675))
save_table(decisive_break, "rq2_decisive_responses_breakdown")
for (i in seq_len(nrow(decisive_break)))
  record(paste0(decisive_break$metric_label[i], ", participant chose a side: ", decisive_break$outcome[i]), decisive_break$prop[i],
         n = decisive_break$n[i], denominator = decisive_break$total[i], section = "RQ2",
         note = "share of the 675 responses where the participant did not say No difference")

direction <- scored |>
  filter(predicted != 0, human != 0) |>
  group_by(metric, metric_label) |>
  group_modify(function(d, k) {
    bt <- binom.test(sum(d$agree), nrow(d), 0.5)
    ci <- boot_mean_ci(d$agree, d$pid)
    tibble::tibble(right = sum(d$agree), wrong = sum(!d$agree), n = nrow(d), prop_right = mean(d$agree),
                   low = ci["low"], high = ci["high"], p_sign = bt$p.value)
  }) |>
  ungroup() |>
  mutate(p_holm = p.adjust(p_sign, "holm")) |>
  arrange(metric_label)
save_table(direction, "rq2_direction_when_both_take_a_side")
for (i in seq_len(nrow(direction))) {
  r <- direction[i, ]
  record(paste0(r$metric_label, ": right way round when both take a side"), r$prop_right, r$low, r$high,
         n = r$right, denominator = r$n,
         test = "exact binomial test vs 50% (treats responses as independent), Holm across 4 metrics; CI participant bootstrap",
         p = r$p_holm, section = "RQ2")
}

# ---- d. Comparing metrics directly --------------------------------------------------
wide_agree <- scored |> select(pid, item, metric, agree) |> pivot_wider(names_from = metric, values_from = agree)
paired <- purrr::map_dfr(METRIC_PAIRS, function(mp) {
  a1 <- wide_agree[[mp[1]]]; a2 <- wide_agree[[mp[2]]]
  b <- sum(a1 & !a2); c <- sum(!a1 & a2)            # discordant counts
  diff_ci <- boot_ratio_ci(W, psum(a2, wide_agree$pid) - psum(a1, wide_agree$pid),
                           psum(rep(1, nrow(wide_agree)), wide_agree$pid))
  tibble::tibble(comparison = paste0(METRIC_LABELS[mp[2]], " minus ", METRIC_LABELS[mp[1]]),
                 diff = mean(a2) - mean(a1), low = diff_ci["low"], high = diff_ci["high"],
                 only_first_agrees = b, only_second_agrees = c, p_mcnemar_exact = if (b + c > 0) binom.test(b, b + c)$p.value else 1)
}) |>
  mutate(p_holm = p.adjust(p_mcnemar_exact, "holm"))
save_table(paired, "rq2_metric_comparisons")
for (i in seq_len(nrow(paired))) {
  r <- paired[i, ]
  record(paste0("agreement difference: ", r$comparison), r$diff, r$low, r$high, n = 750,
         test = "exact McNemar (independence assumed), Holm across 6 comparisons; CI participant bootstrap",
         p = r$p_holm, section = "RQ2")
}
# Mixed-effects logistic regression: agreement ~ metric, crossed random intercepts for
# participant and pair (handles both kinds of clustering). Supplementary.
glmm <- tryCatch(lme4::glmer(agree ~ metric_label + (1 | pid) + (1 | item), data = scored, family = binomial,
                             control = lme4::glmerControl(optimizer = "bobyqa")), error = function(e) NULL)
if (!is.null(glmm)) {
  co <- summary(glmm)$coefficients
  glmm_tbl <- tibble::tibble(term = rownames(co), estimate = co[, 1], se = co[, 2], p = co[, 4]) |>
    mutate(odds_ratio = exp(estimate), or_low = exp(estimate - 1.96 * se), or_high = exp(estimate + 1.96 * se))
  save_table(glmm_tbl, "rq2_mixed_model")
  writeLines(capture.output(print(summary(glmm))), file.path(data_dir("rq2_mixed_model_summary"), "rq2_mixed_model_summary.txt"))
  for (i in which(glmm_tbl$term != "(Intercept)")) {
    r <- glmm_tbl[i, ]
    record(paste0("mixed model odds ratio vs CC: ", sub("metric_label", "", r$term)), r$odds_ratio, r$or_low, r$or_high,
           n = nrow(scored), test = "glmer agree ~ metric + (1|participant) + (1|pair), Wald CI", p = r$p, section = "RQ2",
           note = "supplementary")
  }
} else record("mixed model", NA, note = "model did not converge; not reported", section = "RQ2")

# ---- e. Agreement by tie status and side of the lower measurement ------------------------
# predicted = sign(value_A - value_B): -1 = A has the lower measurement (left), +1 = B has it (right)
STATUS_LEVELS <- c("Lower measurement on the left (A)", "Measurements equal", "Lower measurement on the right (B)")
scored <- scored |>
  mutate(status = factor(c(STATUS_LEVELS[1], STATUS_LEVELS[2], STATUS_LEVELS[3])[predicted + 2], levels = STATUS_LEVELS))
status_tbl <- scored |>
  group_by(metric_label, status) |>
  group_modify(function(d, k) {
    ci <- boot_mean_ci(d$agree, d$pid)
    tibble::tibble(n = nrow(d), n_agree = sum(d$agree), agree = mean(d$agree), low = ci["low"], high = ci["high"],
                   pairs = n_distinct(d$item))
  }) |>
  ungroup()
validate("tie-status groups partition the 750 responses for every metric",
         all(status_tbl |> group_by(metric_label) |> summarise(s = sum(n)) |> pull(s) == 750))
save_table(status_tbl, "rq2_agreement_by_tie_status_and_side")
for (i in seq_len(nrow(status_tbl))) {
  r <- status_tbl[i, ]
  record(paste0(r$metric_label, " agreement: ", r$status), r$agree, r$low, r$high, n = r$n_agree, denominator = r$n,
         test = "participant cluster bootstrap 95% CI", section = "RQ2: tie status",
         note = paste(r$pairs, "distinct pairs"))
}

# ---- f. Measurement gap vs strength of preference ---------------------------------------
gap_tests <- purrr::map_dfr(METRICS, function(m) {
  d <- scored |> filter(metric == m)
  kw <- kruskal.test(gap ~ strength, data = d)
  jt <- DescTools::JonckheereTerpstraTest(d$gap, d$strength, alternative = "increasing", exact = FALSE)
  s <- as.numeric(d$strength) - 1
  rho <- suppressWarnings(cor(d$gap, s, method = "spearman"))
  rows <- split(seq_len(nrow(d)), factor(d$pid, levels = pids))
  set.seed(SEED)
  boot_rho <- replicate(GAP_BOOT, {
    idx <- unlist(rows[sample.int(P, P, replace = TRUE)], use.names = FALSE)
    suppressWarnings(cor(d$gap[idx], s[idx], method = "spearman"))
  })
  q <- quantile(boot_rho, c(0.025, 0.975), na.rm = TRUE)
  med <- tapply(d$gap, d$strength, median)
  cnt <- table(d$strength)
  tibble::tibble(metric = METRIC_LABELS[m], n_none = cnt[[1]], n_slightly = cnt[[2]], n_much = cnt[[3]],
                 median_none = med[[1]], median_slightly = med[[2]], median_much = med[[3]],
                 kw_stat = unname(kw$statistic), p_kw = kw$p.value, p_jt = jt$p.value,
                 rho = rho, rho_low = q[[1]], rho_high = q[[2]])
}) |>
  mutate(p_kw_holm = p.adjust(p_kw, "holm"), p_jt_holm = p.adjust(p_jt, "holm"))
save_table(gap_tests, "rq2_gap_vs_strength")
for (i in seq_len(nrow(gap_tests))) {
  r <- gap_tests[i, ]
  record(paste0(r$metric, ": Spearman, |measurement gap| vs strength of preference"), r$rho, r$rho_low, r$rho_high,
         n = 750, test = "Spearman; CI participant bootstrap (2,000 resamples); p = Jonckheere-Terpstra (increasing), Holm across 4",
         p = r$p_jt_holm, section = "RQ2",
         note = "gaps are in each metric's own units, so slopes are not comparable across metrics")
  record(paste0(r$metric, ": Kruskal-Wallis |gap| across strength groups"), r$kw_stat, n = 750,
         test = "Kruskal-Wallis, Holm across 4", p = r$p_kw_holm, section = "RQ2")
}

# ---- g. Pair-level relationship ----------------------------------------------------------
# Sign convention (the same for every metric): x = value_A - value_B, so positive means B has
# the lower measurement; y = mean rating - 3, so positive means B was judged less complex.
# A positive correlation therefore means the metric tracks the participants.
pair_level <- scored |>
  group_by(item, method_a_id, method_b_id, metric, metric_label) |>
  summarise(n = n(), mean_rating = mean(rating), diff_a_minus_b = first(value_a - value_b), .groups = "drop") |>
  mutate(perceived_b_less_complex = mean_rating - 3)
pair_cor <- pair_level |>
  group_by(metric, metric_label) |>
  group_modify(function(d, k) {
    ct <- suppressWarnings(cor.test(d$diff_a_minus_b, d$perceived_b_less_complex, method = "spearman", exact = FALSE))
    tibble::tibble(rho = unname(ct$estimate), p = ct$p.value, pairs = nrow(d))
  }) |>
  ungroup() |>
  mutate(p_holm = p.adjust(p, "holm")) |>
  arrange(metric_label)
save_table(pair_level, "rq2_pair_level_data")
save_table(pair_cor, "rq2_pair_level_spearman")
for (i in seq_len(nrow(pair_cor))) {
  r <- pair_cor[i, ]
  record(paste0(r$metric_label, ": pair-level Spearman, measurement difference vs perceived difference"), r$rho,
         n = r$pairs, test = "Spearman over 44 pairs (each counted once), Holm across 4", p = r$p_holm, section = "RQ2")
}

# ---- h. Pairs where every key metric ties ----------------------------------------------------
all_tie_items <- scored |> group_by(item) |> summarise(all_tie = all(predicted == 0), .groups = "drop") |>
  filter(all_tie) |> pull(item)
all_tie <- responses |>
  filter(item %in% all_tie_items) |>
  group_by(item, method_a_id, method_b_id) |>
  summarise(n = n(), chose_A = sum(human == -1), no_difference = sum(human == 0), chose_B = sum(human == 1), .groups = "drop") |>
  mutate(prop_no_difference = no_difference / n, prop_preference = (chose_A + chose_B) / n,
         p_binom = purrr::map2_dbl(chose_B, chose_A + chose_B, ~ if (.y > 0) binom.test(.x, .y)$p.value else NA_real_))
save_table(all_tie, "rq2_all_metrics_tie_pairs")
pooled <- all_tie |> summarise(n = sum(n), A = sum(chose_A), B = sum(chose_B), none = sum(no_difference))
bt <- binom.test(pooled$B, pooled$A + pooled$B)
record("pairs where all four key metrics tie", nrow(all_tie), section = "RQ2: all-tie pairs", note = paste(all_tie_items, collapse = ", "))
record("all-tie pairs: responses", pooled$n, section = "RQ2: all-tie pairs")
record("all-tie pairs: share saying No difference", pooled$none / pooled$n, n = pooled$none, denominator = pooled$n, section = "RQ2: all-tie pairs")
record("all-tie pairs: share expressing a preference", (pooled$A + pooled$B) / pooled$n, n = pooled$A + pooled$B, denominator = pooled$n,
       section = "RQ2: all-tie pairs")
record("all-tie pairs: decisive responses choosing the later version (B) as less complex", pooled$B / (pooled$A + pooled$B),
       bt$conf.int[1], bt$conf.int[2], n = pooled$B, denominator = pooled$A + pooled$B,
       test = "exact binomial vs 50% (independence assumed)", p = bt$p.value, section = "RQ2: all-tie pairs",
       note = "B is always the later version, so this mixes comment/naming effects with position")

# ---- i. Position diagnostics -----------------------------------------------------------------------
# Method A was always the earlier version and task order was fixed (not counterbalanced). These
# checks look for evidence that position affected the results; they cannot prove its absence.
pos_lean <- function(d, label) {
  dec <- d |> filter(human != 0)
  nA <- dec$human == -1; nB <- dec$human == 1
  ci_diff <- boot_ratio_ci(W, psum(nB, dec$pid) - psum(nA, dec$pid), psum(rep(1, nrow(dec)), dec$pid))
  ci_B <- boot_ratio_ci(W, psum(nB, dec$pid), psum(rep(1, nrow(dec)), dec$pid))
  bt <- binom.test(sum(nB), nrow(dec))
  tibble::tibble(subset = label, pairs = n_distinct(d$item), responses = nrow(d), chose_A = sum(nA), chose_B = sum(nB),
                 no_difference = sum(d$human == 0), prop_A = mean(nA[nA | nB]), prop_B = mean(nB[nA | nB]),
                 diff_B_minus_A = mean(nB[nA | nB]) - mean(nA[nA | nB]), diff_low = ci_diff["low"], diff_high = ci_diff["high"],
                 propB_low = ci_B["low"], propB_high = ci_B["high"], p_binom = bt$p.value)
}
position <- bind_rows(
  pos_lean(responses, "All 44 pairs"),
  pos_lean(responses |> filter(vv_pair), "Pairs without the original (V vs V)"),
  pos_lean(responses |> filter(!vv_pair), "Original (A) vs refactor (B) pairs"))
validate("position: V-vs-V comparisons cover 20 pairs", position$pairs[2] == 20, position$pairs[2])
validate("position: A + B + no-difference counts sum to the responses",
         all(position$chose_A + position$chose_B + position$no_difference == position$responses))
save_table(position, "position_lean")
for (i in seq_len(nrow(position))) {
  r <- position[i, ]
  record(paste0("position: share of decisive responses choosing B (right), ", r$subset), r$prop_B, r$propB_low, r$propB_high,
         n = r$chose_B, denominator = r$chose_A + r$chose_B, test = "participant cluster bootstrap 95% CI", section = "Design diagnostic: position",
         note = paste0("No difference reported separately: ", r$no_difference))
  record(paste0("position: B minus A share of decisive responses, ", r$subset), r$diff_B_minus_A, r$diff_low, r$diff_high,
         n = r$chose_A + r$chose_B, test = "participant cluster bootstrap 95% CI; exact binomial p (independence assumed)",
         p = r$p_binom, section = "Design diagnostic: position")
}

# ---- j. Direction accuracy on a common subset ------------------------------------------------------------
# Direction accuracy normally uses a different set of responses for each metric (the ones where that metric
# separates the pair), so the four numbers are not on the same footing. Here: only pairs that ALL FOUR key
# metrics separate, and only responses where the participant took a side. Every metric is then judged on
# exactly the same responses, and none can tie.
sep_items <- scored |> group_by(item) |> summarise(all_sep = all(predicted != 0), .groups = "drop") |>
  filter(all_sep) |> pull(item)
common <- scored |> filter(item %in% sep_items, human != 0)
cw <- common |> select(pid, item, metric_label, agree) |>
  pivot_wider(names_from = metric_label, values_from = agree)
validate("common subset: every metric is judged on the same responses and none tie",
         nrow(cw) > 0 && nrow(cw) * 4 == nrow(common) && all(common$predicted != 0),
         sprintf("%d pairs, %d decisive responses", length(sep_items), nrow(cw)))
den_cw <- psum(rep(1, nrow(cw)), cw$pid)
common_tbl <- purrr::map_dfr(levels(scored$metric_label), function(m) {
  ci <- boot_ratio_ci(W, psum(cw[[m]], cw$pid), den_cw)
  bt <- binom.test(sum(cw[[m]]), nrow(cw))
  tibble::tibble(metric = m, pairs = length(sep_items), decisive_responses = nrow(cw), n_correct = sum(cw[[m]]),
                 direction_accuracy = mean(cw[[m]]), low = ci[["low"]], high = ci[["high"]], p_binom = bt$p.value)
}) |> mutate(p_binom_holm = p.adjust(p_binom, "holm"))
save_table(common_tbl, "rq2_direction_common_subset")
for (i in seq_len(nrow(common_tbl))) {
  r <- common_tbl[i, ]
  record(paste0(r$metric, ": direction accuracy, common subset (all four metrics separate the pair)"), r$direction_accuracy,
         r$low, r$high, n = r$n_correct, denominator = r$decisive_responses,
         test = "participant cluster bootstrap 95% CI; exact binomial vs 50% (independence assumed), Holm across 4",
         p = r$p_binom_holm, section = "RQ2: common subset",
         note = sprintf("%d pairs where CC, CogC, LOC and MaxNest all separate the pair; decisive responses only", r$pairs))
}
common_diff <- purrr::map_dfr(c("CogC", "LOC", "MaxNest"), function(m) {
  ci <- boot_ratio_ci(W, psum(cw[[m]] - cw$CC, cw$pid), den_cw)
  tibble::tibble(comparison = paste0(m, " minus CC"), difference = mean(cw[[m]]) - mean(cw$CC), low = ci[["low"]], high = ci[["high"]])
})
save_table(common_diff, "rq2_direction_common_subset_differences")
for (i in seq_len(nrow(common_diff)))
  record(paste0("direction accuracy difference, common subset: ", common_diff$comparison[i]), common_diff$difference[i],
         common_diff$low[i], common_diff$high[i], n = nrow(cw), test = "participant cluster bootstrap 95% CI",
         section = "RQ2: common subset")

# ---- k. Participant consistency per pair: a ceiling for agreement, and the metrics on clear pairs ------------
# If participants disagree among themselves on a pair, no metric can agree with all of them. Two ceilings,
# both over the 750 responses with the same three-way answer as the metric comparison (A / No difference / B):
#  - in-sample consensus: predict every response with its pair's most common answer (optimistic: each response
#    helps choose its own pair's prediction)
#  - leave-one-out consensus: predict each response with the most common answer among the OTHER responses to the
#    same pair (ties share the credit equally)
# A "clear" pair is one where at least CLEAR_SHARE of the participants who took a side chose the same side, with at
# least CLEAR_MIN_DECISIVE of them.
CLEAR_SHARE <- 0.75; CLEAR_MIN_DECISIVE <- 10
pair_ids <- sort(unique(responses$item))
cat_of <- responses$human + 2L                                    # 1 = A less complex, 2 = no difference, 3 = B less complex
col_of <- (match(responses$item, pair_ids) - 1L) * 3L + cat_of
M <- matrix(0, nrow = P, ncol = length(pair_ids) * 3L)            # participant x (pair, answer) indicator
M[cbind(match(responses$pid, pids), col_of)] <- 1
consensus <- function(counts) {                                    # counts: boot x pair x 3 array
  mx <- apply(counts, c(1, 2), max)
  insample <- apply(mx, 1, sum) / apply(counts, 1, sum)
  loo <- 0
  for (cc_ in 1:3) {
    others <- counts; others[, , cc_] <- others[, , cc_] - 1
    omax <- apply(others, c(1, 2), max)
    is_top <- (others == array(omax, dim(others))) * 1
    credit <- is_top[, , cc_] / apply(is_top, c(1, 2), sum)
    loo <- loo + apply(counts[, , cc_] * credit, 1, sum)
  }
  cbind(insample = insample, loo = loo / apply(counts, 1, sum))
}
to_array <- function(flat) array(flat, c(nrow(flat), 3, length(pair_ids))) |> aperm(c(1, 3, 2))
obs <- consensus(to_array(matrix(colSums(M), nrow = 1)))
bootc <- consensus(to_array(W %*% M))
ceil_tbl <- tibble::tibble(
  ceiling = c("In-sample consensus (optimistic)", "Leave-one-out consensus"),
  agreement = c(obs[1, "insample"], obs[1, "loo"]),
  low = c(quantile(bootc[, "insample"], 0.025), quantile(bootc[, "loo"], 0.025)),
  high = c(quantile(bootc[, "insample"], 0.975), quantile(bootc[, "loo"], 0.975)))
save_table(ceil_tbl, "rq2_consensus_ceiling")
for (i in seq_len(nrow(ceil_tbl)))
  record(paste0("agreement ceiling: ", ceil_tbl$ceiling[i]), ceil_tbl$agreement[i], ceil_tbl$low[i], ceil_tbl$high[i],
         n = 750, test = "participant cluster bootstrap 95% CI (pairs re-derived in each resample)", section = "RQ2: consensus",
         note = "best agreement any rule that assigns one answer per pair could reach with these responses")
validate("consensus ceiling is at least as high as the best metric", ceil_tbl$agreement[2] >= 0 && ceil_tbl$agreement[1] >= max(agreement$agree_all) - 1e-9,
         sprintf("in-sample %.3f, leave-one-out %.3f, best metric %.3f", ceil_tbl$agreement[1], ceil_tbl$agreement[2], max(agreement$agree_all)))

pair_consistency <- responses |>
  group_by(item, method_a_id, method_b_id) |>
  summarise(n = n(), chose_A = sum(human == -1), no_difference = sum(human == 0), chose_B = sum(human == 1), .groups = "drop") |>
  mutate(decisive = chose_A + chose_B,
         majority_side = ifelse(chose_A >= chose_B, -1L, 1L),
         majority_share = pmax(chose_A, chose_B) / decisive,
         clear = decisive >= CLEAR_MIN_DECISIVE & majority_share >= CLEAR_SHARE)
save_table(pair_consistency, "rq2_pair_consistency")
clear_pairs <- pair_consistency |> filter(clear)
record("pairs with a clear majority side", nrow(clear_pairs), denominator = nrow(pair_consistency), section = "RQ2: consensus",
       note = sprintf(">= %.0f%% of participants who took a side chose the same side, with >= %d of them", 100 * CLEAR_SHARE, CLEAR_MIN_DECISIVE))
record("pairs: median share of decisive responses on the majority side", median(pair_consistency$majority_share[pair_consistency$decisive > 0]),
       n = sum(pair_consistency$decisive > 0), section = "RQ2: consensus")
clear_metrics <- scored |>
  distinct(item, metric_label, predicted) |>
  inner_join(clear_pairs |> select(item, majority_side, majority_share, decisive), by = "item") |>
  mutate(state = factor(ifelse(predicted == 0, "Metric ties", ifelse(predicted == majority_side, "Metric agrees with the majority", "Metric points the other way")),
                        levels = c("Metric agrees with the majority", "Metric points the other way", "Metric ties")))
clear_summary <- clear_metrics |> count(metric_label, state, .drop = FALSE) |>
  group_by(metric_label) |> mutate(pairs = sum(n), share = n / pairs) |> ungroup()
save_table(clear_summary, "rq2_clear_pairs_metric_calls")
for (i in seq_len(nrow(clear_summary)))
  record(paste0(clear_summary$metric_label[i], " on clear pairs: ", clear_summary$state[i]), clear_summary$share[i],
         n = clear_summary$n[i], denominator = clear_summary$pairs[i], section = "RQ2: consensus",
         note = sprintf("pair level: each of the %d clear pairs counted once", nrow(clear_pairs)))

# Does the 75% / 10-response choice matter? The same clear-pair count and metric calls at other thresholds.
clear_grid <- purrr::map_dfr(c(0.70, 0.75, 0.80), function(sh) purrr::map_dfr(c(8, 10, 12), function(md) {
  cp <- pair_consistency |> filter(decisive >= md, majority_share >= sh)
  scored |> distinct(item, metric_label, predicted) |>
    inner_join(cp |> select(item, majority_side), by = "item") |>
    mutate(state = factor(ifelse(predicted == 0, "Metric ties",
                                 ifelse(predicted == majority_side, "Metric agrees with the majority", "Metric points the other way")),
                          levels = levels(clear_metrics$state))) |>
    count(metric_label, state, .drop = FALSE) |>
    mutate(share_threshold = sh, min_decisive = md, clear_pairs = nrow(cp))
}))
save_table(clear_grid, "rq2_clear_pairs_threshold_sensitivity")
n_clear_main <- nrow(clear_pairs)
cc_ties_main <- clear_summary$n[clear_summary$metric_label == "CC" & clear_summary$state == "Metric ties"]
g_main <- clear_grid |> filter(share_threshold == 0.75, min_decisive == 10)
validate("clear-pair sensitivity grid reproduces the main result at 75% / 10",
         unique(g_main$clear_pairs) == n_clear_main && g_main$n[g_main$metric_label == "CC" & g_main$state == "Metric ties"] == cc_ties_main,
         sprintf("%d clear pairs; CC ties on %d", n_clear_main, cc_ties_main))
for (sh in c(0.70, 0.75, 0.80)) for (md in c(8, 10, 12)) {
  g <- clear_grid |> filter(share_threshold == sh, min_decisive == md)
  lab <- sprintf("clear pairs at >= %.0f%% on one side, >= %d decisive responses", 100 * sh, md)
  record(paste0("number of ", lab), unique(g$clear_pairs), denominator = nrow(pair_consistency), section = "RQ2: consensus")
  for (mm in c("CC", "CogC"))
    record(paste0(mm, " ties on the ", lab), g$n[g$metric_label == mm & g$state == "Metric ties"],
           denominator = unique(g$clear_pairs), section = "RQ2: consensus", note = "pair level")
}

saveRDS(scored, file.path(PATHS$work, "scored_rq2.rds"))
saveRDS(list(agreement = agreement, kappa = kappa_tbl, decomp = decomp, decisive_break = decisive_break, direction = direction, paired = paired,
             status = status_tbl, gap_tests = gap_tests, pair_level = pair_level, pair_cor = pair_cor,
             all_tie = all_tie, position = position, common = common_tbl, ceiling = ceil_tbl, clear = clear_summary),
        file.path(PATHS$work, "rq2_results.rds"))
save_numbers("05_rq2_agreement")
save_validation("05_rq2_agreement")
