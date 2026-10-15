# =============================================================================
# 07_figures.R
# All report figures (PNG, 300 dpi, A4 text width). Figures in output/figures are
# report candidates; output/diagnostics holds exploratory and diagnostic ones.
# Titles state the finding's subject, not the research question; the one-sentence
# takeaway for each figure is in output/figure_index.csv.
# =============================================================================

source("scripts/00_setup.R")
suppressPackageStartupMessages({ library(patchwork); library(ggrepel) })

rq1s <- readRDS(file.path(PATHS$work, "rq1_survey.rds"))
rq1c <- readRDS(file.path(PATHS$work, "rq1_corpus_concordance.rds"))
corr_c <- readRDS(file.path(PATHS$work, "rq1_corpus_corr.rds"))
pca_c <- readRDS(file.path(PATHS$work, "rq1_corpus_pca.rds"))
rq2 <- readRDS(file.path(PATHS$work, "rq2_results.rds"))
scored <- readRDS(file.path(PATHS$work, "scored_rq2.rds"))
grids <- readRDS(file.path(PATHS$work, "rq2_grids.rds"))
rq3 <- readRDS(file.path(PATHS$work, "rq3_results.rds"))
sens <- readRDS(file.path(PATHS$work, "sensitivity_results.rds"))
meta <- readRDS(file.path(PATHS$work, "corpus_meta.rds"))
prov <- if (meta$complete) "" else "  [PROVISIONAL corpus]"
W_LAB <- levels(scored$metric_label)
CAT_LEVELS <- c("B lower", "Equal", "B higher")

text_on <- function(fill) ifelse(fill %in% c("#2166AC", "#B2182B", "#636363"), "white", "#111111")

# =============================== RQ1 ====================================================
# ---- Fig 2: Spearman correlations --------------------------------------------------------
heat_df <- function(m, label) {
  as_tibble(as.data.frame(as.table(m))) |>
    setNames(c("row", "col", "rho")) |>
    mutate(row = factor(row, levels = rev(METRIC_LABELS)), col = factor(col, levels = METRIC_LABELS),
           keep = as.integer(col) <= (5 - as.integer(row)), panel = label) |>    # lower triangle incl. diagonal
    filter(keep)
}
hd <- bind_rows(heat_df(corr_c$key[METRIC_LABELS, METRIC_LABELS], sprintf("Corpus: %s methods%s", format(nrow(readRDS(file.path(PATHS$work, "corpus_key.rds"))[main == TRUE]), big.mark = ","), prov)),
                heat_df(rq1s$corr_key[METRIC_LABELS, METRIC_LABELS], "Survey: 34 constructed snippets"))
p_heat <- ggplot(hd, aes(col, row, fill = rho)) +
  geom_tile(colour = "white", linewidth = 0.8) +
  geom_text(aes(label = sprintf("%.2f", rho), colour = rho > 0.6), size = 3.1, family = FONT_FAMILY) +
  facet_wrap(~ panel, nrow = 1) +
  scale_fill_gradient(low = "#F7FBFF", high = "#08306B", limits = c(0, 1), name = "Spearman correlation",
                      guide = guide_colourbar(title.position = "top", barwidth = 10, barheight = 0.5)) +
  scale_colour_manual(values = c(`TRUE` = "white", `FALSE` = "#111111"), guide = "none") +
  labs(title = "Rank correlations between the four metrics", x = NULL, y = NULL,
       subtitle = "Spearman correlation of the measurements; 1 means the metrics always rank methods identically") +
  theme_report() + theme(panel.grid = element_blank(), legend.title = element_text(size = 8.5), panel.spacing.x = unit(1.2, "lines"))
save_fig(p_heat, "fig02_rq1_correlations", height_cm = 8.5, rq = "RQ1",
         purpose = "How strongly the metrics' rankings agree, in the corpus and in the survey snippets")

# ---- Fig 3: pairwise concordance (one figure per sample) ----------------------------------------
conc_all <- bind_rows(rq1c$conc, rq1s$concordance |> select(any_of(names(rq1c$conc)))) |>
  mutate(source = factor(source, levels = unique(source)),
         metric_pair = factor(metric_pair, levels = rev(unique(metric_pair))),
         class = factor(class, levels = CONCORDANCE_LEVELS))
