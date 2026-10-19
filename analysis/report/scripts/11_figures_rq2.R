# =============================================================================
# 11_figures_rq2.R
# Section 3 (RQ2: which metric agrees most with programmers?), including the sensitivity analyses.
# Figures are PNG, 300 dpi, A4 text width, written to the output folder of their report
# section (see section_of in lib/plot_output.R). Supporting and appendix figures are named
# diag_*. The one-sentence takeaway for each figure is in scripts/figure_takeaways.csv.
# =============================================================================

source("scripts/00_setup.R")
suppressPackageStartupMessages({ library(patchwork); library(ggrepel) })
rq2 <- readRDS(file.path(PATHS$work, "rq2_results.rds"))
scored <- readRDS(file.path(PATHS$work, "scored_rq2.rds"))
grids <- readRDS(file.path(PATHS$work, "rq2_grids.rds"))
sens <- readRDS(file.path(PATHS$work, "sensitivity_results.rds"))
W_LAB <- levels(scored$metric_label)
CAT_LEVELS <- c("B lower", "Equal", "B higher")

# =============================== RQ2 ====================================================
ag <- rq2$agreement |> left_join(rq2$kappa |> select(metric_label, expected_by_chance, kappa, kappa_low, kappa_high), by = "metric_label") |>
  mutate(lab = sprintf("%s (%d/%d)", pct(agree_all, 1), n_agree, n_all),
         metric_label = factor(metric_label, levels = rev(as.character(metric_label[order(agree_all)]))))
# ---- Fig 6: agreement, with the agreement expected by chance as a marker ------------------------------------
p_ag <- ggplot(ag, aes(agree_all, metric_label, fill = metric_label)) +
  geom_col(width = 0.62) +
  geom_errorbar(aes(xmin = all_low, xmax = all_high), width = 0.2, orientation = "y", linewidth = 0.5) +
  geom_point(aes(x = expected_by_chance), shape = 18, size = 4.5, colour = "black") +
  geom_text(aes(x = all_high, label = lab), hjust = -0.12, size = 3.2, family = FONT_FAMILY) +
  scale_fill_manual(values = METRIC_COLOURS, guide = "none") +
  scale_y_discrete(limits = rev(levels(ag$metric_label))) +
  scale_x_continuous(labels = scales::label_percent(), limits = c(0, 0.85), expand = c(0, 0)) +
  labs(title = "How often each metric agrees with participants' judgements",
       subtitle = paste(strwrap("Bars: share of the 750 responses where the metric and the participant gave the same answer (95% interval from resampling participants). Black diamond: the agreement you would expect by chance alone.", 100), collapse = "\n"),
       x = NULL, y = NULL) +
  theme_report() + theme(panel.grid.major.y = element_blank())
save_fig(p_ag, "fig06_rq2_agreement", height_cm = 6.8, rq = "RQ2",
         purpose = "Headline RQ2 result: which metrics agree most with participants, and how far above chance")

# ---- Fig 6b: the same, for every measurement recorded for the survey snippets (optional) ------------------------
# Same rule as fig06: a metric agrees when sign(value_A - value_B) equals the participant's choice, and a tie
# agrees only with "No difference". The four key metrics are checked against fig06 below.
ALL_MEASURES <- c(cc = "CC", cognitive = "CogC", loc = "LOC", max_nesting = "MaxNest",
                  avg_nesting = "Average nesting", hal_vol = "Halstead volume", hal_eff = "Halstead effort",
                  fan_out = "Fan-out", params = "Parameter count", avg_id_words = "Words per identifier",
                  comment_count = "Comment count", has_javadoc = "Has Javadoc")
