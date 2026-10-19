# =============================================================================
# 12d_forest_and_tie_bars.R  (RQ2: replacements for the CC-vs-CogC grid and the gap-vs-strength box plots)
#
# a. fig08_a: forest plot. For every pair where CC ties and another metric (CogC, MaxNest or LOC) separates it,
#    the share of decisive responses choosing the method that metric rates lower (Wilson 95% CI), with the
#    pooled estimate (participant cluster bootstrap) at the bottom of each panel.
# b. fig10: grouped bars. For each metric, the share of responses where it gives the two methods the same value,
#    split by the participant's answer (no difference / slightly / much), with participant-bootstrap 95% CIs.
# No titles. The bar chart is exported 1568 px wide.
# =============================================================================

source("scripts/00_setup.R")
participants <- readRDS(file.path(PATHS$work, "participants.rds"))
scored <- readRDS(file.path(PATHS$work, "scored_rq2.rds"))
pids <- participants$pid
bh <- boot_helpers(pids)
W <- bh$W; psum <- bh$psum
ratio_ci <- function(pid, num, den) {
  ci <- boot_ratio_ci(W, psum(num & den, pid), psum(den, pid))
  tibble::tibble(est = sum(num & den) / sum(den), low = ci[["low"]], high = ci[["high"]], n_num = sum(num & den), n_den = sum(den))
}

# ---- a. Forest plot: pairs where CC ties ----------------------------------------------------------------------
wide <- scored |> select(pid, item, method_a_id, method_b_id, human, metric, predicted) |> pivot_wider(names_from = metric, values_from = predicted)
PANELS <- c("cognitive", "max_nesting", "loc")
rows <- purrr::map_dfr(PANELS, function(m) {
  d <- wide |> filter(cc == 0, .data[[m]] != 0) |> mutate(side = human == .data[[m]], dec = human != 0)
  per <- d |> group_by(item, method_a_id, method_b_id) |>
    summarise(decisive = sum(dec), k = sum(side & dec), responses = n(), .groups = "drop") |> filter(decisive > 0)
  w <- t(mapply(function(k, n) wilson_ci(k, n), per$k, per$decisive))
  per <- per |> mutate(panel = METRIC_LABELS[m], share = k / decisive, low = w[, 1], high = w[, 2],
                       label = sprintf("%s  %s vs %s", item, method_a_id, method_b_id), pooled = FALSE)
  pool <- ratio_ci(d$pid, d$side, d$dec)
  bind_rows(per, tibble::tibble(item = "Pooled", panel = METRIC_LABELS[m], share = pool$est, low = pool$low, high = pool$high,
                                k = pool$n_num, decisive = pool$n_den, responses = nrow(d), label = "Pooled (participant bootstrap)", pooled = TRUE))
})
validate("forest: every pair where CC ties and the metric separates is shown, with decisive responses",
         all(rows$decisive > 0) && all(rows$share >= 0 & rows$share <= 1), sprintf("%d rows", nrow(rows)))
save_table(rows, "rq2_forest_cc_ties")
for (m in PANELS) {
  r <- rows |> filter(panel == METRIC_LABELS[m], pooled)
  p <- rows |> filter(panel == METRIC_LABELS[m], !pooled)
  record(paste0("CC ties, ", METRIC_LABELS[m], " separates: pooled share of decisive responses choosing the method ", METRIC_LABELS[m], " rates lower"),
         r$share, r$low, r$high, n = r$k, denominator = r$decisive, test = "participant cluster bootstrap 95% CI", section = "RQ2: CC ties",
         note = sprintf("%d pairs; %d of them above 50%%", nrow(p), sum(p$share > 0.5)))
}
panel_levels <- unname(METRIC_LABELS[PANELS])
fp <- rows |>
  mutate(panel = factor(panel, levels = panel_levels)) |>
  group_by(panel) |> arrange(pooled, desc(share), .by_group = TRUE) |> ungroup() |>
  mutate(y = factor(paste(panel, label, sep = "|"), levels = rev(unique(paste(panel, label, sep = "|")))))