CONC_SUB <- "Concordant: both metrics order the pair the same way.  Discordant: opposite ways.  One ties: one metric gives the two methods the same score."
conc_fig <- function(src, title, name, purpose, extra = "") {
  d <- conc_all |> filter(source == src)
  p <- ggplot(d, aes(prop, metric_pair, fill = class)) +
    geom_col(width = 0.72, colour = "white", linewidth = 0.25, position = position_stack(reverse = TRUE)) +
    geom_text(aes(label = ifelse(prop >= 0.05, pct(prop), ""), colour = after_scale(text_on(fill))),
              position = position_stack(vjust = 0.5, reverse = TRUE), size = 3, family = FONT_FAMILY) +
    scale_fill_manual(values = CONCORDANCE_COLOURS) +
    scale_x_continuous(labels = scales::label_percent(), expand = expansion(mult = c(0, 0.01))) +
    labs(title = title, subtitle = paste(strwrap(paste0(CONC_SUB, extra), 100), collapse = "\n"), x = "Share of pairs", y = NULL) +
    theme_report() + theme(panel.grid.major.y = element_blank()) + guides(fill = guide_legend(nrow = 1))
  save_fig(p, name, height_cm = 7.6, rq = "RQ1", purpose = purpose)
}
conc_fig("Survey pairs (n = 44)", "Do the metrics order the 44 survey pairs the same way?",
         "fig03a_rq1_concordance_survey", "Direct test of the supervisor's definition on the survey pairs")
conc_fig("Corpus: random method pairs", "Do the metrics order two random corpus methods the same way?",
         "fig03b_rq1_concordance_corpus_random", "Same test on 1,000,000 random pairs of corpus methods", prov)
conc_fig("Corpus: non-trivial methods (LOC ≥ 10 or CC ≥ 3)", "Do the metrics order two larger corpus methods the same way?",
         "fig03c_rq1_concordance_corpus_nontrivial", "Same test restricted to non-trivial methods (LOC >= 10 or CC >= 3)", prov)

# ---- Fig 4: resolution (one simple bar chart per question) ----------------------------------------------
rs <- rq1s$resolution; rc <- rq1c$resolution
tie_bar <- function(df, title, subtitle, name, purpose, main = TRUE) {
  df <- df |> mutate(metric = factor(metric, levels = rev(METRIC_LABELS)))
  p <- ggplot(df, aes(value, metric, fill = metric)) +
    geom_col(width = 0.62) +
    geom_text(aes(label = lab), hjust = -0.1, size = 3.2, family = FONT_FAMILY) +
    scale_fill_manual(values = METRIC_COLOURS, guide = "none") +
    scale_x_continuous(labels = scales::label_percent(), limits = c(0, max(df$value) * 1.35), expand = c(0, 0)) +
    labs(title = title, subtitle = subtitle, x = NULL, y = NULL) +
    theme_report() + theme(panel.grid.major.y = element_blank())
  save_fig(p, name, height_cm = 5.6, main = main, rq = "RQ1/RQ2", purpose = purpose)
}
tie_bar(tibble(metric = rs$metric, value = rs$prop_pairs_tied, lab = sprintf("%s (%d of 44 pairs)", pct(rs$prop_pairs_tied), rs$pairs_tied)),
        "How often does each metric give the two methods in a survey pair the same score?",
        "Share of the 44 survey pairs on which the metric ties", "fig04a_rq1_ties_survey_pairs",
        "Resolution: how often each metric cannot tell the two survey methods apart")
tie_bar(tibble(metric = rc$metric, value = rc$pair_tie_rate_random, lab = pct(rc$pair_tie_rate_random)),
        "How often does each metric give two random corpus methods the same score?",
        paste0("Chance that two randomly chosen methods tie", prov), "fig04b_rq1_ties_corpus",
        "Resolution in the corpus")