ALL_MEASURES["recursive"] <- "Recursive"     # not inside c(): `recursive` is an argument name of c()
snip_all <- read_csv(PATHS$snippets, show_col_types = FALSE)
resp_all <- readRDS(file.path(PATHS$work, "responses.rds"))
bh_all <- boot_helpers(readRDS(file.path(PATHS$work, "participants.rds"))$pid)
ag_all <- bind_rows(lapply(names(ALL_MEASURES), function(mk) {
  a <- snip_all[[mk]][match(resp_all$method_a_id, snip_all$id)]
  b <- snip_all[[mk]][match(resp_all$method_b_id, snip_all$id)]
  pred <- sign(as.numeric(a) - as.numeric(b))
  agree <- pred == resp_all$human
  ci <- bh_all$mean_ci(agree, resp_all$pid)
  tab <- table(factor(pred, levels = -1:1), factor(resp_all$human, levels = -1:1))
  tibble(metric = mk, label = ALL_MEASURES[[mk]], n_agree = sum(agree), n_all = length(agree),
         agree_all = mean(agree), all_low = ci[["low"]], all_high = ci[["high"]],
         expected_by_chance = sum(rowSums(tab) * colSums(tab)) / sum(tab)^2, key = mk %in% METRICS)
}))
key_chk <- ag_all |> filter(key) |> left_join(rq2$agreement |> select(metric, n_agree_main = n_agree, low_main = all_low, high_main = all_high), by = "metric")
stopifnot("fig06b: key-metric agreement must match fig06" = all(key_chk$n_agree == key_chk$n_agree_main) &&
            all(abs(key_chk$all_low - key_chk$low_main) < 1e-12) && all(abs(key_chk$all_high - key_chk$high_main) < 1e-12))
save_table(ag_all, "rq2_agreement_all_measures")
ag_all <- ag_all |>
  mutate(lab = sprintf("%s (%d/%d)", pct(agree_all, 1), n_agree, n_all),
         fill_key = ifelse(key, label, "Other measurement"),
         label = factor(label, levels = rev(label[order(agree_all)])))
p_ag_all <- ggplot(ag_all, aes(agree_all, label, fill = fill_key)) +
  geom_col(width = 0.66) +
  geom_errorbar(aes(xmin = all_low, xmax = all_high), width = 0.25, orientation = "y", linewidth = 0.45) +
  geom_point(aes(x = expected_by_chance), shape = 18, size = 3.8, colour = "black") +
  geom_text(aes(x = pmax(all_high, expected_by_chance), label = lab), hjust = -0.18, size = 3, family = FONT_FAMILY) +
  scale_fill_manual(values = c(METRIC_COLOURS, `Other measurement` = "#B5B5B5"), guide = "none") +
  scale_y_discrete(limits = rev(levels(ag_all$label))) +
  scale_x_continuous(labels = scales::label_percent(), limits = c(0, 0.9), expand = c(0, 0)) +
  labs(title = "How often every recorded measurement agrees with participants' judgements",
       subtitle = paste(strwrap("Same rule as the main agreement figure: share of the 750 responses where the measurement and the participant gave the same answer (95% interval from resampling participants), and a tie agrees only with No difference. Coloured bars: the four key metrics. Grey bars: other measurements recorded for the 34 survey snippets. Black diamond: agreement expected by chance.", 100), collapse = "\n"),
       x = NULL, y = NULL) +
  theme_report() + theme(panel.grid.major.y = element_blank())
save_fig(p_ag_all, "fig06b_rq2_agreement_all_measures", height_cm = 11.5, rq = "RQ2",
         purpose = "Optional: agreement with participants for every measurement recorded for the survey snippets, including Halstead")

# Cohen's kappa, kept as a diagnostic with a plain-language explanation
kp <- ag |> mutate(metric_label = factor(metric_label, levels = rev(W_LAB)))
p_kp <- ggplot(kp, aes(kappa, metric_label, colour = metric_label)) +
  geom_vline(xintercept = 0, linetype = "dashed", colour = "#777777", linewidth = 0.4) +
  geom_errorbar(aes(xmin = kappa_low, xmax = kappa_high), width = 0.2, orientation = "y", linewidth = 0.6) +
  geom_point(size = 2.4) +
  geom_text(aes(label = sprintf("%.2f", kappa)), vjust = -1.1, size = 3.2, family = FONT_FAMILY) +
  scale_colour_manual(values = METRIC_COLOURS, guide = "none") +
  scale_x_continuous(limits = c(-0.05, 0.45)) +
  labs(title = "Agreement beyond chance (Cohen's kappa)",
       subtitle = paste(strwrap("Kappa = (observed agreement - chance agreement) / (1 - chance agreement). 0 means no better than chance, 1 means perfect agreement. The figure above shows the same idea as a diamond.", 100), collapse = "\n"),
       x = "Cohen's kappa (95% interval from resampling participants)", y = NULL) +
  theme_report() + theme(panel.grid.major.y = element_blank())
