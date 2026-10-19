# =============================================================================
# 02_analysis.R
# The analyses: RQ1 (do the metrics agree?), RQ2 (agreement with programmers), RQ3 (refactoring) and sensitivity checks.
#
# Each section runs in its own local() block, so its variables do not leak into the
# next one. Intermediate results pass between sections as files in output/_pipeline/.
# =============================================================================

source("scripts/00_setup.R")

# -----------------------------------------------------------------------------
# SECTION 03_rq1_corpus
#
# a. Spearman correlations: key metrics (full main corpus) and a broader set of
#    metrics (1,000,000-method random sample, fixed seed)
# b. CC vs LOC: Spearman and the partial association controlling for CogC, MaxNest
# c. PCA: key metrics (full corpus) and broader metrics (sample)
# d. Pairwise concordance on a random sample of method pairs
# e. Resolution: distinct values and tie rates
#
# Spearman is the primary correlation (heavily skewed measurements). With millions
# of methods any p-value is effectively zero, so coefficients are reported as
# effect sizes and p-values are not used.
# -----------------------------------------------------------------------------
local({
  d <- readRDS(file.path(PATHS$work, "corpus_key.rds"))
  meta <- readRDS(file.path(PATHS$work, "corpus_meta.rds"))
  prov <- if (meta$complete) "" else " (PROVISIONAL: harvest still running)"
  m <- d[main == TRUE]
  n_main <- nrow(m)
  X <- as.matrix(m[, ..METRICS])
  colnames(X) <- METRIC_LABELS[METRICS]

  BROAD <- c("cc", "cognitive_complexity", "loc", "loc_physical", "avg_nesting", "max_nesting",
             "avg_id_words", "abbreviated_ratio", "single_letter_ids", "longest_id", "total_words",
             "comment_count", "comment_words", "halstead_volume", "halstead_difficulty",
             "halstead_effort", "param_count", "return_count", "fan_out", "max_line_length",
             "avg_line_length")
  BROAD_LABELS <- c(cc = "CC", cognitive_complexity = "CogC", loc = "LOC", loc_physical = "Physical LOC",
                    avg_nesting = "Avg nesting", max_nesting = "MaxNest", avg_id_words = "Avg id words",
                    abbreviated_ratio = "Abbrev. ratio", single_letter_ids = "Single-letter ids",
                    longest_id = "Longest id", total_words = "Total words", comment_count = "Comments",
                    comment_words = "Comment words", halstead_volume = "Halstead vol.",
                    halstead_difficulty = "Halstead diff.", halstead_effort = "Halstead effort",
                    param_count = "Parameters", return_count = "Returns", fan_out = "Fan-out",
                    max_line_length = "Max line length", avg_line_length = "Avg line length")

  # ---- a. Spearman correlations -------------------------------------------------------
  ranks <- apply(X, 2, frank, ties.method = "average")
  rho <- cor(ranks)
  validate("Spearman matrix is symmetric with a unit diagonal", isTRUE(all.equal(rho, t(rho))) && all(abs(diag(rho) - 1) < 1e-9))
  corr_key <- as_tibble(rho, rownames = "metric")
  save_table(corr_key, "rq1_corpus_spearman_key")
  for (mp in METRIC_PAIRS) {
    a <- METRIC_LABELS[mp[1]]; b <- METRIC_LABELS[mp[2]]
    record(paste0("corpus Spearman: ", a, " – ", b), rho[a, b], n = n_main, test = "Spearman rho (effect size; p-values uninformative at this n)",
           section = "RQ1: corpus", subset = "main corpus", note = paste0(prov))
  }

  # Tie rates among methods with CC >= 3 (so not the straight-line methods that dominate the corpus).
  # Exact over all pairs of distinct methods, not sampled: for a metric, P(tie) = sum n_v (n_v - 1) / (n (n - 1))
  # over its values v. "Only X ties" = X ties and the other metric separates the pair.
  m3 <- m[cc >= 3]
  n3 <- nrow(m3)
  pair_tie <- function(counts) sum(counts * (counts - 1)) / (n3 * (n3 - 1))
  p3_cc <- pair_tie(m3[, .N, by = cc]$N)
  p3_cogc <- pair_tie(m3[, .N, by = cognitive]$N)
  p3_both <- pair_tie(m3[, .N, by = .(cc, cognitive)]$N)
  p3_loc <- pair_tie(m3[, .N, by = loc]$N)
  p3_max <- pair_tie(m3[, .N, by = max_nesting]$N)
  tie3 <- tibble::tibble(
    quantity = c("CC ties", "CogC ties", "LOC ties", "MaxNest ties", "Both CC and CogC tie",
                 "Only CC ties (CogC separates)", "Only CogC ties (CC separates)"),
    probability = c(p3_cc, p3_cogc, p3_loc, p3_max, p3_both, p3_cc - p3_both, p3_cogc - p3_both))
  save_table(tie3, "rq1_corpus_tie_rates_cc_ge3")
  for (i in seq_len(nrow(tie3)))
    record(paste0("corpus, CC >= 3: probability two methods tie: ", tie3$quantity[i]), tie3$probability[i], n = n3,
           test = "exact over all pairs of distinct methods", section = "RQ1: corpus", subset = "main corpus, CC >= 3",
           note = prov)
  # Where the 34 survey snippets sit among real methods: the mid-rank percentile of each snippet's measurement
  # in the main corpus (share of corpus methods below it, plus half the share equal to it, because so many
  # corpus methods share the lowest values).
  snippets <- read_csv(PATHS$snippets, show_col_types = FALSE)
  mid_pct <- function(v, x) 100 * (sum(x < v) + 0.5 * sum(x == v)) / length(x)
  snip_pct <- snippets |> select(id, all_of(METRICS)) |>
    rowwise() |>
    mutate(across(all_of(METRICS), ~ mid_pct(.x, m[[cur_column()]]), .names = "pct_{.col}")) |>
    ungroup()
  validate("snippet percentiles cover 34 snippets and lie between 0 and 100",
           nrow(snip_pct) == 34 && all(snip_pct |> select(starts_with("pct_")) >= 0, na.rm = FALSE) &&
             all(snip_pct |> select(starts_with("pct_")) <= 100))
  save_table(snip_pct, "rq1_snippet_percentiles_in_corpus")
  for (k in METRICS) {
    v <- snip_pct[[paste0("pct_", k)]]
    record(paste0(METRIC_LABELS[k], ": median corpus percentile of the 34 survey snippets"), median(v), ci_low = min(v), ci_high = max(v),
           n = length(v), section = "RQ1: corpus", subset = "main corpus",
           note = "mid-rank percentile of each snippet's measurement among main-corpus methods; interval = range over the snippets")
    record(paste0(METRIC_LABELS[k], ": survey snippets above the corpus 90th percentile"), mean(v > 90), n = sum(v > 90),
           denominator = length(v), section = "RQ1: corpus", subset = "main corpus")
  }
  record("corpus, CC >= 3: ratio of 'only CC ties' to 'only CogC ties'", (p3_cc - p3_both) / (p3_cogc - p3_both), n = n3,
         test = "exact over all pairs of distinct methods", section = "RQ1: corpus", subset = "main corpus, CC >= 3", note = prov)

  # The same correlations using only methods above the lowest value of both metrics
  rho_above <- spearman_above_lowest(X)
  save_table(rho_above, "rq1_corpus_spearman_above_lowest")
  for (k in seq_len(nrow(rho_above))) if (rho_above$metric_1[k] < rho_above$metric_2[k]) {
    r <- rho_above[k, ]
    record(paste0("corpus Spearman without the lowest values: ", r$metric_1, " – ", r$metric_2), r$rho, n = r$n,
           test = "Spearman rho on methods above the lowest value of both metrics", section = "RQ1: corpus",
           subset = "main corpus, both metrics above their lowest value", note = prov)
  }

  # Within-repository Spearman: does the pattern hold inside individual repositories?
  pair_names <- c("CC – CogC", "CC – LOC", "CogC – LOC", "CC – MaxNest", "CogC – MaxNest", "LOC – MaxNest")
  within_repo <- m[, if (.N >= 200) {
    r <- suppressWarnings(cor(.SD, method = "spearman")); as.list(setNames(r[upper.tri(r)], pair_names))
  }, by = repo, .SDcols = METRICS]
  within_summary <- purrr::map_dfr(pair_names, function(p) {
    v <- within_repo[[p]]; v <- v[!is.na(v)]
    tibble::tibble(metric_pair = p, repositories = length(v), median_rho = median(v),
                   q25 = unname(quantile(v, 0.25)), q75 = unname(quantile(v, 0.75)))
  })
  save_table(within_summary, "rq1_corpus_spearman_within_repository")
  for (i in seq_len(nrow(within_summary)))
    record(paste0("within-repository median Spearman: ", within_summary$metric_pair[i]), within_summary$median_rho[i],
           within_summary$q25[i], within_summary$q75[i], n = within_summary$repositories[i],
           test = "median across repositories with >= 200 methods; interval = IQR", section = "RQ1: corpus")

  # Broader set of metrics on a fixed-seed random sample of main-corpus methods
  set.seed(SEED)
  sample_rows <- sort(sample(m$row_id, min(1e6, n_main)))
  broad <- suppressWarnings(fread(file.path(PATHS$corpus_dir, "cc_data.csv"), select = BROAD,
                                  nrows = meta$n_raw, showProgress = FALSE))[sample_rows]
  validate("broad metric sample has the expected size and no missing values",
           nrow(broad) == length(sample_rows) && !anyNA(broad), nrow(broad))
  rho_sample_key <- cor(broad[, c("cc", "cognitive_complexity", "loc", "max_nesting")], method = "spearman")
  validate("sample Spearman for the 4 key metrics is within 0.01 of the full corpus",
           max(abs(rho_sample_key - rho)) < 0.01, sprintf("max difference %.4f", max(abs(rho_sample_key - rho))))
  rho_broad <- cor(broad, method = "spearman")
  dimnames(rho_broad) <- list(BROAD_LABELS[BROAD], BROAD_LABELS[BROAD])
  save_table(as_tibble(rho_broad, rownames = "metric"), "rq1_corpus_spearman_broad")
  saveRDS(list(key = rho, key_above = rho_above, broad = rho_broad, n_sample = nrow(broad)), file.path(PATHS$work, "rq1_corpus_corr.rds"))

  # ---- b. CC and LOC: Spearman and partial association ---------------------------------
  P <- solve(rho)
  partial <- -P / sqrt(outer(diag(P), diag(P)))
  diag(partial) <- 1
  save_table(as_tibble(partial, rownames = "metric"), "rq1_corpus_partial_spearman")
  record("corpus Spearman CC – LOC", rho["CC", "LOC"], n = n_main, test = "Spearman rho", section = "RQ1: corpus")
  record("corpus partial Spearman CC – LOC (controlling for CogC and MaxNest)", partial["CC", "LOC"], n = n_main,
         test = "partial Spearman from the rank correlation matrix", section = "RQ1: corpus")
  for (mp in METRIC_PAIRS) {
    a <- METRIC_LABELS[mp[1]]; b <- METRIC_LABELS[mp[2]]
    record(paste0("corpus partial Spearman: ", a, " – ", b, " (other two held constant)"), partial[a, b],
           n = n_main, test = "partial Spearman", section = "RQ1: corpus")
  }

  # ---- c. PCA ------------------------------------------------------------------------------
  # Transformation: log(1 + x) then standardise. The measurements are counts with very
  # long right tails; the log makes the first components describe typical methods rather
  # than the few extreme ones. The rank-based (Spearman) version is a robustness check.
  pca_from_cor <- function(cm, label) {
    e <- eigen(cm, symmetric = TRUE)
    vec <- e$vectors
    vec <- sweep(vec, 2, ifelse(colSums(vec) < 0, -1, 1), `*`)       # PC1 loads positively
    list(var = tibble::tibble(dataset = label, component = paste0("PC", seq_along(e$values)),
                              variance = e$values / sum(e$values), cumulative = cumsum(e$values / sum(e$values))),
         loadings = vec, vars = rownames(cm))
  }
  logX <- log1p(X)
  pca_key <- pca_from_cor(cor(logX), "Corpus, key metrics (log1p, standardised)")
  pca_key_rank <- pca_from_cor(rho, "Corpus, key metrics (ranks)")
  colnames(pca_key$loadings) <- paste0("PC", 1:4)
  load_key <- as_tibble(pca_key$loadings) |> mutate(metric = pca_key$vars, .before = 1)
  save_table(pca_key$var, "rq1_corpus_pca_key_variance")
  save_table(load_key, "rq1_corpus_pca_key_loadings")
  save_table(pca_key_rank$var, "rq1_corpus_pca_key_variance_rank_check")
  for (i in 1:4) {
    record(paste0("corpus PCA, key metrics: PC", i, " share of variance"), pca_key$var$variance[i], n = n_main,
           test = "PCA on log(1+x), standardised", section = "RQ1: corpus")
    record(paste0("corpus PCA, key metrics (rank check): PC", i, " share of variance"), pca_key_rank$var$variance[i],
           n = n_main, test = "PCA on ranks", section = "RQ1: corpus")
  }
  # Scores for plotting: a fixed-seed sample, projected with the full-corpus centring and scaling
  set.seed(SEED)
  s_idx <- sample.int(n_main, 30000)
  mu <- colMeans(logX); sdv <- apply(logX, 2, sd)
  scores_key <- as_tibble(scale(logX[s_idx, ], mu, sdv) %*% pca_key$loadings[, 1:2], .name_repair = ~ c("PC1", "PC2"))

  # Broader metrics on the sample (zero-variance columns are dropped)
  bx <- log1p(as.matrix(broad))
  bx <- bx[, apply(bx, 2, sd) > 0]
  pca_broad <- prcomp(bx, center = TRUE, scale. = TRUE)
  if (sum(pca_broad$rotation[, 1]) < 0) pca_broad$rotation[, 1] <- -pca_broad$rotation[, 1]
  pb_var <- tibble::tibble(dataset = "Corpus, broader metrics (1M sample, log1p, standardised)",
                           component = paste0("PC", seq_along(pca_broad$sdev)),
                           variance = pca_broad$sdev^2 / sum(pca_broad$sdev^2),
                           cumulative = cumsum(variance))
  pb_load <- as_tibble(pca_broad$rotation[, 1:4], rownames = "metric") |>
    mutate(metric = BROAD_LABELS[metric])
  save_table(pb_var, "rq1_corpus_pca_broad_variance")
  save_table(pb_load, "rq1_corpus_pca_broad_loadings")
  for (i in 1:3)
    record(paste0("corpus PCA, broader metrics: PC", i, " share of variance"), pb_var$variance[i], n = nrow(broad),
           test = "PCA on log(1+x), standardised; 1M random sample", section = "RQ1: corpus")
  saveRDS(list(key_var = pca_key$var, key_load = load_key, key_rank_var = pca_key_rank$var, scores = scores_key,
               broad_var = pb_var, broad_load = pb_load), file.path(PATHS$work, "rq1_corpus_pca.rds"))

  # ---- d. Pairwise concordance on sampled method pairs ----------------------------------------
  N_PAIRS <- 1e6
  concordance_counts <- function(mat, label) {
    pr <- sample_pairs(nrow(mat), N_PAIRS)
    validate(paste0("pair sample (", label, "): no self-pairs and no repeated unordered pair"),
             all(pr$i != pr$j) && !anyDuplicated(as.numeric(pr$i) * (nrow(mat) + 1) + pr$j) && length(pr$i) == N_PAIRS)
    S <- apply(mat, 2, function(x) sign(x[pr$i] - x[pr$j]))
    colnames(S) <- colnames(mat)
    conc <- purrr::map_dfr(METRIC_PAIRS, function(mp) {
      cls <- concordance_class(S[, METRIC_LABELS[mp[1]]], S[, METRIC_LABELS[mp[2]]])
      tibble::tibble(metric_pair = metric_pair_label(mp[1], mp[2]), class = cls)
    }) |>
      count(metric_pair, class, .drop = FALSE) |>
      group_by(metric_pair) |>
      mutate(total = sum(n), prop = n / total) |>
      ungroup()
    ci <- t(mapply(function(x, n) wilson_ci(x, n), conc$n, conc$total))
    conc <- conc |> mutate(ci_low = ci[, "low"], ci_high = ci[, "high"], source = label)
    ties <- tibble::tibble(metric = METRIC_LABELS[METRICS], source = label,
                           pair_tie_rate = colMeans(S == 0))
    list(conc = conc, ties = ties, S = S)
  }
  nontrivial <- m$cc >= 3          # non-trivial = CC >= 3
  Xnt <- X[nontrivial, , drop = FALSE]
  res_all <- concordance_counts(X, "Corpus: random method pairs")
  res_nt <- concordance_counts(Xnt, "Corpus: non-trivial methods (CC ≥ 3)")
  validate("concordance classes sum to the number of sampled pairs",
           all((res_all$conc |> group_by(metric_pair) |> summarise(s = sum(n)))$s == N_PAIRS))
  record("non-trivial methods (CC >= 3): share of main corpus", mean(nontrivial), n = sum(nontrivial),
         denominator = n_main, section = "RQ1: corpus")
  # Whole-pair agreement across all four metrics, on the same 1,000,000 non-trivial pairs as the concordance above.
  # S holds sign(value_i - value_j) per metric (-1, 0, 1). A pair is discordant when two metrics give opposite signs.
  S_nt <- res_nt$S
  has_pos <- function(cols) rowSums(S_nt[, cols, drop = FALSE] > 0) > 0
  has_neg <- function(cols) rowSums(S_nt[, cols, drop = FALSE] < 0) > 0
  has_zero <- function(cols) rowSums(S_nt[, cols, drop = FALSE] == 0) > 0
  all4 <- colnames(S_nt)
  disc4 <- has_pos(all4) & has_neg(all4)
  partly <- !disc4 & has_zero(all4) & (has_pos(all4) | has_neg(all4))
  fully <- !disc4 & !partly
  disc3 <- has_pos(c("CC", "CogC", "MaxNest")) & has_neg(c("CC", "CogC", "MaxNest"))
  validate("four-metric classes (discordant, partly, fully) partition the pairs",
           all(disc4 + partly + fully == 1) && length(disc4) == N_PAIRS)
  validate("four-metric discordance matches the six pairwise results (any discordant pair)",
           sum(disc4) == sum(Reduce(`|`, lapply(METRIC_PAIRS, function(mp)
             S_nt[, METRIC_LABELS[mp[1]]] * S_nt[, METRIC_LABELS[mp[2]]] < 0))))
  all_tie <- rowSums(S_nt == 0) == 4
  four_tbl <- tibble::tibble(
    class = c("Discordant: at least one metric combination orders the pair in opposite directions",
              "Partly agreeing: no combination discordant, but a metric ties while another orders the pair",
              "Fully agreeing: all four order the pair the same way, or all four tie",
              "   of which all four tie",
              "Discordant among CC, CogC and MaxNest only (ignoring LOC)"),
    n = c(sum(disc4), sum(partly), sum(fully), sum(fully & all_tie), sum(disc3)), total = N_PAIRS) |>
    mutate(prop = n / total)
  save_table(four_tbl, "rq1_concordance_corpus_four_metrics_cc_ge3")
  for (i in seq_len(nrow(four_tbl)))
    record(paste0("corpus, CC >= 3 pairs, all four metrics: ", trimws(four_tbl$class[i])), four_tbl$prop[i], n = four_tbl$n[i],
           denominator = N_PAIRS, section = "RQ1: corpus", subset = "1,000,000 random pairs, both CC >= 3",
           note = if (i == 5) "overlaps the first three classes; not part of the partition" else if (i == 4) "subset of fully agreeing" else NA)
  conc_corpus <- bind_rows(res_all$conc, res_nt$conc)
  save_table(conc_corpus, "rq1_concordance_corpus")
  for (i in seq_len(nrow(conc_corpus))) {
    r <- conc_corpus[i, ]
    record(paste0("corpus concordance (", r$source, "): ", r$metric_pair, ": ", r$class), r$prop, r$ci_low, r$ci_high,
           n = r$n, denominator = r$total,
           test = "Wilson 95% CI: reflects random pair sampling only, not how representative the corpus is",
           section = "RQ1: corpus", note = prov)
  }

  # ---- e. Resolution ----------------------------------------------------------------------------
  res_tbl <- purrr::map_dfr(METRICS, function(k) {
    x <- m[[k]]; tab <- sort(table(x), decreasing = TRUE)
    tibble::tibble(metric = METRIC_LABELS[k], distinct_values = length(tab),
                   modal_value = names(tab)[1], share_at_modal_value = as.numeric(tab[1]) / n_main)
  }) |>
    left_join(res_all$ties |> select(metric, pair_tie_rate_random = pair_tie_rate), by = "metric") |>
    left_join(res_nt$ties |> select(metric, pair_tie_rate_nontrivial = pair_tie_rate), by = "metric") |>
    # exact tie chance for two methods that both measure above the metric's lowest possible value
    left_join(purrr::map_dfr(METRICS, function(k) {
      x <- m[[k]]; x <- x[x > min(x)]; p <- as.numeric(table(x)) / length(x)
      tibble::tibble(metric = METRIC_LABELS[k], lowest_value = min(m[[k]]), n_above_lowest = length(x),
                     pair_tie_rate_above_lowest = sum(p^2))
    }), by = "metric")
  save_table(res_tbl, "rq1_corpus_resolution")
  for (i in seq_len(nrow(res_tbl))) {
    r <- res_tbl[i, ]
    record(paste0(r$metric, ": probability two random methods tie"), r$pair_tie_rate_random, n = N_PAIRS,
           section = "RQ1: corpus", subset = "random pairs, main corpus")
    record(paste0(r$metric, ": probability two non-trivial methods tie"), r$pair_tie_rate_nontrivial, n = N_PAIRS,
           section = "RQ1: corpus", subset = "random pairs, non-trivial methods")
    record(paste0(r$metric, ": probability two methods tie when both are above the lowest value (", r$lowest_value, ")"),
           r$pair_tie_rate_above_lowest, n = r$n_above_lowest, section = "RQ1: corpus",
           subset = "main corpus methods above the metric's lowest value; exact, not sampled")
    record(paste0(r$metric, ": share of methods at the most common value (", r$modal_value, ")"), r$share_at_modal_value,
           n = n_main, section = "RQ1: corpus")
  }
  saveRDS(list(conc = conc_corpus, resolution = res_tbl), file.path(PATHS$work, "rq1_corpus_concordance.rds"))

  save_numbers("03_rq1_corpus")
  save_validation("03_rq1_corpus")
  cat("Corpus RQ1 analyses done", prov, "\n")
})