tie_bar(tibble(metric = rc$metric, value = rc$pair_tie_rate_above_lowest, lab = pct(rc$pair_tie_rate_above_lowest)),
        "How often does each metric tie two corpus methods that both score above its lowest value?",
        paste0("Lowest values removed: CC 1, CogC 0, LOC 1, MaxNest 0", prov),
        "fig04c_rq1_ties_corpus_above_lowest", "Resolution in the corpus once the trivial lowest-value methods are removed")
tie_bar(tibble(metric = rs$metric, value = rs$prop_responses_tied, lab = sprintf("%s (%d of 750)", pct(rs$prop_responses_tied), rs$responses_tied)),
        "Share of the 750 survey responses that were about a tied pair",
        "Counts each response, so a pair seen by many participants counts many times", "diag_rq1_ties_survey_responses",
        "Response-level tie share (differs from the pair-level share)", main = FALSE)

# ---- Fig 5: PCA (scree only; loadings are a diagnostic) -----------------------------------------------------
scree_df <- bind_rows(pca_c$key_var |> mutate(panel = "Corpus"),
                      rq1s$pca_var |> filter(grepl("key metrics \\(log1p", dataset)) |> mutate(panel = "Survey: 34 constructed snippets")) |>
  mutate(panel = factor(panel, levels = unique(panel)))
p_scree <- ggplot(scree_df, aes(component, variance)) +
  geom_col(fill = "#4D4D4D", width = 0.6) +
  geom_text(aes(label = pct(variance)), vjust = -0.5, size = 3.2, family = FONT_FAMILY) +
  facet_wrap(~ panel, nrow = 1) +
  scale_y_continuous(labels = scales::label_percent(), limits = c(0, 1), expand = expansion(mult = c(0, 0.04))) +
  labs(title = "One shared component explains most of the variation between the four metrics",
       subtitle = paste0(paste(strwrap("PC1 is the single combination of CC, CogC, LOC and MaxNest that varies most from method to method. Each bar is the share of all variation one component explains.", 100), collapse = "\n"), prov),
       x = NULL, y = "Share of variation") +
  theme_report()
save_fig(p_scree, "fig05_rq1_pca_variance", height_cm = 7.6, rq = "RQ1",
         purpose = "Supporting evidence: how much variation one shared component captures (not proof the metrics are equivalent)")
load_df <- bind_rows(pca_c$key_load |> pivot_longer(starts_with("PC"), names_to = "component", values_to = "loading") |> mutate(panel = "Corpus"),
                     rq1s$pca_load_key |> pivot_longer(starts_with("PC"), names_to = "component", values_to = "loading") |> mutate(panel = "Survey snippets")) |>
  mutate(metric = factor(metric, levels = rev(METRIC_LABELS)))
p_load <- ggplot(load_df, aes(component, metric, fill = loading)) +
  geom_tile(colour = "white", linewidth = 0.8) +
  geom_text(aes(label = sprintf("%.2f", loading), colour = abs(loading) > 0.6), size = 3, family = FONT_FAMILY) +
  facet_wrap(~ panel, nrow = 1) +
  scale_fill_gradient2(low = "#B2182B", mid = "white", high = "#2166AC", limits = c(-1, 1), name = "Loading") +
  scale_colour_manual(values = c(`TRUE` = "white", `FALSE` = "#111111"), guide = "none") +
  labs(title = "What each principal component is made of (loadings)", x = NULL, y = NULL,
       subtitle = "Only the sign pattern within a component matters; the sign of a whole component is arbitrary") +
  theme_report() + theme(panel.grid = element_blank(), legend.position = "right")
save_fig(p_load, "diag_rq1_pca_loadings", height_cm = 6.5, main = FALSE, rq = "RQ1", purpose = "PCA loadings")

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
save_fig(p_kp, "diag_rq2_kappa", height_cm = 6.2, main = FALSE, rq = "RQ2", purpose = "Chance-corrected agreement (kappa)")

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
save_fig(p_dec, "diag_rq2_decomposition_five_categories", height_cm = 8, main = FALSE, rq = "RQ2", purpose = "Full five-way decomposition of agreement")

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

