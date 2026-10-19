# =============================================================================
# 12c_ordinal_models.R  (RQ2: ordinal models of the 1-5 ratings)
#
# a. Cumulative-link mixed model of the rating on the signed, rank-scaled measurement differences of CC, CogC,
#    LOC and MaxNest, with random intercepts for participant and pair. Coefficients with Wald 95% CIs and
#    likelihood-ratio tests for dropping each metric; does CogC add anything beyond LOC, and LOC beyond CogC?
# b. Within-task ordinal Bradley-Terry model: a latent perceived-complexity score for every snippet
#    (the original of each task = 0), and the within-task Spearman correlation of each metric with the scores.
# Needs the 'ordinal' package.
# =============================================================================

source("scripts/00_setup.R")
suppressPackageStartupMessages(library(ggrepel))
# 'ordinal' is called as ordinal::... and not attached: attaching it masks dplyr::slice(), which later scripts use
stopifnot(requireNamespace("ordinal", quietly = TRUE))
responses <- readRDS(file.path(PATHS$work, "responses.rds"))
participants <- readRDS(file.path(PATHS$work, "participants.rds"))
snip <- read_csv(PATHS$snippets, show_col_types = FALSE)
dat <- responses |> mutate(rating_f = factor(rating, levels = 1:5, ordered = TRUE), pid = factor(pid), item = factor(item))
validate("ordinal models: 750 responses with ratings 1-5", nrow(dat) == 750 && all(dat$rating %in% 1:5))

# ---- a. Cumulative-link mixed model -----------------------------------------------------------------------
# Rank-scale each metric across the 34 snippets to 0-1 (average ranks for ties); the predictor is the rank of
# Method A minus the rank of Method B, so a positive coefficient means "A measured higher -> B judged less complex"
# (the direction the ratings run: 5 = B much less complex).
rank01 <- function(x) (rank(x, ties.method = "average") - 1) / (length(x) - 1)
for (m in METRICS) {
  r <- setNames(rank01(snip[[m]]), snip$id)
  dat[[paste0("d_", m)]] <- unname(r[dat$method_a_id] - r[dat$method_b_id])
}
D <- paste0("d_", METRICS)
fit_clmm <- function(terms) ordinal::clmm(reformulate(c(terms, "(1 | pid)", "(1 | item)"), response = "rating_f"), data = dat, link = "logit", Hess = TRUE, nAGQ = 1)
full <- fit_clmm(D)
validate("cumulative-link mixed model converged (largest gradient below 0.01)", max(abs(full$gradient)) < 0.01, sprintf("%.2e", max(abs(full$gradient))))
cf <- summary(full)$coefficients
beta <- cf[D, , drop = FALSE]
coef_tbl <- tibble::tibble(metric = METRIC_LABELS[METRICS], term = D, estimate = beta[, "Estimate"], se = beta[, "Std. Error"],
                           low = estimate - 1.96 * se, high = estimate + 1.96 * se, p_wald = beta[, "Pr(>|z|)"])
# Likelihood-ratio test of a reduced model against a fuller one, from the log-likelihoods
lrt <- function(reduced, fuller) {
  stat <- 2 * (as.numeric(logLik(fuller)) - as.numeric(logLik(reduced)))
  df <- length(coef(fuller)) - length(coef(reduced))
  list(stat = stat, df = df, p = pchisq(stat, df, lower.tail = FALSE))
}
drop_one <- purrr::map_dfr(seq_along(D), function(i) {
  a <- lrt(fit_clmm(D[-i]), full)
  tibble::tibble(term = D[i], lr_chisq = a$stat, df = a$df, p_lrt = a$p)
})
validate("likelihood-ratio tests each drop exactly one parameter", all(drop_one$df == 1) && all(drop_one$lr_chisq > -1e-6))
coef_tbl <- coef_tbl |> left_join(drop_one, by = "term") |> mutate(p_lrt_holm = p.adjust(p_lrt, "holm"))
save_table(coef_tbl, "rq2_clmm_coefficients")
cor_d <- cor(as.data.frame(dat[, D]))
max_cor <- max(abs(cor_d[upper.tri(cor_d)]))
record("cumulative-link mixed model: largest correlation between two predictors", max_cor, n = 750, section = "RQ2: ordinal model",
       note = "rank-scaled signed differences; strong collinearity makes the individual coefficients imprecise")
