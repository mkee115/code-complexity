# =============================================================================
# 06_figures_survey.R
# Report figures built from the survey analyses (run 03, 04, 05 first).
# Each figure answers one question; its takeaway is in the comment above it.
# =============================================================================

source("scripts/00_setup.R")
suppressPackageStartupMessages(library(patchwork))

conc <- readRDS(file.path(PATHS$work, "rq1_concordance_survey.rds"))
rq2 <- readRDS(file.path(PATHS$work, "rq2_results.rds"))
scored <- readRDS(file.path(PATHS$work, "scored_rq2.rds"))
winrate <- readRDS(file.path(PATHS$work, "rq3_winrate.rds"))
red_long <- readRDS(file.path(PATHS$work, "rq3_reduction.rds"))
pct <- scales::label_percent(accuracy = 1)

# ---- RQ1: concordance between metrics over the 44 survey pairs ---------------
# Takeaway: the metrics almost never order a pair in opposite directions; where
# they differ, one metric ties while the other separates (resolution).
pair_order <- rev(unique(conc$metric_pair))
p_conc <- ggplot(conc, aes(prop, factor(metric_pair, levels = pair_order), fill = class)) +
  geom_col(width = 0.7, colour = "white", linewidth = 0.2, position = position_stack(reverse = TRUE)) +
  geom_text(aes(label = ifelse(prop >= 0.06, pct(prop), "")), position = position_stack(vjust = 0.5, reverse = TRUE),
            size = 2.8, family = FONT_FAMILY, colour = "white") +
  scale_fill_manual(values = CONCORDANCE_COLOURS) +
  scale_x_continuous(labels = pct, expand = expansion(mult = c(0, 0.03))) +
  labs(x = "Share of the 44 survey pairs", y = NULL) +
  theme_report() +
  theme(panel.grid.major.y = element_blank()) +
  guides(fill = guide_legend(nrow = 2))
save_fig(p_conc, "fig_rq1_concordance_survey", height_cm = 7)

# ---- RQ2: agreement and chance-corrected agreement ----------------------------
# Takeaway: CogC agrees with participants most often and CC least; all four are
# better than chance (kappa CI above 0), CC only weakly.
ag <- rq2$agreement
kp <- rq2$kappa
p_ag <- ggplot(ag, aes(agree_all, metric_label, colour = metric_label)) +
  geom_errorbar(aes(xmin = all_low, xmax = all_high), width = 0.25, orientation = "y", linewidth = 0.6) +
  geom_point(size = 2.4) +
  geom_text(aes(label = pct(agree_all)), vjust = -1.1, size = 2.8, family = FONT_FAMILY, show.legend = FALSE) +
  scale_colour_manual(values = METRIC_COLOURS, guide = "none") +
  scale_y_discrete(limits = rev(levels(ag$metric_label))) +
  scale_x_continuous(labels = pct, limits = c(0.3, 0.7)) +
  labs(x = "Agreement with participants (all 750 responses)", y = NULL) +
  theme_report()
p_kp <- ggplot(kp, aes(kappa, metric_label, colour = metric_label)) +
  geom_vline(xintercept = 0, linetype = "dashed", colour = "#888888", linewidth = 0.4) +
  geom_errorbar(aes(xmin = kappa_low, xmax = kappa_high), width = 0.25, orientation = "y", linewidth = 0.6) +
  geom_point(size = 2.4) +
  geom_text(aes(label = sprintf("%.2f", kappa)), vjust = -1.1, size = 2.8, family = FONT_FAMILY, show.legend = FALSE) +
  scale_colour_manual(values = METRIC_COLOURS, guide = "none") +
  scale_y_discrete(limits = rev(levels(kp$metric_label))) +
  scale_x_continuous(limits = c(-0.05, 0.4)) +
  labs(x = "Cohen's kappa (0 = chance)", y = NULL) +
  theme_report() +
  theme(axis.text.y = element_blank())
save_fig(p_ag + p_kp + plot_layout(widths = c(1.2, 1)), "fig_rq2_agreement", height_cm = 5.5)

# ---- RQ2: decomposition (resolution vs direction) ------------------------------
# Takeaway: when CC and the participant both take a side, CC is right about as
# often as the others; its low agreement comes from tying where people did not.
DECOMP_COLOURS <- c("Both take a side: metric right" = "#0072B2",
                    "Both take a side: metric wrong" = "#D55E00",
                    "Metric ties, participant takes a side" = "#E69F00",
                    "Metric takes a side, participant says no difference" = "#BBBBBB",
                    "Both say no difference" = "#666666")