# ---- Fig 10: gap vs strength -------------------------------------------------------------------------------
gp <- scored |> mutate(strength = factor(strength, levels = c("No difference", "Slightly", "Much")))
gap_main <- gp |> filter(metric %in% c("cc", "cognitive", "loc"))
cnt3 <- gap_main |> count(metric_label, strength)
gap_main <- gap_main |> mutate(strength = factor(strength, levels = c("No difference", "Slightly", "Much"),
                                                  labels = c("No difference\n(n = 75)", "Slightly\n(n = 401)", "Much\n(n = 274)")))
p_gap <- ggplot(gap_main, aes(strength, gap, fill = metric_label)) +
  geom_boxplot(width = 0.6, outlier.size = 0.5, outlier.alpha = 0.35, linewidth = 0.3) +
  facet_wrap(~ metric_label, nrow = 1, scales = "free_y") +
  scale_fill_manual(values = METRIC_COLOURS, guide = "none") +
  labs(title = "Do bigger differences in measurement go with stronger preferences?",
       subtitle = "Each panel uses that metric's own units, so the panels are not comparable with each other",
       x = "Strength of the participant's preference (responses)", y = "Absolute difference in measurement") +
  theme_report()
save_fig(p_gap, "fig10_rq2_gap_vs_strength", height_cm = 8, rq = "RQ2",
         purpose = "Tests whether the size of a metric's measurement difference tracks how strongly participants prefer one method")
p_gap4 <- ggplot(gp, aes(strength, gap, fill = metric_label)) +
  geom_boxplot(width = 0.6, outlier.size = 0.5, outlier.alpha = 0.35, linewidth = 0.3) +
  facet_wrap(~ metric_label, nrow = 1, scales = "free_y") + scale_fill_manual(values = METRIC_COLOURS, guide = "none") +
  labs(x = "Strength of the participant's preference", y = "Absolute difference in measurement") + theme_report() +
  theme(axis.text.x = element_text(angle = 25, hjust = 1))
save_fig(p_gap4, "diag_rq2_gap_vs_strength_all_four", height_cm = 7, main = FALSE, rq = "RQ2", purpose = "Same as fig10 including MaxNest")

# ---- Fig 11: pair-level ----------------------------------------------------------------------------------------
pl <- rq2$pair_level |> mutate(metric_label = factor(metric_label, levels = W_LAB))
rho_lab <- rq2$pair_cor |> mutate(metric_label = factor(metric_label, levels = W_LAB),
                                   lab = sprintf("Spearman rho = %.2f", rho))
p_pl <- ggplot(pl, aes(diff_a_minus_b, perceived_b_less_complex, colour = metric_label)) +
  geom_hline(yintercept = 0, colour = "#888888", linewidth = 0.3) + geom_vline(xintercept = 0, colour = "#888888", linewidth = 0.3) +
  geom_jitter(aes(size = n), width = 0.12, height = 0, alpha = 0.7) +
  geom_text(data = rho_lab, aes(x = -Inf, y = Inf, label = lab), inherit.aes = FALSE, hjust = -0.05, vjust = 1.5, size = 2.7, family = FONT_FAMILY) +
  facet_wrap(~ metric_label, nrow = 2, scales = "free_x") +
  scale_colour_manual(values = METRIC_COLOURS, guide = "none") + scale_size_area(max_size = 3.4, name = "Responses to the pair") +
  labs(title = "Pair by pair: do larger measurement differences go with larger perceived differences?",
       subtitle = "One point per survey pair. Right of 0: B has the lower measurement. Above 0: B judged less complex on average.",
       x = "Measurement of A minus measurement of B", y = "Mean rating minus 3 (positive: B judged less complex)") +
  theme_report()
save_fig(p_pl, "fig11_rq2_pair_level", height_cm = 11, rq = "RQ2",
         purpose = "Pair-level view (each pair counted once) of whether measurement differences track perceived differences")

# ---- Position diagnostic ------------------------------------------------------------------------------------------
pos <- rq2$position |> mutate(subset = factor(subset, levels = rev(subset)))
pos_long <- pos |> select(subset, chose_A, no_difference, chose_B) |> pivot_longer(-subset) |>
  group_by(subset) |> mutate(prop = value / sum(value)) |> ungroup() |>
  mutate(name = factor(name, levels = c("chose_A", "no_difference", "chose_B"), labels = c("Chose A (left)", "No difference", "Chose B (right)")))