for (i in seq_len(nrow(coef_tbl))) {
  r <- coef_tbl[i, ]
  record(paste0("cumulative-link mixed model: ", r$metric, " coefficient (log-odds per full-range rank difference)"), r$estimate, r$low, r$high,
         n = 750, test = "clmm, Wald 95% CI; random intercepts for participant and pair", p = r$p_wald, section = "RQ2: ordinal model")
  record(paste0("cumulative-link mixed model: likelihood-ratio test for dropping ", r$metric), r$lr_chisq, n = 750, test = "likelihood-ratio chi-squared, 1 df; p Holm across 4",
         p = r$p_lrt_holm, section = "RQ2: ordinal model", note = sprintf("unadjusted p = %.4f", r$p_lrt))
}
# CogC and LOC head to head (the two highest-agreeing metrics)
m_loc <- fit_clmm("d_loc"); m_cogc <- fit_clmm("d_cognitive"); m_both <- fit_clmm(c("d_cognitive", "d_loc"))
a_cogc_beyond_loc <- lrt(m_loc, m_both); a_loc_beyond_cogc <- lrt(m_cogc, m_both)
h2h <- tibble::tibble(question = c("CogC added to a model with LOC", "LOC added to a model with CogC"),
                      lr_chisq = c(a_cogc_beyond_loc$stat, a_loc_beyond_cogc$stat),
                      p = c(a_cogc_beyond_loc$p, a_loc_beyond_cogc$p),
                      aic_without = c(AIC(m_loc), AIC(m_cogc)), aic_with = c(AIC(m_both), AIC(m_both)))
save_table(h2h, "rq2_clmm_cogc_vs_loc")
for (i in 1:2)
  record(paste0("cumulative-link mixed model: ", h2h$question[i], ", likelihood-ratio test"), h2h$lr_chisq[i], n = 750, test = "likelihood-ratio chi-squared, 1 df",
         p = h2h$p[i], section = "RQ2: ordinal model", note = sprintf("AIC %.1f without, %.1f with", h2h$aic_without[i], h2h$aic_with[i]))
record("cumulative-link mixed model: pair variance (random intercept)", as.numeric(ordinal::VarCorr(full)$item), n = 44, section = "RQ2: ordinal model")
record("cumulative-link mixed model: participant variance (random intercept)", as.numeric(ordinal::VarCorr(full)$pid), n = 75, section = "RQ2: ordinal model")

p_coef <- ggplot(coef_tbl |> mutate(metric = factor(metric, levels = rev(unname(METRIC_LABELS)))), aes(estimate, metric, colour = metric)) +
  geom_vline(xintercept = 0, linetype = "dashed", colour = "#777777", linewidth = 0.4) +
  geom_errorbar(aes(xmin = low, xmax = high), width = 0.18, orientation = "y", linewidth = 0.7) +
  geom_point(size = 3) +
  scale_colour_manual(values = METRIC_COLOURS, guide = "none") +
  labs(x = "Coefficient (log-odds of a higher rating per full-range rank difference, 95% CI)", y = NULL) +
  theme_report() + theme(panel.grid.major.y = element_blank())
save_fig(p_coef, "diag_rq2_ordinal_coefficients", height_cm = 6, rq = "RQ2",
         purpose = "Coefficients of CC, CogC, LOC and MaxNest in the cumulative-link mixed model of the 1-5 ratings (all four entered together)")

# ---- b. Within-task ordinal Bradley-Terry model -------------------------------------------------------------
snip_t <-snip |> transmute(id, task = group, variant, across(all_of(METRICS)))
nonref <- snip_t |> filter(variant != "ORIG") |> pull(id)
safe <- function(id) paste0("s_", gsub("-", "_", id))
for (s in nonref) dat[[safe(s)]] <- ifelse(dat$method_a_id == s, 1, ifelse(dat$method_b_id == s, -1, 0))
bt_fit <- ordinal::clmm(reformulate(c(safe(nonref), "(1 | pid)"), response = "rating_f"), data = dat, link = "logit", Hess = TRUE)
validate("Bradley-Terry model converged (largest gradient below 0.01)", max(abs(bt_fit$gradient)) < 0.01, sprintf("%.2e", max(abs(bt_fit$gradient))))
bcf <- summary(bt_fit)$coefficients
bt <- snip_t |> mutate(theta = 0, se = NA_real_)          # originals stay at 0 with no interval
for (i in which(bt$variant != "ORIG")) { bt$theta[i] <- bcf[safe(bt$id[i]), "Estimate"]; bt$se[i] <- bcf[safe(bt$id[i]), "Std. Error"] }
bt <- bt |> mutate(low = theta - 1.96 * se, high = theta + 1.96 * se)
validate("Bradley-Terry: 34 snippets, one reference (original = 0) per task", nrow(bt) == 34 && sum(bt$variant == "ORIG") == 10 && all(bt$theta[bt$variant == "ORIG"] == 0))
save_table(bt |> select(id, task, variant, theta, se, low, high), "rq2_bradley_terry_scores")
for (i in which(bt$variant != "ORIG"))
  record(paste0("latent perceived complexity, ", bt$id[i], " (original of the task = 0; higher = judged more complex)"), bt$theta[i], bt$low[i], bt$high[i],
         n = sum(dat$method_a_id == bt$id[i] | dat$method_b_id == bt$id[i]), test = "ordinal Bradley-Terry (clmm, random intercept for participant), Wald 95% CI",
         section = "RQ2: Bradley-Terry")