save_fig(p_kp, "diag_rq2_kappa", height_cm = 6.2, rq = "RQ2", purpose = "Chance-corrected agreement (kappa)")

# ---- Fig 7a: when the participant chose a side, what did each metric say? -----------------------------------
DB_COL <- c("Metric agrees" = OUTCOME_RIGHT, "Metric points the other way" = OUTCOME_WRONG, "Metric ties" = OUTCOME_TIE)
db <- rq2$decisive_break |> mutate(outcome = factor(outcome, levels = names(DB_COL)), metric_label = factor(metric_label, levels = rev(W_LAB)))
p_db <- ggplot(db, aes(prop, metric_label, fill = outcome)) +
  geom_col(width = 0.7, colour = "white", linewidth = 0.25, position = position_stack(reverse = TRUE)) +
  geom_text(aes(label = pct(prop), colour = after_scale(text_on(fill))), position = position_stack(vjust = 0.5, reverse = TRUE),
            size = 3.4, family = FONT_FAMILY) +
  scale_fill_manual(values = DB_COL) +
  scale_x_continuous(labels = scales::label_percent(), expand = c(0, 0), breaks = seq(0, 1, 0.25)) +
  labs(title = "When a participant chose a side, what did each metric say?",
       subtitle = "The 675 responses where the participant judged one method less complex than the other",
       x = "Share of those responses", y = NULL) +
  theme_report() + theme(panel.grid.major.y = element_blank()) + guides(fill = guide_legend(nrow = 1))
save_fig(p_db, "fig07a_rq2_what_each_metric_said", height_cm = 6.6, rq = "RQ2",
         purpose = "Shows how much of each metric's disagreement is tying versus pointing the other way")

# ---- Fig 7b: when the metric takes a side, how often is it right? ---------------------------------------------
dr <- rq2$direction |> mutate(metric_label = factor(metric_label, levels = rev(W_LAB)),
                              lab = sprintf("%s (%d/%d)", pct(prop_right), right, n))
p_dr <- ggplot(dr, aes(prop_right, metric_label, fill = metric_label)) +
  geom_col(width = 0.62) +
  geom_errorbar(aes(xmin = low, xmax = high), width = 0.2, orientation = "y", linewidth = 0.5) +
  geom_vline(xintercept = 0.5, linetype = "dashed", colour = "#555555") +
  geom_text(aes(x = high, label = lab), hjust = -0.12, size = 3.2, family = FONT_FAMILY) +
  scale_fill_manual(values = METRIC_COLOURS, guide = "none") +
  scale_x_continuous(labels = scales::label_percent(), limits = c(0, 1), expand = c(0, 0), breaks = seq(0, 1, 0.25)) +
  labs(title = "When a metric does take a side, how often is it right?",
       subtitle = paste(strwrap("Only responses where the metric separates the two methods and the participant chose a side (95% interval from resampling participants). Dashed line: 50%, a coin flip.", 100), collapse = "\n"),
       x = NULL, y = NULL) +
  theme_report() + theme(panel.grid.major.y = element_blank())
save_fig(p_dr, "fig07b_rq2_direction_accuracy", height_cm = 6.2, rq = "RQ2",
         purpose = "Direction accuracy of each metric when it does separate the pair")

# Full five-way decomposition kept as a diagnostic
DEC_COL <- c("Both take a side and agree" = OUTCOME_RIGHT, "Both take a side but disagree" = OUTCOME_WRONG,
             "Metric ties, participant takes a side" = OUTCOME_TIE,
             "Metric takes a side, participant says no difference" = OUTCOME_NODIFF, "Both say no difference" = OUTCOME_BOTH_NODIFF)