# -----------------------------------------------------------------------------
# SECTION 04_rq1_survey
#
# a. Pairwise concordance between metrics over the 44 compared pairs
# b. Resolution: how often each metric ties (pairs and responses), distinct values
# c. PCA over the 34 snippets (key metrics and broader set)
# d. Spearman correlations over the 34 snippets
#
# The 34 snippets were deliberately constructed; none of this describes a random
# sample of Java methods.
# -----------------------------------------------------------------------------
local({
  responses <- readRDS(file.path(PATHS$work, "responses.rds"))
  snip <- read_csv(PATHS$snippets, show_col_types = FALSE)
  pairs <- read_csv(PATHS$pairs, show_col_types = FALSE)

  # Signed difference (A - B) per pair and metric
  pair_signs <- pairs |>
    select(item, method_a_id, method_b_id) |>
    left_join(snip |> select(id, all_of(METRICS)), by = c("method_a_id" = "id")) |>
    left_join(snip |> select(id, all_of(METRICS)), by = c("method_b_id" = "id"), suffix = c("_a", "_b"))
  for (m in METRICS) pair_signs[[paste0("s_", m)]] <- sign(pair_signs[[paste0(m, "_a")]] - pair_signs[[paste0(m, "_b")]])
  n_pairs <- nrow(pair_signs)
  validate("survey pair table has 44 rows and no missing measurements", n_pairs == 44 && !anyNA(pair_signs))

  # Concordance classifier: hand-checks
  validate("concordance classifier: same sign", concordance_class(1, 1) == "Concordant")
  validate("concordance classifier: opposite sign", concordance_class(1, -1) == "Discordant")
  validate("concordance classifier: one ties", concordance_class(0, -1) == "One ties, other separates")
  validate("concordance classifier: both tie", concordance_class(0, 0) == "Both tie")

  # ---- a. Concordance over the 44 survey pairs ---------------------------------
  concordance_survey <- purrr::map_dfr(METRIC_PAIRS, function(mp) {
    cls <- concordance_class(pair_signs[[paste0("s_", mp[1])]], pair_signs[[paste0("s_", mp[2])]])
    tibble::tibble(metric_pair = metric_pair_label(mp[1], mp[2]), class = cls)
  }) |>
    count(metric_pair, class, .drop = FALSE) |>
    group_by(metric_pair) |>
    mutate(prop = n / sum(n), total = sum(n)) |>
    ungroup()
  ci <- t(mapply(function(x, n) wilson_ci(x, n), concordance_survey$n, concordance_survey$total))
  concordance_survey <- concordance_survey |>
    mutate(ci_low = ci[, "low"], ci_high = ci[, "high"], source = "Survey pairs (n = 44)")
  validate("survey concordance classes sum to 44 for each metric pair", all(tapply(concordance_survey$n, concordance_survey$metric_pair, sum) == 44))
  save_table(concordance_survey, "rq1_concordance_survey")
  for (i in seq_len(nrow(concordance_survey))) {
    r <- concordance_survey[i, ]
    record(paste0("survey concordance: ", r$metric_pair, ": ", r$class), r$prop, r$ci_low, r$ci_high, n = r$n,
           denominator = r$total, test = "Wilson 95% CI over the 44 constructed pairs", section = "RQ1: survey")
  }

  # ---- b. Resolution -------------------------------------------------------------
  resp_ties <- responses |>
    select(item) |>
    left_join(pair_signs |> select(item, starts_with("s_")), by = "item")
  resolution <- purrr::map_dfr(METRICS, function(m) {
    tie_pairs <- sum(pair_signs[[paste0("s_", m)]] == 0)
    tie_resp <- sum(resp_ties[[paste0("s_", m)]] == 0)
    ci_p <- wilson_ci(tie_pairs, n_pairs)
    tibble::tibble(
      metric = METRIC_LABELS[m],
      distinct_values_34_snippets = n_distinct(snip[[m]]),
      range_34_snippets = paste0(min(snip[[m]]), "–", max(snip[[m]])),
      pairs_tied = tie_pairs, pairs_total = n_pairs, prop_pairs_tied = tie_pairs / n_pairs,
      prop_pairs_tied_low = ci_p["low"], prop_pairs_tied_high = ci_p["high"],
      responses_tied = tie_resp, responses_total = nrow(responses), prop_responses_tied = tie_resp / nrow(responses))
  })
  save_table(resolution, "rq1_resolution_survey")
  for (i in seq_len(nrow(resolution))) {
    r <- resolution[i, ]
    record(paste0(r$metric, ": proportion of the 44 survey pairs tied"), r$prop_pairs_tied, r$prop_pairs_tied_low,
           r$prop_pairs_tied_high, n = r$pairs_tied, denominator = n_pairs, test = "Wilson 95% CI", section = "RQ1: survey")
    record(paste0(r$metric, ": proportion of the 750 responses on a tied pair"), r$prop_responses_tied,
           n = r$responses_tied, denominator = nrow(responses), section = "RQ1: survey",
           note = "response-level: a pair seen by many participants counts many times")
    record(paste0(r$metric, ": distinct values across 34 snippets"), r$distinct_values_34_snippets, n = 34,
           section = "RQ1: survey")
  }

  # ---- c. PCA over the 34 snippets ------------------------------------------------
  # Same transformation as the corpus PCA: log(1 + x), then standardise. The raw
  # (untransformed) version is kept as a check.
  pca_one <- function(df, cols, transform = TRUE) {
    x <- as.matrix(df[cols]); if (transform) x <- log1p(x)
    keep <- apply(x, 2, sd) > 0
    p <- prcomp(x[, keep, drop = FALSE], center = TRUE, scale. = TRUE)
    if (sum(p$rotation[, 1]) < 0) { p$rotation[, 1] <- -p$rotation[, 1]; p$x[, 1] <- -p$x[, 1] }
    list(p = p, kept = cols[keep])
  }
  var_tbl <- function(pc, label) tibble::tibble(dataset = label, component = paste0("PC", seq_along(pc$p$sdev)),
                                                 variance = pc$p$sdev^2 / sum(pc$p$sdev^2),
                                                 cumulative = cumsum(variance))
  BROAD_S <- c("cc", "cognitive", "loc", "max_nesting", "avg_nesting", "fan_out", "params", "hal_vol", "hal_eff",
               "avg_id_words", "comment_count")
  BROAD_S_LABELS <- c(cc = "CC", cognitive = "CogC", loc = "LOC", max_nesting = "MaxNest", avg_nesting = "Avg nesting",
                      fan_out = "Fan-out", params = "Parameters", hal_vol = "Halstead vol.", hal_eff = "Halstead effort",
                      avg_id_words = "Avg id words", comment_count = "Comments")
  pc_key <- pca_one(snip, METRICS)
  pc_key_raw <- pca_one(snip, METRICS, transform = FALSE)
  pc_broad <- pca_one(snip, BROAD_S)
  pca_var <- bind_rows(var_tbl(pc_key, "Survey snippets, key metrics (log1p, standardised)"),
                       var_tbl(pc_key_raw, "Survey snippets, key metrics (raw, standardised)"),
                       var_tbl(pc_broad, "Survey snippets, broader metrics (log1p, standardised)"))
  pca_load_key <- as_tibble(pc_key$p$rotation, rownames = "metric") |> mutate(metric = METRIC_LABELS[metric])
  pca_load_broad <- as_tibble(pc_broad$p$rotation[, 1:4], rownames = "metric") |> mutate(metric = BROAD_S_LABELS[metric])
  pca_scores <- tibble::tibble(id = snip$id, PC1 = pc_key$p$x[, 1], PC2 = pc_key$p$x[, 2],
                               task = sprintf("%02d", snip$group), variant = snip$variant)
  save_table(pca_var, "rq1_pca_survey_variance")
  save_table(pca_load_key, "rq1_pca_survey_key_loadings")
  save_table(pca_load_broad, "rq1_pca_survey_broad_loadings")
  save_table(pca_scores, "rq1_pca_survey_key_scores")
  for (i in seq_len(4)) {
    record(paste0("survey PCA, key metrics: PC", i, " share of variance"), var_tbl(pc_key, "")$variance[i], n = 34,
           test = "PCA on log(1+x), standardised", section = "RQ1: survey", note = "34 deliberately constructed snippets")
    record(paste0("survey PCA, key metrics (raw check): PC", i, " share of variance"), var_tbl(pc_key_raw, "")$variance[i],
           n = 34, test = "PCA on raw values, standardised", section = "RQ1: survey")
  }
  for (i in 1:3)
    record(paste0("survey PCA, broader metrics: PC", i, " share of variance"), var_tbl(pc_broad, "")$variance[i], n = 34,
           test = "PCA on log(1+x), standardised", section = "RQ1: survey", note = paste(length(pc_broad$kept), "metrics"))

  # ---- d. Spearman correlations over the 34 snippets ----------------------------------
  sp <- cor(snip[METRICS], method = "spearman")
  dimnames(sp) <- list(METRIC_LABELS[METRICS], METRIC_LABELS[METRICS])
  varying <- BROAD_S[sapply(snip[BROAD_S], sd) > 0]       # a constant column has no rank correlation
  sp_broad <- cor(snip[varying], method = "spearman")
  dimnames(sp_broad) <- list(BROAD_S_LABELS[rownames(sp_broad)], BROAD_S_LABELS[colnames(sp_broad)])
  snip_matrix <- as.matrix(snip[METRICS]); colnames(snip_matrix) <- METRIC_LABELS[METRICS]
  sp_above <- spearman_above_lowest(snip_matrix)
  save_table(sp_above, "rq1_spearman_survey_snippets_above_lowest")
  for (k in seq_len(nrow(sp_above))) if (sp_above$metric_1[k] < sp_above$metric_2[k]) {
    r <- sp_above[k, ]
    record(paste0("survey snippets Spearman without the lowest values: ", r$metric_1, " – ", r$metric_2), r$rho, n = r$n,
           test = "Spearman rho on snippets above the lowest value of both metrics", section = "RQ1: survey")
  }
  save_table(as_tibble(sp, rownames = "metric"), "rq1_spearman_survey_snippets_key")
  save_table(as_tibble(sp_broad, rownames = "metric"), "rq1_spearman_survey_snippets_broad")
  for (mp in METRIC_PAIRS)
    record(paste0("survey snippets Spearman: ", metric_pair_label(mp[1], mp[2])),
           sp[METRIC_LABELS[mp[1]], METRIC_LABELS[mp[2]]], n = 34, test = "Spearman rho", section = "RQ1: survey")

  saveRDS(list(concordance = concordance_survey, resolution = resolution, pca_var = pca_var,
               pca_load_key = pca_load_key, pca_load_broad = pca_load_broad, pca_scores = pca_scores,
               corr_key = sp, corr_key_above = sp_above, corr_broad = sp_broad, pair_signs = pair_signs),
          file.path(PATHS$work, "rq1_survey.rds"))
  save_numbers("04_rq1_survey")
  save_validation("04_rq1_survey")
})