bt_plot <- bt |> mutate(task_f = factor(sprintf("Task %d", task), levels = sprintf("Task %d", sort(unique(task)))),
                        kind = ifelse(variant == "ORIG", "Original (fixed at 0)", "Variant")) |>
  group_by(task) |> mutate(id_f = factor(id, levels = rev(sort(id)))) |> ungroup()
p_bt <- ggplot(bt_plot, aes(theta, id_f, colour = kind)) +
  geom_vline(xintercept = 0, linetype = "dashed", colour = "#999999", linewidth = 0.3) +
  geom_errorbar(aes(xmin = low, xmax = high), width = 0.25, orientation = "y", linewidth = 0.45, na.rm = TRUE) +
  geom_point(size = 2) +
  facet_wrap(~ task_f, ncol = 2, scales = "free_y") +
  scale_colour_manual(values = c(`Original (fixed at 0)` = ORIG_COLOUR, Variant = REFACTOR_COLOUR), name = NULL) +
  labs(x = "Latent perceived complexity (log-odds scale; original of each task = 0; higher = judged more complex)", y = NULL) +
  theme_report(base_size = 8.5) + theme(strip.text = element_text(face = "bold"), panel.grid.major.y = element_blank())
save_fig(p_bt, "diag_rq2_bradley_terry", height_cm = 15, rq = "RQ2",
         purpose = "Latent perceived complexity of each snippet from the within-task ordinal Bradley-Terry model (95% Wald intervals)")

# Within-task Spearman between each metric and the latent scores: both are centred on their task mean first,
# so only differences between snippets of the same task count; the 95% interval resamples whole tasks.
# (The scores are treated as known; their own uncertainty is in the intervals plotted above.)
centre <- function(x, g) x - ave(x, g)
within_rho <- function(d, metric) { z <- suppressWarnings(cor(centre(d$theta, d$task), centre(d[[metric]], d$task), method = "spearman")); z }
tasks_u <- sort(unique(bt$task))
by_task <- split(bt, bt$task)
set.seed(SEED)
rho_tbl <- purrr::map_dfr(METRICS, function(m) {
  est <- within_rho(bt, m)
  b <- vapply(seq_len(N_BOOT), function(i) {
    pick <- sample(tasks_u, length(tasks_u), replace = TRUE)
    d <- bind_rows(lapply(seq_along(pick), function(k) transform(by_task[[as.character(pick[k])]], task = k)))
    within_rho(d, m)
  }, numeric(1))
  q <- quantile(b, c(0.025, 0.975), na.rm = TRUE)
  tibble::tibble(metric = METRIC_LABELS[m], rho = est, low = q[[1]], high = q[[2]], n_snippets = nrow(bt), valid_resamples = sum(!is.na(b)))
})
save_table(rho_tbl, "rq2_bradley_terry_within_task_spearman")
for (i in seq_len(nrow(rho_tbl)))
  record(paste0("within-task Spearman, latent complexity vs ", rho_tbl$metric[i]), rho_tbl$rho[i], rho_tbl$low[i], rho_tbl$high[i], n = rho_tbl$n_snippets[i],
         test = "Spearman on task-centred values; task cluster bootstrap 95% CI (10,000)", section = "RQ2: Bradley-Terry",
         note = sprintf("%d of %d resamples defined", rho_tbl$valid_resamples[i], N_BOOT))

save_figure_registry("12c_ordinal_models")
save_numbers("12c_ordinal_models")
save_validation("12c_ordinal_models")
cat("Ordinal models done\n")
