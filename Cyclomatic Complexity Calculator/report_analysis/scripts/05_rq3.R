# =============================================================================
# 05_rq3.R  (RQ3: does reducing measurements through refactoring reduce
#            perceived complexity?)
#
# a. Win rate per snippet (No difference = half a win), Wilson 95% CIs
# b. Original vs each refactor: exact binomial, Holm across the 24 pairs
# c. Size of measurement reduction vs net preference for the refactor
# d. What kind of change mattered (descriptive, by isolated factor)
# e. Exceptions: 03-V2 (fewer lines, same CC/CogC) and 05-V3 (naming only)
# =============================================================================

source("scripts/00_setup.R")
participants <- readRDS(file.path(PATHS$work, "participants.rds"))
responses <- readRDS(file.path(PATHS$work, "responses.rds"))
snip <- read_csv(PATHS$snippets, show_col_types = FALSE)
catalogue <- read_csv(PATHS$catalogue, show_col_types = FALSE)

# ---- a. Win rates --------------------------------------------------------------
# Each response gives one result for each side: 1 if judged less complex,
# 0.5 for No difference, 0 otherwise.
side_results <- bind_rows(
  responses |> transmute(pid, item, id = method_a_id, win = c(1, 1, 0.5, 0, 0)[rating]),
  responses |> transmute(pid, item, id = method_b_id, win = c(0, 0, 0.5, 1, 1)[rating])
)
winrate <- side_results |>
  group_by(id) |>
  summarise(n = n(), n_decisive = sum(win != 0.5), no_difference = sum(win == 0.5), wins = sum(win),
            win_rate = wins / n, .groups = "drop") |>
  mutate(low = mapply(function(x, n) wilson_ci(x, n)["low"], wins, n),
         high = mapply(function(x, n) wilson_ci(x, n)["high"], wins, n),
         kind = ifelse(grepl("ORIG$", id), "Original", "Refactored variant")) |>
  arrange(desc(win_rate))
save_table(winrate, "rq3_win_rates")
saveRDS(winrate, file.path(PATHS$work, "rq3_winrate.rds"))

ref <- winrate |> filter(kind == "Refactored variant")
orig <- winrate |> filter(kind == "Original")
record("refactors winning more than half their comparisons", sum(ref$win_rate > 0.5), n = nrow(ref), section = "RQ3")
record("originals winning more than half their comparisons", sum(orig$win_rate > 0.5), n = nrow(orig), section = "RQ3",
       note = paste(orig$id[orig$win_rate > 0.5], collapse = ", "))
record("refactors whose 95% CI lies entirely above 50%", sum(ref$low > 0.5), n = nrow(ref), section = "RQ3")
record("originals whose 95% CI lies entirely below 50%", sum(orig$high < 0.5), n = nrow(orig), section = "RQ3")
validate("win-rate comparisons: every response contributes one result to each of its two snippets", sum(winrate$n) == 2 * nrow(responses))
for (i in seq_len(nrow(winrate))) {
  r <- winrate[i, ]
  record(paste0("win rate: ", r$id), r$win_rate, r$low, r$high, n = r$wins, denominator = r$n,
         test = "Wilson 95% CI (No difference = half a win; responses treated as independent)", section = "RQ3",
         note = sprintf("%d decisive, %d No difference", r$n_decisive, r$no_difference))
}

# ---- b. Original vs each refactor ---------------------------------------------------
# In these pairs the original is always Method A, so human = +1 means the
# refactor (B) was judged less complex.
orig_pairs <- responses |>
  filter(method_a == "ORIG") |>
  group_by(item, method_a_id, method_b_id) |>
  summarise(n = n(), prefer_refactor = sum(human == 1), prefer_original = sum(human == -1),
            no_difference = sum(human == 0), net_preference = mean(rating - 3), .groups = "drop") |>
  mutate(decisive = prefer_refactor + prefer_original,
         share_prefer_refactor = prefer_refactor / decisive,
         ci_low = mapply(function(x, n) wilson_ci(x, n)[["low"]], prefer_refactor, decisive),
         ci_high = mapply(function(x, n) wilson_ci(x, n)[["high"]], prefer_refactor, decisive),
         p = purrr::map2_dbl(prefer_refactor, decisive, ~ if (.y > 0) binom.test(.x, .y)$p.value else NA_real_),
         p_holm = p.adjust(p, "holm"),
         outcome = case_when(p_holm < ALPHA & prefer_refactor > prefer_original ~ "Refactor preferred",
                             p_holm < ALPHA ~ "Original preferred",
                             TRUE ~ "No significant preference"))
