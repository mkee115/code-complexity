# =============================================================================
# 12_figures_rq3.R
# Section 4 (RQ3: does reducing a measurement reduce perceived complexity?).
# Figures are PNG, 300 dpi, A4 text width, written to the output folder of their report
# section (see section_of in lib/plot_output.R). Supporting and appendix figures are named
# diag_*. The one-sentence takeaway for each figure is in scripts/figure_takeaways.csv.
# =============================================================================

source("scripts/00_setup.R")
suppressPackageStartupMessages({ library(patchwork); library(ggrepel) })
rq3 <- readRDS(file.path(PATHS$work, "rq3_results.rds"))
W_LAB <- METRIC_LABELS[METRICS]

# =============================== RQ3 ====================================================
wr <- rq3$winrate |> mutate(id = factor(id, levels = rev(id)))
p_win <- ggplot(wr, aes(win_rate, id, colour = kind)) +
  geom_vline(xintercept = 0.5, linetype = "dashed", colour = "#888888", linewidth = 0.4) +
  geom_errorbar(aes(xmin = low, xmax = high), width = 0, orientation = "y", linewidth = 0.5, alpha = 0.7) + geom_point(size = 1.8) +
  geom_text(aes(x = 1.02, label = sprintf("%d", n)), hjust = 0, size = 2.1, colour = "#555555", family = FONT_FAMILY) +
  scale_colour_manual(values = c(Original = ORIG_COLOUR, `Refactored variant` = REFACTOR_COLOUR)) +
  scale_x_continuous(labels = scales::label_percent(), limits = c(0, 1.07), breaks = seq(0, 1, 0.25)) +
  labs(title = "How often each version was judged less complex than the version it was compared with",
       subtitle = "Win rate with 95% CI (No difference counts as half). Numbers on the right: comparisons. Variants were constructed, not sampled.",
       x = "Share of comparisons judged less complex", y = NULL) +
  theme_report(base_size = 9) + theme(axis.text.y = element_text(size = 7.5), panel.grid.major.y = element_blank(), plot.title = element_text(size = 10))
save_fig(p_win, "fig14_rq3_win_rates", height_cm = 15.5, rq = "RQ3", purpose = "Ranks every version by how often participants judged it less complex")

# ---- Fig 14a-d: the same leaderboard, shaded by each metric's measurement within the task ----------------
snip_m <- read_csv(PATHS$snippets, show_col_types = FALSE)
win_by_metric <- function(m, letter) {
  lab <- METRIC_LABELS[m]
  d <- rq3$winrate |>
    mutate(group = as.integer(substr(as.character(id), 1, 2))) |>
    left_join(snip_m |> select(id, value = all_of(m)), by = "id") |>
    group_by(group) |>
    # 0 = lowest measurement among this task's variants, 1 = highest (0.5 if every variant ties)
    mutate(rel = if (max(value) == min(value)) 0.5 else (value - min(value)) / (max(value) - min(value))) |>
    ungroup() |>
    mutate(id = factor(id, levels = rev(as.character(id))),
           right_lab = sprintf("%s %d  (n = %d)", lab, value, n))
  p <- ggplot(d, aes(win_rate, id)) +
    geom_vline(xintercept = 0.5, linetype = "dashed", colour = "#888888", linewidth = 0.4) +
    geom_errorbar(aes(xmin = low, xmax = high), width = 0, orientation = "y", linewidth = 0.5, colour = "#9A9A9A") +
    geom_point(aes(fill = rel), shape = 21, size = 2.6, colour = "#333333", stroke = 0.4) +
    geom_text(aes(x = 1.02, label = right_lab), hjust = 0, size = 2.2, colour = "#555555", family = FONT_FAMILY) +
    scale_fill_gradient(low = "#C6DBEF", high = "#08306B", limits = c(0, 1), breaks = c(0, 1),
                        labels = c(paste("Lowest", lab, "in its task"), paste("Highest", lab, "in its task")),
                        guide = guide_colourbar(barwidth = 9, barheight = 0.5, title = NULL, label.position = "bottom")) +
    scale_x_continuous(labels = scales::label_percent(), limits = c(0, 1.2), breaks = seq(0, 1, 0.25)) +
    labs(title = sprintf("How often each version was judged less complex, shaded by its %s", lab),
         subtitle = paste(strwrap(sprintf("Win rate with 95%% CI (No difference counts as half). Shade: the version's %s compared with the other versions of the same task, darkest = highest. Right: its %s and the number of comparisons.", lab, lab), 105), collapse = "\n"),
         x = "Share of comparisons judged less complex", y = NULL) +
    theme_report(base_size = 9) +
    theme(axis.text.y = element_text(size = 7.5), panel.grid.major.y = element_blank(), plot.title = element_text(size = 10))
  save_fig(p, sprintf("fig14%s_rq3_win_rates_by_%s", letter, tolower(lab)), height_cm = 15.5, rq = "RQ3",
           purpose = sprintf("Win-rate leaderboard shaded by each version's %s within its task, to see whether higher measurements go with being judged more complex", lab))
}
for (i in seq_along(METRICS)) win_by_metric(METRICS[i], letters[i])