dec <- rq2$decomp |> mutate(decomp = factor(decomp, levels = names(DEC_COL)), metric_label = factor(metric_label, levels = rev(W_LAB)))
p_dec <- ggplot(dec, aes(prop, metric_label, fill = decomp)) +
  geom_col(width = 0.7, colour = "white", linewidth = 0.25, position = position_stack(reverse = TRUE)) +
  geom_text(aes(label = ifelse(prop >= 0.05, pct(prop), ""), colour = after_scale(text_on(fill))),
            position = position_stack(vjust = 0.5, reverse = TRUE), size = 3, family = FONT_FAMILY) +
  scale_fill_manual(values = DEC_COL) +
  scale_x_continuous(labels = scales::label_percent(), expand = c(0, 0), breaks = seq(0, 1, 0.25)) +
  labs(title = "All 750 responses, split five ways", x = "Share of the 750 responses", y = NULL) +
  theme_report() + theme(panel.grid.major.y = element_blank()) + guides(fill = guide_legend(nrow = 3))
save_fig(p_dec, "diag_rq2_decomposition_five_categories", height_cm = 8, rq = "RQ2", purpose = "Full five-way decomposition of agreement")

# ---- Fig 8: six 3x3 grids --------------------------------------------------------------------------------
TYPE_FILL <- c("Same direction" = "#D6E6F4", "Opposite directions" = "#F8D3C8", "One metric ties" = "#FBEFC4", "Both tie" = "#E6E6E6")
grid_plot <- function(m1, m2) {
  c1 <- METRIC_LABELS[m1]; c2 <- METRIC_LABELS[m2]
  cells <- grids$cells |> filter(metric_1 == c1, metric_2 == c2) |>
    mutate(x = as.integer(col), y = 4 - as.integer(row),
           type = factor(type, levels = names(TYPE_FILL)),
           head = ifelse(n == 0, "no pairs", sprintf("%d %s, %d responses", pairs, ifelse(pairs == 1, "pair", "pairs"), n)),
           body = ifelse(n == 0, "", ifelse(same_prediction,
                    sprintf("Both: %s\nNeither: %s", pct(shared_agree / n), pct((n - shared_agree) / n)),
                    sprintf("%s only: %s\n%s only: %s\nNeither: %s", c1, pct(only_m1 / n), c2, pct(only_m2 / n), pct(neither / n)))))
  ggplot(cells, aes(x, y)) +
    geom_tile(aes(fill = ifelse(n == 0, NA, as.character(type))), colour = "white", linewidth = 1.2, width = 1, height = 1) +
    geom_text(aes(y = y + 0.37, label = head, colour = ifelse(n == 0, "#999999", "#555555")), size = 3.1, family = FONT_FAMILY, fontface = "italic") +
    geom_text(aes(y = y - 0.08, label = body), size = 4.6, family = FONT_FAMILY, lineheight = 1.05, colour = "#111111") +
    scale_fill_manual(values = TYPE_FILL, na.value = "white", breaks = names(TYPE_FILL), name = NULL, drop = FALSE) +
    scale_colour_identity() +
    scale_x_continuous(breaks = 1:3, labels = CAT_LEVELS, position = "top", expand = c(0, 0)) +
    scale_y_continuous(breaks = 3:1, labels = CAT_LEVELS, expand = c(0, 0)) +
    labs(title = sprintf("%s versus %s", c1, c2),
         subtitle = paste(strwrap(sprintf("Each cell groups the survey pairs by what the two metrics say about Method B compared with Method A. Percentages: share of the cell's responses that agree with both metrics, only one of them, or neither. 'Neither' includes 'No difference' answers."), 105), collapse = "\n"),
         x = sprintf("%s: Method B's measurement compared with Method A's", c1),
         y = sprintf("%s: B compared with A", c2)) +
    theme_report(base_size = 9.5) +
    theme(panel.grid = element_blank(), axis.title.y = element_text(margin = margin(r = 4)),
          axis.text = element_text(face = "bold", size = 9), plot.subtitle = element_text(size = 8)) +
    guides(fill = guide_legend(nrow = 1, override.aes = list(colour = "grey70")))
}
for (mp in METRIC_PAIRS) {
  if (identical(mp, c("cc", "cognitive"))) next     # replaced by the forest plot fig08_a (12d_forest_and_tie_bars.R)
  nm <- sprintf("fig08_%s_grid_%s_vs_%s", letters[match(list(mp), METRIC_PAIRS)], tolower(METRIC_LABELS[mp[1]]), tolower(METRIC_LABELS[mp[2]]))
  save_fig(grid_plot(mp[1], mp[2]), nm, height_cm = 13, rq = "RQ2",
           purpose = sprintf("3x3 grid for %s vs %s: where the two metrics agree or differ, and which side participants took", METRIC_LABELS[mp[1]], METRIC_LABELS[mp[2]]))
}