p_pos1 <- ggplot(pos_long, aes(prop, subset, fill = name)) +
  geom_col(width = 0.65, colour = "white", position = position_stack(reverse = TRUE)) +
  geom_text(aes(label = sprintf("%d (%s)", value, pct(prop))), position = position_stack(vjust = 0.5, reverse = TRUE), size = 2.5,
            colour = "white", family = FONT_FAMILY) +
  scale_fill_manual(values = c("#2166AC", "#999999", "#B2182B")) +
  scale_x_continuous(labels = scales::label_percent(), expand = c(0, 0)) + labs(x = "Share of responses", y = NULL) +
  theme_report() + theme(panel.grid.major.y = element_blank())
p_pos2 <- ggplot(pos, aes(diff_B_minus_A, subset)) +
  geom_vline(xintercept = 0, linetype = "dashed", colour = "#777777") +
  geom_errorbar(aes(xmin = diff_low, xmax = diff_high), width = 0.2, orientation = "y") + geom_point(size = 2) +
  scale_x_continuous(labels = function(x) sprintf("%+.0f pts", 100 * x)) +
  labs(x = "Share choosing B minus share choosing A\n(decisive responses; 95% CI)", y = NULL) +
  theme_report() + theme(axis.text.y = element_blank(), panel.grid.major.y = element_blank())
p_pos <- (p_pos1 | p_pos2) + plot_layout(widths = c(1.6, 1)) +
  plot_annotation(title = "Did participants favour the right-hand method?",
                  subtitle = "Method A was always the earlier version, so position was not counterbalanced",
                  theme = theme(plot.title = element_text(face = "bold", size = 11, family = FONT_FAMILY),
                                plot.subtitle = element_text(size = 8.5, family = FONT_FAMILY)))
save_fig(p_pos, "diag_position_lean", height_cm = 6.5, main = FALSE, rq = "Design diagnostic", purpose = "Checks for a left/right preference lean")

# ---- Sensitivity ----------------------------------------------------------------------------------------------------
SHORT <- c("Main analysis: all 750 responses" = "Main analysis\n(all 750 responses)",
           "Only participants with all 3 screening questions correct" = "Screening questions\nall correct (380)",
           "Decisive responses only (No difference excluded)" = "Decisive responses\nonly (675)",
           "Metric separates and participant chooses a side" = "Metric separates and\nparticipant takes a side")
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
  geom_text_repel(aes(label = method_b_id), size = 2, family = FONT_FAMILY, colour = "#333333", max.overlaps = 40, segment.size = 0.2, min.segment.length = 0.2) +
  facet_wrap(~ metric_label, nrow = 2, scales = "free_x", labeller = as_labeller(panel_names)) +
  scale_colour_manual(values = METRIC_COLOURS, guide = "none") + scale_size_area(max_size = 3.3, name = "Responses") +
  labs(title = "Reduction in a measurement against perceived improvement, pair by pair",
       subtitle = "One point per refactor compared with its original. Above 0: refactor judged less complex. Labels are variant IDs.",
       x = "Reduction in measurement (original minus refactor)", y = "Net preference for the refactor (mean rating − 3)") +
  theme_report() + theme(legend.title = element_text(size = 8.5))
save_fig(p_red, "diag_rq3_reduction_scatter", height_cm = 12.5, main = FALSE, rq = "RQ3", purpose = "Scatter behind the reduction-vs-preference result")

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

# ---- Diagnostics: corpus PCA scores and broad correlation/PCA -----------------------------------------------------
p_sc <- ggplot(pca_c$scores, aes(PC1, PC2)) + geom_bin2d(bins = 70) + scale_fill_viridis_c(trans = "log10", name = "Methods") +
  labs(title = "Corpus: methods on the first two components", subtitle = "30,000-method random sample; log(1+x), standardised", x = "PC1", y = "PC2") + theme_report()