save_table(orig_pairs, "rq3_original_vs_refactor")
validate("24 original-vs-refactor pairs, all with the original as Method A", nrow(orig_pairs) == 24 && all(grepl("ORIG", orig_pairs$method_a_id)))
for (i in seq_len(nrow(orig_pairs))) {
  r <- orig_pairs[i, ]
  record(paste0("original vs refactor, share of decisive responses preferring the refactor: ", r$method_b_id),
         r$share_prefer_refactor, r$ci_low, r$ci_high, n = r$prefer_refactor, denominator = r$decisive,
         test = "exact binomial vs 50% (No difference excluded; independence assumed), Holm across 24 pairs; CI Wilson",
         p = r$p_holm, section = "RQ3", note = paste0(r$outcome, "; No difference: ", r$no_difference, "; net preference ", round(r$net_preference, 2)))
}
outcomes <- count(orig_pairs, outcome)
for (i in seq_len(nrow(outcomes)))
  record(paste0("original vs refactor pairs: ", outcomes$outcome[i]), outcomes$n[i], n = nrow(orig_pairs),
         test = "exact binomial per pair (No difference excluded), Holm across pairs", section = "RQ3")

# ---- c. Size of reduction vs size of improvement --------------------------------------
reduction <- orig_pairs |>
  left_join(snip |> select(id, all_of(METRICS)), by = c("method_a_id" = "id")) |>
  left_join(snip |> select(id, all_of(METRICS)), by = c("method_b_id" = "id"), suffix = c("_orig", "_ref"))
for (m in METRICS) reduction[[paste0("red_", m)]] <- reduction[[paste0(m, "_orig")]] - reduction[[paste0(m, "_ref")]]
red_long <- reduction |>
  select(item, method_b_id, n, net_preference, prefer_refactor, prefer_original, starts_with("red_")) |>
  pivot_longer(starts_with("red_"), names_to = "metric", values_to = "reduction") |>
  mutate(metric = sub("^red_", "", metric), metric_label = metric_factor(metric),
         change = factor(case_when(reduction > 0 ~ "Measurement reduced",
                                   reduction == 0 ~ "Unchanged",
                                   TRUE ~ "Measurement increased"),
                         levels = c("Measurement reduced", "Unchanged", "Measurement increased")))
saveRDS(red_long, file.path(PATHS$work, "rq3_reduction.rds"))
save_table(red_long, "rq3_reduction_data")

red_cor <- red_long |>
  group_by(metric, metric_label) |>
  group_modify(function(d, k) {
    ct <- suppressWarnings(cor.test(d$reduction, d$net_preference, method = "spearman", exact = FALSE))
    tibble::tibble(rho = unname(ct$estimate), p = ct$p.value, pairs = nrow(d))
  }) |>
  ungroup() |>
  mutate(p_holm = p.adjust(p, "holm")) |>
  arrange(metric_label)
save_table(red_cor, "rq3_reduction_vs_preference")
for (i in seq_len(nrow(red_cor))) {
  r <- red_cor[i, ]
  record(paste0(r$metric_label, ": Spearman, reduction in measurement vs net preference for refactor"),
         r$rho, n = r$pairs, test = "Spearman over original-vs-refactor pairs, Holm across 4", p = r$p_holm,
         section = "RQ3")
}
by_change <- red_long |>
  group_by(metric_label, change) |>
  summarise(pairs = n(), prefer_refactor = sum(prefer_refactor), prefer_original = sum(prefer_original),
            .groups = "drop") |>
  mutate(share_refactor = prefer_refactor / (prefer_refactor + prefer_original),
         low = mapply(function(x, n) wilson_ci(x, n)["low"], prefer_refactor, prefer_refactor + prefer_original),
         high = mapply(function(x, n) wilson_ci(x, n)["high"], prefer_refactor, prefer_refactor + prefer_original))
save_table(by_change, "rq3_preference_by_change")
for (i in seq_len(nrow(by_change))) {
  r <- by_change[i, ]
  record(paste0(r$metric_label, ", ", r$change, ": share of decisive responses preferring the refactor"),
         r$share_refactor, r$low, r$high, n = r$prefer_refactor + r$prefer_original,
         test = "Wilson 95% CI (responses treated as independent)", section = "RQ3",
         note = paste(r$pairs, "pairs"))
}