# -----------------------------------------------------------------------------
# SECTION 05_rq2_agreement
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
# -----------------------------------------------------------------------------
local({
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
})

# -----------------------------------------------------------------------------
# SECTION 06_rq2_grids
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
# -----------------------------------------------------------------------------
local({
  participants <- readRDS(file.path(PATHS$work, "participants.rds"))
  scored <- readRDS(file.path(PATHS$work, "scored_rq2.rds"))
  rq2 <- readRDS(file.path(PATHS$work, "rq2_results.rds"))
  pids <- participants$pid
  bh <- boot_helpers(pids)
  W <- bh$W; psum <- bh$psum

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
  save_numbers("06_rq2_grids")
  save_validation("06_rq2_grids")
})

# -----------------------------------------------------------------------------
# SECTION 07_rq3_refactoring
#            perceived complexity?)
#
# a. Win rate per snippet (No difference = half a win), Wilson 95% CIs
# b. Original vs each refactor: exact binomial, Holm across the 24 pairs
# c. Size of measurement reduction vs net preference for the refactor
# d. What kind of change mattered (descriptive, by isolated factor)
# e. Exceptions: 03-V2 (fewer lines, same CC/CogC) and 05-V3 (naming only)
# -----------------------------------------------------------------------------
local({
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
                               any_reduced ~ "Measurement fell and the refactor was preferred",
                               all_unchanged & p_holm < ALPHA ~ "No key measurement changed but preference shifted (significant)",
                               all_unchanged & refactor_preferred ~ "No key measurement changed; leaning towards the refactor",
                               all_unchanged ~ "No key measurement changed; leaning towards the original",
                               refactor_preferred ~ "No measurement fell (some rose); leaning towards the refactor",
                               TRUE ~ "No measurement fell (some rose); the original was preferred")) |>
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
  save_numbers("07_rq3_refactoring")
  save_validation("07_rq3_refactoring")
})

# -----------------------------------------------------------------------------
# SECTION 08_sensitivity
#
# 9.1 Excluding participants who failed screening questions (C, 2, 24)
# 9.2 Decisive responses only (structurally penalises metrics that tie)
# 9.3 Excluding metric-tied comparisons (and No difference responses)
# 9.4 Self-reported programming experience (original categories)
# 9.5 Corpus filtering choices
# -----------------------------------------------------------------------------
local({
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
})