# ---- Fig 9: agreement by tie status and side --------------------------------------------------------------
STATUS_ORDER <- c("Lower measurement on the left (A)", "Lower measurement on the right (B)", "Measurements equal")
st <- rq2$status |> mutate(metric_label = factor(metric_label, levels = rev(W_LAB)),
                           status = factor(status, levels = rev(STATUS_ORDER)),     # first level is drawn at the bottom
                           lab = sprintf("%s (%d/%d)", pct(agree, 1), n_agree, n))
DODGE <- position_dodge(width = 0.8)
p_st <- ggplot(st, aes(agree, metric_label, fill = status)) +
  geom_col(position = DODGE, width = 0.78) +
  geom_errorbar(aes(xmin = low, xmax = high), position = DODGE, width = 0.3, orientation = "y", linewidth = 0.4) +
  geom_text(aes(x = high, label = lab), position = DODGE, hjust = -0.1, size = 2.5, family = FONT_FAMILY) +
  scale_fill_manual(values = c("Lower measurement on the left (A)" = "#2166AC", "Lower measurement on the right (B)" = "#67A9CF",
                               "Measurements equal" = "#BDBDBD"), breaks = STATUS_ORDER) +
  scale_x_continuous(labels = scales::label_percent(), limits = c(0, 1.08), breaks = seq(0, 1, 0.25), expand = c(0, 0)) +
  labs(title = "Agreement by whether the metric separates the pair and where the lower measurement was",
       subtitle = "A metric tie can only agree with 'No difference', so agreement on tied pairs is very low",
       x = "Agreement with participants (95% CI from resampling participants)", y = NULL) +
  theme_report() + theme(panel.grid.major.y = element_blank(), plot.title = element_text(size = 10)) + guides(fill = guide_legend(nrow = 1))
save_fig(p_st, "fig09_rq2_agreement_by_tie_status_and_side", height_cm = 10, rq = "RQ2",
         purpose = "Agreement split by whether the metric ties and where the lower measurement was shown")

# Fig 10 (gap vs strength) is now the grouped bar chart of tie rates by strength of preference, made in
# 12d_forest_and_tie_bars.R. The gap-vs-strength tests are still run and recorded in 05_rq2_agreement.R.

# ---- Fig 11: pair-level ----------------------------------------------------------------------------------------
pl <- rq2$pair_level |> mutate(metric_label = factor(metric_label, levels = W_LAB))
rho_lab <- rq2$pair_cor |> mutate(metric_label = factor(metric_label, levels = W_LAB),
                                   lab = sprintf("Spearman rho = %.2f", rho))
p_pl <- ggplot(pl, aes(diff_a_minus_b, perceived_b_less_complex, colour = metric_label)) +
  geom_hline(yintercept = 0, colour = "#888888", linewidth = 0.3) + geom_vline(xintercept = 0, colour = "#888888", linewidth = 0.3) +
  geom_point(aes(size = n), position = position_jitter(width = 0.12, height = 0, seed = SEED), alpha = 0.7) +
  geom_text(data = rho_lab, aes(x = -Inf, y = Inf, label = lab), inherit.aes = FALSE, hjust = -0.05, vjust = 1.5, size = 2.7, family = FONT_FAMILY) +
  facet_wrap(~ metric_label, nrow = 2, scales = "free_x") +
  scale_colour_manual(values = METRIC_COLOURS, guide = "none") + scale_size_area(max_size = 3.4, name = "Responses to the pair") +
  labs(title = "Pair by pair: do larger measurement differences go with larger perceived differences?",
       subtitle = "One point per survey pair. Right of 0: B has the lower measurement. Above 0: B judged less complex on average.",
       x = "Measurement of A minus measurement of B", y = "Mean rating minus 3 (positive: B judged less complex)") +
  theme_report()
