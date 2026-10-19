# =============================================================================
# 10_figures_rq1.R
# Section 2 (RQ1: do the metrics order methods the same way?).
# Figures are PNG, 300 dpi, A4 text width, written to the output folder of their report
# section (see section_of in lib/plot_output.R). Supporting and appendix figures are named
# diag_*. The one-sentence takeaway for each figure is in scripts/figure_takeaways.csv.
# =============================================================================

source("scripts/00_setup.R")
suppressPackageStartupMessages({ library(patchwork); library(ggrepel) })
meta <- readRDS(file.path(PATHS$work, "corpus_meta.rds"))
prov <- if (meta$complete) "" else "  [PROVISIONAL corpus]"
rq1s <- readRDS(file.path(PATHS$work, "rq1_survey.rds"))
rq1c <- readRDS(file.path(PATHS$work, "rq1_corpus_concordance.rds"))
corr_c <- readRDS(file.path(PATHS$work, "rq1_corpus_corr.rds"))
pca_c <- readRDS(file.path(PATHS$work, "rq1_corpus_pca.rds"))
n_main <- nrow(readRDS(file.path(PATHS$work, "corpus_key.rds"))[main == TRUE])

# =============================== RQ1 ====================================================
# ---- Fig 2: Spearman correlations --------------------------------------------------------
heat_df <- function(m, label) {
  as_tibble(as.data.frame(as.table(m))) |>
    setNames(c("row", "col", "rho")) |>
    mutate(row = factor(row, levels = rev(METRIC_LABELS)), col = factor(col, levels = METRIC_LABELS),
           keep = as.integer(col) <= (5 - as.integer(row)), panel = label) |>    # lower triangle incl. diagonal
    filter(keep)
}
hd <- bind_rows(heat_df(corr_c$key[METRIC_LABELS, METRIC_LABELS], sprintf("Corpus: %s methods%s", format(n_main, big.mark = ","), prov)),
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

# ---- Fig 2b: the same correlations without the lowest values -------------------------------------
heat_above <- function(long, label) {
  long |>
    mutate(row = factor(metric_2, levels = rev(METRIC_LABELS)), col = factor(metric_1, levels = METRIC_LABELS),
           panel = label) |>
    filter(as.integer(col) <= (5 - as.integer(row)))
}
ha <- bind_rows(heat_above(corr_c$key_above, sprintf("Corpus%s", prov)), heat_above(rq1s$corr_key_above, "Survey snippets")) |>
  mutate(lab = ifelse(metric_1 == metric_2, sprintf("n = %s", prettyNum(n, big.mark = ",")),
                      sprintf("%.2f
(n = %s)", rho, prettyNum(n, big.mark = ","))),
         panel = factor(panel, levels = unique(panel)))
p_heat_above <- ggplot(ha, aes(col, row, fill = ifelse(metric_1 == metric_2, NA, rho))) +
  geom_tile(colour = "white", linewidth = 0.8) +
  geom_text(aes(label = lab, colour = !is.na(rho) & metric_1 != metric_2 & rho > 0.6), size = 2.3, family = FONT_FAMILY, lineheight = 0.95) +
  facet_wrap(~ panel, nrow = 1) +
  scale_fill_gradient(low = "#F7FBFF", high = "#08306B", limits = c(0, 1), na.value = "#EDEDED", name = "Spearman correlation",
                      guide = guide_colourbar(title.position = "top", barwidth = 10, barheight = 0.5)) +
  scale_colour_manual(values = c(`TRUE` = "white", `FALSE` = "#111111"), guide = "none") +
  labs(title = "Rank correlations between the metrics, without the lowest values",
       subtitle = paste(strwrap("Each cell uses only the methods (or snippets) that score above the lowest possible value on both of its metrics (CC 1, CogC 0, LOC 1, MaxNest 0 removed). n = how many remain; the diagonal shows how many are above the lowest value of that metric alone.", 100), collapse = "
"),
       x = NULL, y = NULL) +
  theme_report() + theme(panel.grid = element_blank(), legend.title = element_text(size = 8.5), panel.spacing.x = unit(1.2, "lines"))
save_fig(p_heat_above, "fig02b_rq1_correlations_above_lowest", height_cm = 9.5, rq = "RQ1",
         purpose = "The metric correlations once the trivial lowest-value methods are removed")

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
conc_fig("Corpus: non-trivial methods (CC ≥ 3)", "Do the metrics order two non-trivial corpus methods the same way?",
         "fig03c_rq1_concordance_corpus_nontrivial", "Same test restricted to non-trivial methods (CC >= 3)", prov)

# ---- Fig 4: resolution (one simple bar chart per question) ----------------------------------------------
rs <- rq1s$resolution; rc <- rq1c$resolution
tie_bar <- function(df, title, subtitle, name, purpose) {
  df <- df |> mutate(metric = factor(metric, levels = rev(METRIC_LABELS)))
  p <- ggplot(df, aes(value, metric, fill = metric)) +
    geom_col(width = 0.62) +
    geom_text(aes(label = lab), hjust = -0.1, size = 3.2, family = FONT_FAMILY) +
    scale_fill_manual(values = METRIC_COLOURS, guide = "none") +
    scale_x_continuous(labels = scales::label_percent(), limits = c(0, max(df$value) * 1.35), expand = c(0, 0)) +
    labs(title = title, subtitle = subtitle, x = NULL, y = NULL) +
    theme_report() + theme(panel.grid.major.y = element_blank())
  save_fig(p, name, height_cm = 5.6, rq = "RQ1/RQ2", purpose = purpose)
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
        "Response-level tie share (differs from the pair-level share)")

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
save_fig(p_load, "diag_rq1_pca_loadings", height_cm = 6.5, rq = "RQ1", purpose = "PCA loadings")

# ---- Diagnostics: corpus PCA scores and broad correlation/PCA -----------------------------------------------------
p_sc <- ggplot(pca_c$scores, aes(PC1, PC2)) + geom_bin2d(bins = 70) + scale_fill_viridis_c(trans = "log10", name = "Methods") +
  labs(title = "Corpus: methods on the first two components", subtitle = "30,000-method random sample; log(1+x), standardised", x = "PC1", y = "PC2") + theme_report()
sc <- rq1s$pca_scores
p_ss <- ggplot(sc, aes(PC1, PC2, colour = variant == "ORIG")) + geom_point(size = 1.8) +
  geom_text_repel(aes(label = id), size = 2.1, family = FONT_FAMILY, max.overlaps = 40, segment.size = 0.2, seed = SEED) +
  scale_colour_manual(values = c(`TRUE` = ORIG_COLOUR, `FALSE` = REFACTOR_COLOUR), guide = "none") +
  labs(title = "Survey snippets on the first two components", subtitle = "Orange: originals. 34 constructed snippets.", x = "PC1", y = "PC2") + theme_report()
save_fig(p_sc | p_ss, "diag_rq1_pca_scores", height_cm = 8, rq = "RQ1", purpose = "PCA score plots")

bro <- as_tibble(as.data.frame(as.table(corr_c$broad))) |> setNames(c("row", "col", "rho")) |>
  mutate(row = factor(row, levels = rev(rownames(corr_c$broad))), col = factor(col, levels = rownames(corr_c$broad)))
p_br <- ggplot(bro, aes(col, row, fill = rho)) + geom_tile(colour = "white") +
  geom_text(aes(label = sprintf("%.2f", rho)), size = 1.7, family = FONT_FAMILY) +
  scale_fill_gradient2(low = "#B2182B", mid = "white", high = "#2166AC", limits = c(-1, 1), name = "Spearman") +
  labs(title = "Corpus: broader set of metrics (Spearman)", subtitle = sprintf("1,000,000-method random sample%s", prov), x = NULL, y = NULL) +
  theme_report(base_size = 8) + theme(axis.text.x = element_text(angle = 50, hjust = 1), panel.grid = element_blank(), legend.position = "right")
save_fig(p_br, "diag_rq1_corpus_correlations_broad", height_cm = 15, rq = "RQ1", purpose = "Broader metric correlation matrix")
bs <- as_tibble(as.data.frame(as.table(rq1s$corr_broad))) |> setNames(c("row", "col", "rho")) |>
  mutate(row = factor(row, levels = rev(rownames(rq1s$corr_broad))), col = factor(col, levels = rownames(rq1s$corr_broad)))
p_bs <- ggplot(bs, aes(col, row, fill = rho)) + geom_tile(colour = "white") +
  geom_text(aes(label = sprintf("%.2f", rho)), size = 2.2, family = FONT_FAMILY) +
  scale_fill_gradient2(low = "#B2182B", mid = "white", high = "#2166AC", limits = c(-1, 1), name = "Spearman") +
  labs(title = "Survey snippets: broader set of metrics (Spearman)", subtitle = "34 constructed snippets", x = NULL, y = NULL) +
  theme_report(base_size = 8.5) + theme(axis.text.x = element_text(angle = 50, hjust = 1), panel.grid = element_blank(), legend.position = "right")
save_fig(p_bs, "diag_rq1_survey_correlations_broad", height_cm = 11, rq = "RQ1", purpose = "Broader metric correlation matrix for the survey snippets")

bscree <- bind_rows(pca_c$broad_var |> mutate(panel = "Corpus, broader metrics (1M sample)"),
                    rq1s$pca_var |> filter(grepl("broader", dataset)) |> mutate(panel = "Survey snippets, broader metrics")) |>
  filter(as.integer(sub("PC", "", component)) <= 10) |> mutate(component = factor(component, levels = paste0("PC", 1:10)))
p_bsc <- ggplot(bscree, aes(component, variance)) + geom_col(fill = "#4D4D4D", width = 0.6) + facet_wrap(~ panel) +
  geom_text(aes(label = pct(variance)), vjust = -0.4, size = 2.4, family = FONT_FAMILY) +
  scale_y_continuous(labels = scales::label_percent(), expand = expansion(mult = c(0, 0.12))) +
  labs(title = "Broader metric sets: variance explained by each component", x = NULL, y = NULL) + theme_report()
save_fig(p_bsc, "diag_rq1_pca_broad_scree", height_cm = 7, rq = "RQ1", purpose = "Scree for the broader metric sets")


save_figure_registry("10_figures_rq1")
cat("Figures written (10_figures_rq1)
")