# ---- d. What kind of change mattered (descriptive) ---------------------------------------
factor_of <- function(isolating) {
  f <- tolower(trimws(sub("[,.].*$", "", isolating)))
  dplyr::recode(f, "cognitive complexity against cc" = "cognitive vs CC", "comments" = "comment quality",
                "control flow removal" = "control-flow removal",
                "extraction into named helpers" = "extraction",
                "branch count and nesting together" = "branch count and nesting")
}
factor_tbl <- orig_pairs |>
  left_join(catalogue |> select(id, isolating), by = c("method_b_id" = "id")) |>
  mutate(factor = factor_of(isolating)) |>
  group_by(factor) |>
  summarise(variants = paste(method_b_id, collapse = ", "), n_variants = n(),
            responses = sum(n), mean_net_preference = weighted.mean(net_preference, n),
            share_refactor_decisive = sum(prefer_refactor) / sum(prefer_refactor + prefer_original),
            .groups = "drop") |>
  arrange(desc(mean_net_preference))
save_table(factor_tbl, "rq3_factor_summary")

# ---- e. Exceptions ------------------------------------------------------------------------
exceptions <- reduction |>
  mutate(any_reduced = (red_cc > 0) | (red_cognitive > 0) | (red_loc > 0) | (red_max_nesting > 0),
         all_unchanged = red_cc == 0 & red_cognitive == 0 & red_loc == 0 & red_max_nesting == 0,
         refactor_preferred = prefer_refactor > prefer_original,
         pattern = case_when(any_reduced & !refactor_preferred ~ "A measurement fell but the refactor was not preferred",
                             all_unchanged & p_holm < ALPHA ~ "No key measurement changed but preference shifted (significant)",
                             all_unchanged & refactor_preferred ~ "No key measurement changed; leaning towards the refactor",
                             all_unchanged ~ "No key measurement changed; leaning towards the original",
                             TRUE ~ "Measurement fell and the refactor was preferred")) |>
  select(item, original = method_a_id, refactor = method_b_id, red_cc, red_cognitive, red_loc, red_max_nesting,
         prefer_refactor, prefer_original, no_difference, net_preference, p_holm, pattern)
save_table(exceptions, "rq3_pair_patterns")
pattern_counts <- count(exceptions, pattern)
for (i in seq_len(nrow(pattern_counts)))
  record(paste0("original-vs-refactor pairs: ", pattern_counts$pattern[i]), pattern_counts$n[i], n = pattern_counts$n[i], denominator = nrow(exceptions),
         section = "RQ3", note = paste(exceptions$refactor[exceptions$pattern == pattern_counts$pattern[i]], collapse = ", "))

v2 <- winrate |> filter(id == "03-V2")
record("03-V2 win rate", v2$win_rate, v2$low, v2$high, n = v2$n, test = "Wilson 95% CI", section = "RQ3")
ternary <- side_results |>
  filter(id == "03-V2") |>
  left_join(participants |> select(pid, java_q1_correct), by = "pid") |>
  group_by(java_q1_correct) |>
  summarise(n = n(), wins = sum(win), win_rate = wins / n, .groups = "drop")
save_table(ternary, "rq3_03V2_by_ternary_check")
for (i in seq_len(nrow(ternary))) {
  r <- ternary[i, ]
  ci <- wilson_ci(r$wins, r$n)
  record(paste0("03-V2 win rate, ternary screening question ", ifelse(r$java_q1_correct, "correct", "incorrect")),
         r$win_rate, ci["low"], ci["high"], n = r$n, test = "Wilson 95% CI", section = "RQ3")
}
v3 <- orig_pairs |> filter(method_b_id == "05-V3")
record("05-V3 (naming only) vs 05-ORIG: decisive responses preferring the refactor",
       v3$prefer_refactor / (v3$prefer_refactor + v3$prefer_original),
       n = v3$prefer_refactor + v3$prefer_original, p = v3$p, test = "exact binomial", section = "RQ3")

saveRDS(list(winrate = winrate, orig_pairs = orig_pairs, red_long = red_long, red_cor = red_cor, by_change = by_change,
             factor_tbl = factor_tbl, exceptions = exceptions, ternary = ternary), file.path(PATHS$work, "rq3_results.rds"))
save_numbers("05_rq3")
save_validation("05_rq3")
print(winrate, n = Inf); print(orig_pairs |> select(item, method_b_id, n, prefer_refactor, prefer_original, no_difference, p_holm, outcome), n = Inf)
print(red_cor); print(by_change, n = Inf); print(factor_tbl, n = Inf); print(ternary)