dec <- rq2$decomp |> mutate(decomp = factor(decomp, levels = names(DECOMP_COLOURS)))
dir_lab <- rq2$direction |> transmute(metric_label, lab = paste0(pct(prop_right), " right"))
p_dec <- ggplot(dec, aes(prop, factor(metric_label, levels = rev(levels(metric_label))), fill = decomp)) +
  geom_col(width = 0.7, colour = "white", linewidth = 0.2, position = position_stack(reverse = TRUE)) +
  geom_text(aes(label = ifelse(prop >= 0.05, pct(prop), "")), position = position_stack(vjust = 0.5, reverse = TRUE),
            size = 2.7, family = FONT_FAMILY, colour = "white") +
  geom_text(data = dir_lab, aes(x = 1.01, y = metric_label, label = lab), inherit.aes = FALSE,
            hjust = 0, size = 2.7, family = FONT_FAMILY, colour = "#333333") +
  scale_fill_manual(values = DECOMP_COLOURS) +
  scale_x_continuous(labels = pct, expand = c(0, 0), limits = c(0, 1.17), breaks = seq(0, 1, 0.25)) +
  labs(x = "Share of the 750 responses", y = NULL) +
  theme_report() +
  theme(panel.grid.major.y = element_blank()) +
  guides(fill = guide_legend(nrow = 3))
save_fig(p_dec, "fig_rq2_decomposition", height_cm = 7.5)

# ---- RQ2: measurement gap vs strength of preference -----------------------------
# Takeaway: for CogC, LOC and MaxNest a bigger gap goes with a stronger stated
# preference; CC's gap does not change with strength.
p_gap <- ggplot(scored, aes(strength, gap, fill = metric_label)) +
  geom_boxplot(width = 0.6, outlier.size = 0.6, outlier.alpha = 0.4, linewidth = 0.3) +
  facet_wrap(~ metric_label, nrow = 1, scales = "free_y") +
  scale_fill_manual(values = METRIC_COLOURS, guide = "none") +
  labs(x = "Strength of the participant's preference", y = "|Difference in measurement|") +
  theme_report() +
  theme(axis.text.x = element_text(angle = 30, hjust = 1))
save_fig(p_gap, "fig_rq2_gap_vs_strength", height_cm = 7)

# ---- RQ3: win-rate leaderboard -----------------------------------------------------
# Takeaway: most refactored variants were judged less complex more often than
# not, and most originals less often, but there are clear exceptions.
wr <- winrate |> mutate(id = factor(id, levels = rev(id)))
p_win <- ggplot(wr, aes(win_rate, id, colour = kind)) +
  geom_vline(xintercept = 0.5, linetype = "dashed", colour = "#888888", linewidth = 0.4) +
  geom_errorbar(aes(xmin = low, xmax = high), width = 0, orientation = "y", linewidth = 0.5, alpha = 0.7) +
  geom_point(size = 1.8) +
  scale_colour_manual(values = c(Original = ORIG_COLOUR, `Refactored variant` = REFACTOR_COLOUR)) +
  scale_x_continuous(labels = pct, limits = c(0, 1), breaks = seq(0, 1, 0.25)) +
  labs(x = "Share of comparisons judged less complex (No difference = half), 95% CI", y = NULL) +
  theme_report(base_size = 9) +
  theme(axis.text.y = element_text(size = 7.5), panel.grid.major.y = element_blank())
save_fig(p_win, "fig_rq3_win_rates", height_cm = 14)

# ---- RQ3: size of reduction vs net preference --------------------------------------
# Takeaway: across original-vs-refactor pairs, a larger drop in a measurement
# does not reliably mean a larger perceived improvement.
rho_lab <- red_long |>
  group_by(metric_label) |>
  summarise(rho = suppressWarnings(cor(reduction, net_preference, method = "spearman")), .groups = "drop")
panel_names <- setNames(sprintf("%s (Spearman rho = %.2f)", rho_lab$metric_label, rho_lab$rho),
                        as.character(rho_lab$metric_label))
p_red <- ggplot(red_long, aes(reduction, net_preference, colour = metric_label)) +
  geom_hline(yintercept = 0, colour = "#888888", linewidth = 0.3) +
  geom_vline(xintercept = 0, colour = "#888888", linewidth = 0.3) +
  geom_point(aes(size = n), alpha = 0.75) +
  facet_wrap(~ metric_label, nrow = 2, scales = "free_x", labeller = as_labeller(panel_names)) +
  scale_colour_manual(values = METRIC_COLOURS, guide = "none") +
  scale_size_area(max_size = 3.5, name = "Responses to the pair") +
  labs(x = "Reduction in measurement (original minus refactor)",
       y = "Net preference for refactor (mean rating − 3)") +
  theme_report() +
  theme(legend.title = element_text(size = 8.5))
save_fig(p_red, "fig_rq3_reduction_vs_preference", height_cm = 10)

cat("Survey figures written to", PATHS$figures, "\n")
