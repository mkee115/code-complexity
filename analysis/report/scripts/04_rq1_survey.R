# =============================================================================
# 04_rq1_survey.R  (RQ1, survey side: do the metrics measure the same thing?)
#
# a. Pairwise concordance between metrics over the 44 compared pairs
# b. Resolution: how often each metric ties (pairs and responses), distinct values
# c. PCA over the 34 snippets (key metrics and broader set)
# d. Spearman correlations over the 34 snippets
#
# The 34 snippets were deliberately constructed; none of this describes a random
# sample of Java methods.
# =============================================================================

source("scripts/00_setup.R")
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