sc <- rq1s$pca_scores
p_ss <- ggplot(sc, aes(PC1, PC2, colour = variant == "ORIG")) + geom_point(size = 1.8) +
  geom_text_repel(aes(label = id), size = 2.1, family = FONT_FAMILY, max.overlaps = 40, segment.size = 0.2) +
  scale_colour_manual(values = c(`TRUE` = ORIG_COLOUR, `FALSE` = REFACTOR_COLOUR), guide = "none") +
  labs(title = "Survey snippets on the first two components", subtitle = "Orange: originals. 34 constructed snippets.", x = "PC1", y = "PC2") + theme_report()
save_fig(p_sc | p_ss, "diag_rq1_pca_scores", height_cm = 8, main = FALSE, rq = "RQ1", purpose = "PCA score plots")

bro <- as_tibble(as.data.frame(as.table(corr_c$broad))) |> setNames(c("row", "col", "rho")) |>
  mutate(row = factor(row, levels = rev(rownames(corr_c$broad))), col = factor(col, levels = rownames(corr_c$broad)))
p_br <- ggplot(bro, aes(col, row, fill = rho)) + geom_tile(colour = "white") +
  geom_text(aes(label = sprintf("%.2f", rho)), size = 1.7, family = FONT_FAMILY) +
  scale_fill_gradient2(low = "#B2182B", mid = "white", high = "#2166AC", limits = c(-1, 1), name = "Spearman") +
  labs(title = "Corpus: broader set of metrics (Spearman)", subtitle = sprintf("1,000,000-method random sample%s", prov), x = NULL, y = NULL) +
  theme_report(base_size = 8) + theme(axis.text.x = element_text(angle = 50, hjust = 1), panel.grid = element_blank(), legend.position = "right")
save_fig(p_br, "diag_rq1_corpus_correlations_broad", height_cm = 15, main = FALSE, rq = "RQ1", purpose = "Broader metric correlation matrix")
bs <- as_tibble(as.data.frame(as.table(rq1s$corr_broad))) |> setNames(c("row", "col", "rho")) |>
  mutate(row = factor(row, levels = rev(rownames(rq1s$corr_broad))), col = factor(col, levels = rownames(rq1s$corr_broad)))
p_bs <- ggplot(bs, aes(col, row, fill = rho)) + geom_tile(colour = "white") +
  geom_text(aes(label = sprintf("%.2f", rho)), size = 2.2, family = FONT_FAMILY) +
  scale_fill_gradient2(low = "#B2182B", mid = "white", high = "#2166AC", limits = c(-1, 1), name = "Spearman") +
  labs(title = "Survey snippets: broader set of metrics (Spearman)", subtitle = "34 constructed snippets", x = NULL, y = NULL) +
  theme_report(base_size = 8.5) + theme(axis.text.x = element_text(angle = 50, hjust = 1), panel.grid = element_blank(), legend.position = "right")
save_fig(p_bs, "diag_rq1_survey_correlations_broad", height_cm = 11, main = FALSE, rq = "RQ1", purpose = "Broader metric correlation matrix for the survey snippets")

bscree <- bind_rows(pca_c$broad_var |> mutate(panel = "Corpus, broader metrics (1M sample)"),
                    rq1s$pca_var |> filter(grepl("broader", dataset)) |> mutate(panel = "Survey snippets, broader metrics")) |>
  filter(as.integer(sub("PC", "", component)) <= 10) |> mutate(component = factor(component, levels = paste0("PC", 1:10)))
p_bsc <- ggplot(bscree, aes(component, variance)) + geom_col(fill = "#4D4D4D", width = 0.6) + facet_wrap(~ panel) +
  geom_text(aes(label = pct(variance)), vjust = -0.4, size = 2.4, family = FONT_FAMILY) +
  scale_y_continuous(labels = scales::label_percent(), expand = expansion(mult = c(0, 0.12))) +
  labs(title = "Broader metric sets: variance explained by each component", x = NULL, y = NULL) + theme_report()
save_fig(p_bsc, "diag_rq1_pca_broad_scree", height_cm = 7, main = FALSE, rq = "RQ1", purpose = "Scree for the broader metric sets")

save_figure_registry("07_figures")
cat("Figures written\n")
