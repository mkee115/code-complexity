# =============================================================================
# lib/stats.R
# Statistical helpers shared by the analysis scripts: participant-level cluster
# bootstrap, Wilson intervals, number formatting, pairwise concordance and
# random pair sampling.
# =============================================================================

# ---- Participant-level cluster bootstrap -------------------------------------
# Responses from one participant are not independent, so CIs resample whole
# participants. boot_weights() gives an N_BOOT x P matrix of how many times each
# participant appears in each resample; any ratio of per-participant sums can
# then be bootstrapped with one matrix multiplication.
boot_weights <- function(n_participants, n_boot = N_BOOT, seed = SEED) {
  set.seed(seed)
  idx <- matrix(sample.int(n_participants, n_participants * n_boot, replace = TRUE), nrow = n_boot)
  t(apply(idx, 1, tabulate, nbins = n_participants))
}

# Per-participant sum of x (participants with no rows in the subset contribute 0)
participant_sum <- function(x, pid, pids) {
  s <- tapply(as.numeric(x), factor(pid, levels = pids), sum)
  s[is.na(s)] <- 0
  as.vector(s)
}

# Bundle of bootstrap helpers for the survey scripts: the resampling weights, per-participant
# sums, and the bootstrap CI of a mean. Every script calls this with the same seed, so all
# scripts resample the participants identically.
boot_helpers <- function(pids) {
  W <- boot_weights(length(pids))
  psum <- function(x, pid) participant_sum(x, pid, pids)
  list(W = W, psum = psum,
       mean_ci = function(x, pid) boot_ratio_ci(W, psum(x, pid), psum(rep(1, length(x)), pid)))
}

# Percentile CI of a ratio of sums: numerator / denominator per participant
boot_ratio_ci <- function(W, num, den, level = 0.95) {
  est <- as.vector((W %*% num) / (W %*% den))
  q <- quantile(est, c((1 - level) / 2, 1 - (1 - level) / 2), na.rm = TRUE)
  c(low = unname(q[1]), high = unname(q[2]))
}

# Wilson score interval for a proportion (x may be fractional when a
# "No difference" counts as half a win)
wilson_ci <- function(x, n, level = 0.95) {
  z <- qnorm(1 - (1 - level) / 2)
  p <- x / n
  centre <- (p + z^2 / (2 * n)) / (1 + z^2 / n)
  half <- z * sqrt(p * (1 - p) / n + z^2 / (4 * n^2)) / (1 + z^2 / n)
  c(low = centre - half, high = centre + half)
}

pct <- function(x, digits = 0) sprintf(paste0("%.", digits, "f%%"), 100 * x)
fmt_p <- function(p) ifelse(is.na(p), "", ifelse(p < 0.001, "< .001", sub("^0", "", sprintf("%.3f", p))))
fmt_ci <- function(est, lo, hi, digits = 1) sprintf(paste0("%.", digits, "f%% (%.", digits, "f–%.", digits, "f)"),
                                                      100 * est, 100 * lo, 100 * hi)

# ---- RQ1: pairwise concordance between two metrics ---------------------------
# For one pair of methods, two metrics are concordant if they order the methods
# the same way, discordant if they order them oppositely; otherwise one metric
# separates the methods while the other ties (a resolution difference), or both
# tie. s1, s2 are sign(value_a - value_b) under each metric.
CONCORDANCE_LEVELS <- c("Concordant", "One ties, other separates", "Both tie", "Discordant")
CONCORDANCE_COLOURS <- c("Concordant" = "#2166AC", "One ties, other separates" = "#EF8A62",
                         "Both tie" = "#BDBDBD", "Discordant" = "#B2182B")
concordance_class <- function(s1, s2) {
  out <- ifelse(s1 == 0 & s2 == 0, "Both tie",
         ifelse(s1 == 0 | s2 == 0, "One ties, other separates",
         ifelse(s1 == s2, "Concordant", "Discordant")))
  factor(out, levels = CONCORDANCE_LEVELS)
}
METRIC_PAIRS <- utils::combn(METRICS, 2, simplify = FALSE)
metric_pair_label <- function(m1, m2) paste(METRIC_LABELS[m1], METRIC_LABELS[m2], sep = " – ")

# ---- Random pairs of methods -------------------------------------------------
# k distinct unordered pairs of different rows out of n (sampled with replacement, then
# self-pairs and repeated pairs are dropped), reproducible from the seed.
sample_pairs <- function(n, k, seed = SEED) {
  set.seed(seed)
  over <- ceiling(k * 1.02) + 1000
  i <- sample.int(n, over, replace = TRUE); j <- sample.int(n, over, replace = TRUE)
  ok <- i != j
  lo <- pmin(i, j)[ok]; hi <- pmax(i, j)[ok]
  key <- as.numeric(lo) * (n + 1) + as.numeric(hi)       # unordered-pair key, so no pair repeats
  first <- !duplicated(key)
  stopifnot(sum(first) >= k)
  list(i = lo[first][seq_len(k)], j = hi[first][seq_len(k)])
}

# ---- Spearman correlation without the lowest values ---------------------------
# For every pair of columns, the Spearman correlation using only the rows where BOTH
# metrics are above their own lowest value (CC 1, CogC 0, LOC 1, MaxNest 0), so the
# many trivial rows that tie at the floor cannot inflate the agreement.
# The diagonal gives the number of rows above the lowest value of that one metric.
spearman_above_lowest <- function(M) {
  lowest <- apply(M, 2, min)
  grid <- expand.grid(i = seq_len(ncol(M)), j = seq_len(ncol(M)))
  purrr::pmap_dfr(grid, function(i, j) {
    keep <- M[, i] > lowest[i] & M[, j] > lowest[j]
    tibble::tibble(metric_1 = colnames(M)[i], metric_2 = colnames(M)[j], n = sum(keep),
                   rho = if (i == j) 1 else if (sum(keep) >= 3) cor(frank(M[keep, i]), frank(M[keep, j])) else NA_real_)
  })
}
