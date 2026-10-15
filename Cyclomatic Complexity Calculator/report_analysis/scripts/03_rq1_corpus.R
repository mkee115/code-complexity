# =============================================================================
# 03_rq1_corpus.R  (RQ1, corpus side: do the metrics measure the same thing?)
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
# =============================================================================

source("scripts/00_setup.R")

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
saveRDS(list(key = rho, broad = rho_broad, n_sample = nrow(broad)), file.path(PATHS$work, "rq1_corpus_corr.rds"))

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
sample_pairs <- function(n, k, seed) {
  set.seed(seed)
  over <- ceiling(k * 1.02) + 1000
  i <- sample.int(n, over, replace = TRUE); j <- sample.int(n, over, replace = TRUE)
  ok <- i != j                                           # a method is never paired with itself
  lo <- pmin(i, j)[ok]; hi <- pmax(i, j)[ok]
  key <- as.numeric(lo) * (n + 1) + as.numeric(hi)       # unordered-pair key, so no pair repeats
  first <- !duplicated(key)
  stopifnot(sum(first) >= k)
  list(i = lo[first][seq_len(k)], j = hi[first][seq_len(k)])
}
N_PAIRS <- 1e6
concordance_counts <- function(mat, label) {
  pr <- sample_pairs(nrow(mat), N_PAIRS, SEED)
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
  list(conc = conc, ties = ties)
}
nontrivial <- (m$loc >= 10) | (m$cc >= 3)
Xnt <- X[nontrivial, , drop = FALSE]
res_all <- concordance_counts(X, "Corpus: random method pairs")
res_nt <- concordance_counts(Xnt, "Corpus: non-trivial methods (LOC ≥ 10 or CC ≥ 3)")
validate("concordance classes sum to the number of sampled pairs",
         all((res_all$conc |> group_by(metric_pair) |> summarise(s = sum(n)))$s == N_PAIRS))
record("non-trivial methods (LOC >= 10 or CC >= 3): share of main corpus", mean(nontrivial), n = sum(nontrivial),
       denominator = n_main, section = "RQ1: corpus")
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

print(rho); print(within_summary); print(partial["CC", "LOC"]); print(pca_key$var); print(pb_var[1:4, ])
print(conc_corpus |> filter(class %in% c("Discordant", "One ties, other separates")) |>
        select(source, metric_pair, class, prop), n = 24)
print(res_tbl)
save_numbers("03_rq1_corpus")
save_validation("03_rq1_corpus")
cat("Corpus RQ1 analyses done", prov, "\n")
