# =============================================================================
# 04b_rq2_grids.R  (RQ2: the six 3x3 metric-comparison grids)
#
# For each of the six pairs of key metrics, every response is placed in a 3x3
# grid by how each metric rates Method B relative to Method A:
#   "B lower"   B has the lower measurement (the metric says B is less complex)
#   "Equal"     the metric ties
#   "B higher"  B has the higher measurement
# Columns follow metric 1 and rows follow metric 2, both ordered B lower, Equal,
# B higher, so the top-left cell is "B lower under both metrics", the centre is
# "both tie" and the bottom-right is "B higher under both".
#
# Per cell: distinct pairs, responses, how participants answered, and agreement:
#   - same prediction  -> the shared agreement
#   - different        -> agrees with metric 1 only / metric 2 only / neither
# Then exact binomial tests for the cells where the metrics disagree.
# =============================================================================

source("scripts/00_setup.R")
participants <- readRDS(file.path(PATHS$work, "participants.rds"))
scored <- readRDS(file.path(PATHS$work, "scored_rq2.rds"))
rq2 <- readRDS(file.path(PATHS$work, "rq2_results.rds"))
W <- rq2$W
pids <- participants$pid
psum <- function(x, pid) participant_sum(x, pid, pids)

CAT_LEVELS <- c("B lower", "Equal", "B higher")
cat_of <- function(s) factor(c("B higher", "Equal", "B lower")[s + 2], levels = CAT_LEVELS)   # s = sign(A - B)
validate("grid categories: A higher than B means B lower", cat_of(1) == "B lower" && cat_of(-1) == "B higher" && cat_of(0) == "Equal")

wide <- scored |>
  select(pid, item, human, metric, predicted) |>
  pivot_wider(names_from = metric, values_from = predicted)
validate("grid input has 750 responses", nrow(wide) == 750)

cell_type <- function(c1, c2) {
  dplyr::case_when(c1 == "Equal" & c2 == "Equal" ~ "Both tie",
                   c1 == "Equal" | c2 == "Equal" ~ "One metric ties",
                   c1 == c2 ~ "Same direction", TRUE ~ "Opposite directions")
}

grid_cells <- purrr::map_dfr(METRIC_PAIRS, function(mp) {
  s1 <- wide[[mp[1]]]; s2 <- wide[[mp[2]]]
  d <- wide |> mutate(s1 = s1, s2 = s2, col = cat_of(s1), row = cat_of(s2))
  cells <- d |>
    group_by(col, row) |>
    summarise(pairs = n_distinct(item), n = n(), chose_A = sum(human == -1), no_difference = sum(human == 0),
              chose_B = sum(human == 1),
              shared_agree = sum(human == s1 & s1 == s2),
              only_m1 = sum(human == s1 & s1 != s2), only_m2 = sum(human == s2 & s1 != s2),
              .groups = "drop") |>
    tidyr::complete(col, row, fill = list(pairs = 0L, n = 0L, chose_A = 0L, no_difference = 0L, chose_B = 0L,
                                          shared_agree = 0L, only_m1 = 0L, only_m2 = 0L)) |>
    mutate(metric_1 = METRIC_LABELS[mp[1]], metric_2 = METRIC_LABELS[mp[2]],
           type = cell_type(col, row),
           same_prediction = as.character(col) == as.character(row),
           neither = ifelse(same_prediction, NA_integer_, n - only_m1 - only_m2))
  validate(paste0("grid ", METRIC_LABELS[mp[1]], " vs ", METRIC_LABELS[mp[2]], ": cells sum to 750 responses and 44 pairs"),
           sum(cells$n) == 750 && sum(cells$pairs) == 44 &&
             sum(cells$chose_A + cells$no_difference + cells$chose_B) == 750)
  # Each metric's total agreement must be recoverable from the cells:
  # shared agreement (both agree) + agreement with that metric only
  a1 <- rq2$agreement$n_agree[rq2$agreement$metric == mp[1]]
  a2 <- rq2$agreement$n_agree[rq2$agreement$metric == mp[2]]
  validate(paste0("grid ", METRIC_LABELS[mp[1]], " vs ", METRIC_LABELS[mp[2]], ": cell agreement counts add up to each metric's overall agreement"),
           sum(cells$shared_agree) + sum(cells$only_m1) == a1 && sum(cells$shared_agree) + sum(cells$only_m2) == a2,
           sprintf("%d / %d vs %d / %d", sum(cells$shared_agree) + sum(cells$only_m1), sum(cells$shared_agree) + sum(cells$only_m2), a1, a2))
  cells
})
save_table(grid_cells |> mutate(col = as.character(col), row = as.character(row)), "rq2_grid_cells")