op <- rq3$orig_pairs |> mutate(label = sprintf("%s (%d vs %d)", method_b_id, prefer_refactor, prefer_original)) |>
  arrange(share_prefer_refactor) |> mutate(label = factor(label, levels = label),
                                          outcome = factor(outcome, levels = c("Refactor preferred", "No significant preference", "Original preferred")))
p_op <- ggplot(op, aes(share_prefer_refactor, label, colour = outcome)) +
  geom_vline(xintercept = 0.5, linetype = "dashed", colour = "#888888", linewidth = 0.4) +
  geom_errorbar(aes(xmin = ci_low, xmax = ci_high), width = 0, orientation = "y", linewidth = 0.5) + geom_point(size = 1.9) +
  scale_colour_manual(values = c("Refactor preferred" = "#2166AC", "No significant preference" = "#7F7F7F", "Original preferred" = "#B2182B")) +
  scale_x_continuous(labels = scales::label_percent(), limits = c(0, 1)) +
  labs(title = "Each refactor against its original",
       subtitle = "Share of decisive responses preferring the refactor (95% CI).\nLabels: refactor (responses preferring the refactor vs the original). Colour: Holm-adjusted exact test.",
       x = "Share of decisive responses preferring the refactored version", y = NULL) +
  theme_report(base_size = 9) + theme(axis.text.y = element_text(size = 7.5), panel.grid.major.y = element_blank(), plot.title = element_text(size = 10)) +
  guides(colour = guide_legend(nrow = 1))
save_fig(p_op, "fig15_rq3_original_vs_refactor", height_cm = 13, rq = "RQ3", purpose = "Direct test, pair by pair, of whether each refactor was preferred to its original")

rl <- rq3$red_long |> mutate(metric_label = factor(metric_label, levels = W_LAB))
rho_r <- rq3$red_cor |> mutate(metric_label = factor(metric_label, levels = W_LAB), lab = sprintf("%s (Spearman rho = %.2f)", metric_label, rho))
panel_names <- setNames(rho_r$lab, rho_r$metric_label)
p_red <- ggplot(rl, aes(reduction, net_preference, colour = metric_label)) +
  geom_hline(yintercept = 0, colour = "#888888", linewidth = 0.3) + geom_vline(xintercept = 0, colour = "#888888", linewidth = 0.3) +
  geom_point(aes(size = n), alpha = 0.75) +
  geom_text_repel(aes(label = method_b_id), size = 2, family = FONT_FAMILY, colour = "#333333", max.overlaps = 40, segment.size = 0.2, min.segment.length = 0.2, seed = SEED) +
  facet_wrap(~ metric_label, nrow = 2, scales = "free_x", labeller = as_labeller(panel_names)) +
  scale_colour_manual(values = METRIC_COLOURS, guide = "none") + scale_size_area(max_size = 3.3, name = "Responses") +
  labs(title = "Reduction in a measurement against perceived improvement, pair by pair",
       subtitle = "One point per refactor compared with its original. Above 0: refactor judged less complex. Labels are variant IDs.",
       x = "Reduction in measurement (original minus refactor)", y = "Net preference for the refactor (mean rating − 3)") +
  theme_report() + theme(legend.title = element_text(size = 8.5))