p_forest <- ggplot(fp, aes(share, y)) +
  geom_vline(xintercept = 0.5, linetype = "dashed", colour = "#777777", linewidth = 0.4) +
  geom_errorbar(aes(xmin = low, xmax = high, colour = pooled), width = 0.3, orientation = "y", linewidth = 0.5) +
  geom_point(aes(shape = pooled, colour = pooled, size = pooled)) +
  geom_text(aes(x = 1.02, label = sprintf("%d/%d", k, decisive)), hjust = 0, size = 2.5, family = FONT_FAMILY) +
  facet_grid(panel ~ ., scales = "free_y", space = "free_y", labeller = labeller(panel = function(x) paste0(x, " separates")), switch = "y") +
  scale_y_discrete(labels = function(x) sub("^[^|]*\\|", "", x)) +
  scale_colour_manual(values = c(`FALSE` = "#4D4D4D", `TRUE` = "#B2182B"), guide = "none") +
  scale_shape_manual(values = c(`FALSE` = 16, `TRUE` = 18), guide = "none") +
  scale_size_manual(values = c(`FALSE` = 1.8, `TRUE` = 3.6), guide = "none") +
  scale_x_continuous(labels = scales::label_percent(), limits = c(0, 1.12), breaks = seq(0, 1, 0.25), expand = c(0, 0)) +
  labs(x = "Share of decisive responses choosing the method the separating metric rates lower", y = NULL) +
  theme_report(base_size = 8.5) +
  theme(panel.grid.major.y = element_blank(), strip.placement = "outside", strip.text.y.left = element_text(angle = 0, face = "bold", hjust = 1))
save_fig(p_forest, "fig08_a_forest_cc_ties", height_cm = 15, rq = "RQ2",
         purpose = "Pairs where CC ties and CogC, MaxNest or LOC separates: share of decisive responses choosing the method that metric rates lower (Wilson 95% CIs per pair; pooled participant-bootstrap estimate in red)")

# ---- b. Tie rate by the participant's answer ---------------------------------------------------------------------
STRENGTH <- c("No difference", "Slightly", "Much")
strength_n <- scored |> filter(metric == "cc") |> count(strength) |> mutate(lab = sprintf("%s (n = %d)", strength, n))
tie_str <- purrr::map_dfr(names(METRIC_LABELS), function(m) purrr::map_dfr(STRENGTH, function(s) {
  d <- scored |> filter(metric == m)
  r <- ratio_ci(d$pid, d$predicted == 0, d$strength == s)
  tibble::tibble(metric = METRIC_LABELS[m], strength = s, tie_rate = r$est, low = r$low, high = r$high, n_tied = r$n_num, n = r$n_den)
}))
validate("tie rate by strength: the strength groups partition the 750 responses for every metric",
         all(tie_str |> group_by(metric) |> summarise(s = sum(n)) |> pull(s) == 750))
save_table(tie_str, "rq2_tie_rate_by_strength")
for (i in seq_len(nrow(tie_str))) {
  r <- tie_str[i, ]
  record(paste0(r$metric, ": tie rate when the participant answered ", r$strength), r$tie_rate, r$low, r$high, n = r$n_tied, denominator = r$n,
         test = "participant cluster bootstrap 95% CI", section = "RQ2: tie rate by strength")
}
ts <- tie_str |> mutate(metric = factor(metric, levels = unname(METRIC_LABELS)),
                        strength = factor(strength, levels = STRENGTH, labels = strength_n$lab[match(STRENGTH, strength_n$strength)]))
DODGE <- position_dodge(width = 0.8)
p_ties <- ggplot(ts, aes(metric, tie_rate, fill = strength)) +
  geom_col(position = DODGE, width = 0.76) +
  geom_errorbar(aes(ymin = low, ymax = high), position = DODGE, width = 0.25, linewidth = 0.4) +
  geom_text(aes(y = high, label = sprintf("%.0f%%", 100 * tie_rate)), position = DODGE, vjust = -0.5, size = 2.6, family = FONT_FAMILY) +
  scale_fill_manual(values = c("#BDBDBD", "#67A9CF", "#2166AC"), name = "Participant's answer") +
  scale_y_continuous(labels = scales::label_percent(), limits = c(0, 1), breaks = seq(0, 1, 0.25), expand = c(0, 0)) +
  labs(x = NULL, y = "Responses where the metric ties") +
  theme_report(base_size = 9) + theme(panel.grid.major.x = element_blank(), legend.position = "bottom") + guides(fill = guide_legend(nrow = 1))
save_fig(p_ties, "fig10_rq2_tie_rate_by_strength", height_cm = 8.5, width_cm = 1568 / 300 * 2.54, rq = "RQ2",
         purpose = "How often each metric ties on the pair, by the participant's answer (no difference / slightly / much); exported 1568 px wide")

save_figure_registry("12d_forest_and_tie_bars")
save_numbers("12d_forest_and_tie_bars")
save_validation("12d_forest_and_tie_bars")
cat("Forest and tie-rate figures done\n")