# ---- Tests in the cells where the metrics disagree ------------------------------------
# (a) Opposite directions: responses favouring metric 1's side vs metric 2's side (No difference excluded)
# (b) One metric ties, the other separates: how often the separating metric picks the participant's side
grid_tests <- purrr::map_dfr(METRIC_PAIRS, function(mp) {
  s1 <- wide[[mp[1]]]; s2 <- wide[[mp[2]]]
  d <- wide |> mutate(s1 = s1, s2 = s2)
  l1 <- METRIC_LABELS[mp[1]]; l2 <- METRIC_LABELS[mp[2]]
  one_test <- function(rows, side_stat, label, favours) {
    k <- sum(side_stat[rows]); dec <- rows & d$human != 0; n <- sum(dec)
    bt <- if (n > 0) binom.test(sum(side_stat[dec]), n) else NULL
    ci <- if (n > 0) boot_ratio_ci(W, psum(side_stat & dec, d$pid), psum(dec, d$pid)) else c(low = NA, high = NA)
    tibble::tibble(metric_pair = paste(l1, "vs", l2), group = label, favours = favours,
                   pairs = n_distinct(d$item[rows]), responses = sum(rows), decisive = n,
                   favouring = if (n > 0) sum(side_stat[dec]) else 0L, no_difference = sum(rows & d$human == 0),
                   prop = if (n > 0) sum(side_stat[dec]) / n else NA_real_, low = ci[["low"]], high = ci[["high"]],
                   p = if (n > 0) bt$p.value else NA_real_)
  }
  opp <- d$s1 != 0 & d$s2 != 0 & d$s1 != d$s2
  bind_rows(
    one_test(opp, d$human == d$s2, paste0(l1, " and ", l2, " point in opposite directions"), paste0(l2, "'s side")),
    one_test(d$s1 == 0 & d$s2 != 0, d$human == d$s2, paste0(l1, " ties, ", l2, " separates"), paste0(l2, "'s side")),
    one_test(d$s2 == 0 & d$s1 != 0, d$human == d$s1, paste0(l2, " ties, ", l1, " separates"), paste0(l1, "'s side")))
}) |>
  mutate(p_holm = p.adjust(p, "holm"))
save_table(grid_tests, "rq2_grid_tests")
for (i in seq_len(nrow(grid_tests))) {
  r <- grid_tests[i, ]
  record(paste0("grid: ", r$metric_pair, ": ", r$group, ": share of decisive responses on ", r$favours), r$prop, r$low, r$high,
         n = r$favouring, denominator = r$decisive,
         test = "exact binomial vs 50% (independence assumed), Holm across the tests; CI participant bootstrap",
         p = r$p_holm, section = "RQ2: grids",
         note = sprintf("%d distinct pairs, %d responses (%d No difference excluded)", r$pairs, r$responses, r$no_difference))
}
cc_cogc <- grid_tests |> filter(metric_pair == "CC vs CogC")
record("CC vs CogC: distinct pairs where they point in opposite directions", cc_cogc$pairs[1], section = "RQ2: grids",
       note = if (cc_cogc$pairs[1] == 0) "none: the survey design contains no such pair, so the strongest test of which metric is closer to perception cannot be run" else "")
saveRDS(list(cells = grid_cells, tests = grid_tests), file.path(PATHS$work, "rq2_grids.rds"))
print(grid_tests |> select(metric_pair, group, pairs, decisive, favouring, prop, p_holm), n = Inf)
print(grid_cells |> filter(metric_1 == "CC", metric_2 == "CogC") |> select(col, row, pairs, n, chose_A, no_difference, chose_B, shared_agree, only_m1, only_m2, neither))
save_numbers("04b_rq2_grids")
save_validation("04b_rq2_grids")