save_fig(p_red, "diag_rq3_reduction_scatter", height_cm = 12.5, rq = "RQ3", purpose = "Scatter behind the reduction-vs-preference result")

bc <- rq3$by_change |> mutate(metric_label = factor(metric_label, levels = W_LAB),
                              change = factor(change, levels = rev(c("Measurement reduced", "Unchanged", "Measurement increased")),
                                              labels = rev(c("Measurement fell", "Measurement unchanged", "Measurement rose"))),
                              lab = sprintf("%s  (%d %s)", pct(share_refactor), pairs, ifelse(pairs == 1, "pair", "pairs")))
p_bc <- ggplot(bc, aes(share_refactor, change, colour = metric_label)) +
  geom_vline(xintercept = 0.5, linetype = "dashed", colour = "#777777") +
  geom_errorbar(aes(xmin = low, xmax = high), width = 0.2, orientation = "y", linewidth = 0.6) +
  geom_point(size = 2.6) +
  geom_text(aes(x = high, label = lab), hjust = -0.1, size = 3, family = FONT_FAMILY, show.legend = FALSE) +
  facet_wrap(~ metric_label, ncol = 1, strip.position = "left", scales = "free_y") +
  scale_colour_manual(values = METRIC_COLOURS, guide = "none") +
  scale_x_continuous(labels = scales::label_percent(), limits = c(0, 1.25), breaks = seq(0, 1, 0.25)) +
  labs(title = "Were refactors preferred more when a measurement fell?",
       subtitle = paste(strwrap("Each dot: share of decisive responses preferring the refactored version, for the refactors where that metric's measurement fell, stayed the same or rose compared with the original (95% interval). Dashed line: no preference.", 100), collapse = "\n"),
       x = "Share of decisive responses preferring the refactor", y = NULL) +
  theme_report() + theme(strip.placement = "outside", strip.text.y.left = element_text(angle = 0, face = "bold"), panel.grid.major.y = element_blank())
save_fig(p_bc, "fig16_rq3_preference_by_measurement_change", height_cm = 10.5, rq = "RQ3",
         purpose = "Whether refactors that lowered a measurement were preferred more than those that did not")

ft <- rq3$factor_tbl |> mutate(factor = factor(factor, levels = rev(factor)),
                               lab = sprintf("%s (n=%d)", sub(",.*", "", variants), n_variants))
p_ft <- ggplot(ft, aes(mean_net_preference, factor)) +
  geom_vline(xintercept = 0, colour = "#888888") + geom_point(aes(size = responses), colour = "#4D4D4D") +
  geom_text(aes(x = mean_net_preference, label = variants), vjust = -1.1, size = 2.2, family = FONT_FAMILY, colour = "#555555") +
  scale_size_area(max_size = 4, name = "Responses") +
  labs(title = "What kind of change made code feel simpler?", x = "Mean net preference for the refactor (positive = judged less complex)", y = NULL,
       subtitle = "Descriptive: each kind of change rests on one to four variants") + theme_report()
save_fig(p_ft, "fig17_rq3_type_of_change", height_cm = 10, rq = "RQ3", purpose = "Descriptive view of which kinds of change were preferred")


save_figure_registry("12_figures_rq3")
cat("Figures written (12_figures_rq3)
")