save_fig(p_pl, "fig11_rq2_pair_level", height_cm = 11, rq = "RQ2",
         purpose = "Pair-level view (each pair counted once) of whether measurement differences track perceived differences")

# ---- Sensitivity ----------------------------------------------------------------------------------------------------
n_of <- function(a) sens$sens$n[sens$sens$analysis == a][1]      # responses in each analysis
SHORT <- c("Main analysis: all 750 responses" = sprintf("Main analysis
(all %d responses)", n_of("Main analysis: all 750 responses")),
           "Only participants with all 3 screening questions correct" = sprintf("Screening questions
all correct (%d)", n_of("Only participants with all 3 screening questions correct")),
           "Decisive responses only (No difference excluded)" = sprintf("Decisive responses
only (%d)", n_of("Decisive responses only (No difference excluded)")),
           "Metric separates and participant chooses a side" = "Metric separates and
participant takes a side")
sn <- sens$sens |> mutate(metric_label = factor(metric_label, levels = rev(W_LAB)),
                          analysis = factor(SHORT[as.character(analysis)], levels = SHORT))
p_sn <- ggplot(sn, aes(agree, metric_label, colour = metric_label)) +
  geom_errorbar(aes(xmin = low, xmax = high), width = 0.25, orientation = "y", linewidth = 0.5) + geom_point(size = 2) +
  geom_text(aes(label = pct(agree)), vjust = -1.1, size = 2.5, family = FONT_FAMILY) +
  facet_wrap(~ analysis, nrow = 1) +
  scale_colour_manual(values = METRIC_COLOURS, guide = "none") +
  scale_x_continuous(labels = scales::label_percent(), limits = c(0.25, 0.95)) +
  labs(title = "Agreement under four ways of selecting responses", x = "Agreement (95% CI)", y = NULL,
       subtitle = "Only the first panel is the main analysis; the others show how much each rule changes the picture") +
  theme_report(base_size = 8.5) + theme(strip.text = element_text(size = 7.5), panel.spacing.x = unit(1, "lines"))
save_fig(p_sn, "fig12_sensitivity_agreement", height_cm = 7.5, rq = "RQ2", purpose = "Shows the ranking of metrics under alternative inclusion rules")

EXP_LAB <- c("None" = "None", "Written tiny programs (Up to 100 lines)" = "Tiny\n(<100 lines)", "Written small programs (100-500 lines)" = "Small\n(100\u2013500)",
             "Written medium programs (500-2000 lines)" = "Medium\n(500\u20132,000)", "Written large programs (2000+ lines)" = "Large\n(2,000+)")
ex <- sens$exp |> mutate(metric_label = factor(metric_label, levels = W_LAB),
                         xl = sprintf("%s\n%d people", EXP_LAB[as.character(experience)], people))
ex$xl <- factor(ex$xl, levels = unique(ex$xl))
p_ex <- ggplot(ex, aes(xl, agree, colour = metric_label, group = metric_label)) +
  geom_errorbar(aes(ymin = low, ymax = high), width = 0.18, position = position_dodge(width = 0.5), linewidth = 0.4) +
  geom_point(position = position_dodge(width = 0.5), size = 1.8) +
  scale_colour_manual(values = METRIC_COLOURS) + scale_y_continuous(labels = scales::label_percent(), limits = c(0.1, 0.95)) +
  labs(title = "Agreement by self-reported Java programming experience",
       subtitle = "Largest programs written. The 'none' and 'large' groups are small, so their intervals are wide.",
       x = NULL, y = "Agreement (95% CI)") + theme_report()
save_fig(p_ex, "fig13_sensitivity_experience", height_cm = 7.5, rq = "RQ2", purpose = "Checks whether agreement differs by self-reported experience")


save_figure_registry("11_figures_rq2")
cat("Figures written (11_figures_rq2)
")
