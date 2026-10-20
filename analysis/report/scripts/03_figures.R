# =============================================================================
# 03_figures.R
# All figures, one section per report section, followed by the extra RQ2 robustness analyses and their figures.
#
# Each section runs in its own local() block, so its variables do not leak into the
# next one. Intermediate results pass between sections as files in output/_pipeline/.
# =============================================================================

source("scripts/00_setup.R")

# -----------------------------------------------------------------------------
# SECTION 09_figures_data
# Section 1 (data and corpus): the corpus distributions and the position check.
# Figures are PNG, 300 dpi, A4 text width, written to the output folder of their report
# section (see section_of in lib/plot_output.R). Supporting and appendix figures are named
# diag_*. The one-sentence takeaway for each figure is in scripts/figure_takeaways.csv.
# -----------------------------------------------------------------------------
local({
  set.seed(SEED)   # label placement (ggrepel) and jitter draw from the RNG; fix it per section
  suppressPackageStartupMessages({ library(patchwork); library(ggrepel) })
  meta <- readRDS(file.path(PATHS$work, "corpus_meta.rds"))
  prov <- if (meta$complete) "" else "  [PROVISIONAL corpus]"
  rq2 <- readRDS(file.path(PATHS$work, "rq2_results.rds"))

  # ---- Fig 1: log-log frequency plot (descriptive; no distribution is fitted) ---------------------------
  d <- readRDS(file.path(PATHS$work, "corpus_key.rds"))
  m <- d[main == TRUE]
  freq <- rbindlist(lapply(METRICS, function(k)
    m[, .N, by = .(value = get(k))][value >= 1][, metric := METRIC_LABELS[k]]))
  freq[, metric := factor(metric, levels = METRIC_LABELS)]
  zero_metrics <- c("cognitive", "max_nesting")
  zero_note <- paste(sprintf("%s: %s of methods are 0", METRIC_LABELS[zero_metrics],
                             pct(vapply(zero_metrics, function(k) mean(m[[k]] == 0), numeric(1)), 0)),
                     collapse = "; ")
  p_loglog <- ggplot(freq, aes(value, N, colour = metric)) +
    geom_point(size = 0.9, alpha = 0.8) +
    facet_wrap(~ metric, nrow = 2, scales = "free_x") +
    scale_x_log10(labels = scales::label_comma()) +
    scale_y_log10(labels = scales::label_comma()) +
    scale_colour_manual(values = METRIC_COLOURS, guide = "none") +
    labs(title = "Most methods have small measurements; a few have very large ones",
         subtitle = paste(strwrap(sprintf("Main corpus, %s methods. Log scales on both axes. Values of 0 are not shown (%s).%s",
                            format(nrow(m), big.mark = ","), zero_note, prov), 105), collapse = "\n"),
         x = "Measurement (log scale)", y = "Number of methods (log scale)") +
    theme_report()
  save_fig(p_loglog, "fig01_corpus_loglog_distributions", height_cm = 10, rq = "Data",
           purpose = "Shows the heavily skewed distributions and the concentration of methods at small values")

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
  save_fig(p_pos, "diag_position_lean", height_cm = 6.5, rq = "Design diagnostic", purpose = "Checks for a left/right preference lean")


  save_figure_registry("09_figures_data")
  cat("Figures written (09_figures_data)
  ")
})

# -----------------------------------------------------------------------------
# SECTION 10_figures_rq1
# Section 2 (RQ1: do the metrics order methods the same way?).
# Figures are PNG, 300 dpi, A4 text width, written to the output folder of their report
# section (see section_of in lib/plot_output.R). Supporting and appendix figures are named
# diag_*. The one-sentence takeaway for each figure is in scripts/figure_takeaways.csv.
# -----------------------------------------------------------------------------
local({
  set.seed(SEED)   # label placement (ggrepel) and jitter draw from the RNG; fix it per section
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
})

# -----------------------------------------------------------------------------
# SECTION 11_figures_rq2
# Section 3 (RQ2: which metric agrees most with programmers?), including the sensitivity analyses.
# Figures are PNG, 300 dpi, A4 text width, written to the output folder of their report
# section (see section_of in lib/plot_output.R). Supporting and appendix figures are named
# diag_*. The one-sentence takeaway for each figure is in scripts/figure_takeaways.csv.
# -----------------------------------------------------------------------------
local({
  set.seed(SEED)   # label placement (ggrepel) and jitter draw from the RNG; fix it per section
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
})

# -----------------------------------------------------------------------------
# SECTION 12_figures_rq3
# Section 4 (RQ3: does reducing a measurement reduce perceived complexity?).
# Figures are PNG, 300 dpi, A4 text width, written to the output folder of their report
# section (see section_of in lib/plot_output.R). Supporting and appendix figures are named
# diag_*. The one-sentence takeaway for each figure is in scripts/figure_takeaways.csv.
# -----------------------------------------------------------------------------
local({
  set.seed(SEED)   # label placement (ggrepel) and jitter draw from the RNG; fix it per section
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
})

# -----------------------------------------------------------------------------
# SECTION 12a_task_robustness
#
# a. Leave-one-task-out: agreement of the four metrics with each of the 10 tasks dropped in turn
# b. Task-level cluster bootstrap for the six pairwise differences in agreement: resample the 10
#    tasks, then the pairs within each drawn task, then the responses within each drawn pair
#    (each participant answered a pair at most once, so that is a resample of the participants who
#    saw the pair). Also the participant-only bootstrap, for comparison.
# Outputs: appendix dot plot (no title), a table of the six differences, numbers in report_numbers.csv.
# -----------------------------------------------------------------------------
local({
  set.seed(SEED)   # label placement (ggrepel) and jitter draw from the RNG; fix it per section
  participants <- readRDS(file.path(PATHS$work, "participants.rds"))
  scored <- readRDS(file.path(PATHS$work, "scored_rq2.rds"))
  pids <- participants$pid
  bh <- boot_helpers(pids)

  KEY <- unname(METRIC_LABELS)                                   # CC, CogC, LOC, MaxNest
  agr <- scored |> select(pid, item, group, metric_label, agree) |>
    pivot_wider(names_from = metric_label, values_from = agree) |> arrange(item, pid)
  validate("task robustness: 750 responses, 10 tasks, 44 pairs", nrow(agr) == 750 && n_distinct(agr$group) == 10 && n_distinct(agr$item) == 44)
  A_all <- as.matrix(agr[, KEY]) * 1
  tasks <- sort(unique(agr$group))
  full <- tibble::tibble(metric = KEY, agreement = colMeans(A_all))

  # ---- a. Leave-one-task-out ------------------------------------------------------------------------
  loto <- purrr::map_dfr(tasks, function(t) {
    keep <- agr$group != t
    tibble::tibble(dropped_task = t, metric = KEY, agreement = colMeans(A_all[keep, , drop = FALSE]), n = sum(keep))
  })
  wide_loto <- loto |> pivot_wider(names_from = metric, values_from = agreement) |>
    mutate(highest = KEY[max.col(as.matrix(across(all_of(KEY))), ties.method = "first")],
           order = apply(as.matrix(across(all_of(KEY))), 1, function(v) paste(KEY[order(-v)], collapse = " > ")),
           cogc_minus_cc = CogC - CC, cogc_minus_loc = CogC - LOC)
  save_table(wide_loto, "rq2_leave_one_task_out")
  rq2 <- readRDS(file.path(PATHS$work, "rq2_results.rds"))
  main_agree <- rq2$agreement$agree_all[match(METRICS, rq2$agreement$metric)]
  validate("leave-one-task-out: the full-data agreement matches the main analysis", isTRUE(all.equal(unname(full$agreement), unname(main_agree))))
  MAIN_ORDER <- paste(full$metric[order(-full$agreement)], collapse = " > ")
  for (m in KEY) {
    v <- wide_loto[[m]]
    record(paste0(m, ": agreement leaving one task out, lowest"), min(v), n = 10, section = "RQ2: task robustness",
           note = paste("task", wide_loto$dropped_task[which.min(v)], "dropped"))
    record(paste0(m, ": agreement leaving one task out, highest"), max(v), n = 10, section = "RQ2: task robustness",
           note = paste("task", wide_loto$dropped_task[which.max(v)], "dropped"))
  }
  record("leave-one-task-out: tasks whose removal keeps CogC the highest", sum(wide_loto$highest == "CogC"), denominator = 10, section = "RQ2: task robustness")
  record("leave-one-task-out: tasks whose removal keeps the full ranking", sum(wide_loto$order == MAIN_ORDER), denominator = 10,
         section = "RQ2: task robustness", note = paste("full-data ranking:", MAIN_ORDER))
  record("leave-one-task-out: CogC minus LOC, smallest across the 10 drops", min(wide_loto$cogc_minus_loc), n = 10, section = "RQ2: task robustness",
         note = paste("task", wide_loto$dropped_task[which.min(wide_loto$cogc_minus_loc)], "dropped"))
  record("leave-one-task-out: CogC minus LOC, largest across the 10 drops", max(wide_loto$cogc_minus_loc), n = 10, section = "RQ2: task robustness")
  record("leave-one-task-out: CogC minus CC, smallest across the 10 drops", min(wide_loto$cogc_minus_cc), n = 10, section = "RQ2: task robustness",
         note = paste("task", wide_loto$dropped_task[which.min(wide_loto$cogc_minus_cc)], "dropped"))
  record("leave-one-task-out: CogC minus CC, largest across the 10 drops", max(wide_loto$cogc_minus_cc), n = 10, section = "RQ2: task robustness")

  ord_metrics <- full$metric[order(-full$agreement)]                 # highest agreement first
  dd <- loto |> mutate(metric = factor(metric, levels = rev(ord_metrics)), y = as.numeric(metric) + (dropped_task - 5.5) * 0.07)
  fd <- full |> mutate(metric = factor(metric, levels = rev(ord_metrics)), y = as.numeric(metric))
  p_loto <- ggplot(dd, aes(agreement, y, colour = metric)) +
    geom_point(size = 1.9) +
    geom_text(aes(label = dropped_task), nudge_x = 0.0045, size = 2.1, family = FONT_FAMILY, show.legend = FALSE) +
    geom_point(data = fd, shape = 18, size = 4.2, colour = "black") +
    scale_colour_manual(values = METRIC_COLOURS, guide = "none") +
    scale_y_continuous(breaks = seq_along(levels(dd$metric)), labels = levels(dd$metric), expand = expansion(add = 0.5)) +
    scale_x_continuous(labels = scales::label_percent(), expand = expansion(mult = c(0.02, 0.05))) +
    labs(x = "Agreement with participants (all 750 responses minus one task)", y = NULL) +
    theme_report() + theme(panel.grid.major.y = element_blank())
  save_fig(p_loto, "diag_rq2_leave_one_task_out", height_cm = 7, rq = "RQ2",
           purpose = "Leave-one-task-out agreement for the four metrics; each dot is labelled with the task that was dropped, the diamond is the full-data value")

  # ---- b. Three-stage cluster bootstrap --------------------------------------------------------------
  A_item <- lapply(split(seq_len(nrow(agr)), agr$item), function(ix) A_all[ix, , drop = FALSE])
  items_by_task <- lapply(tasks, function(t) unique(agr$item[agr$group == t]))
  one_replicate <- function() {
    tot <- numeric(4); n <- 0
    for (t in sample.int(length(tasks), length(tasks), replace = TRUE)) {
      its <- items_by_task[[t]]
      for (i in its[sample.int(length(its), length(its), replace = TRUE)]) {
        Ai <- A_item[[i]]; ni <- nrow(Ai)
        tot <- tot + colSums(Ai[sample.int(ni, ni, replace = TRUE), , drop = FALSE]); n <- n + ni
      }
    }
    tot / n
  }
  set.seed(SEED)
  boot_agree <- t(vapply(seq_len(N_BOOT), function(b) one_replicate(), numeric(4)))
  colnames(boot_agree) <- KEY
  DIFFS <- list(c("CogC", "CC"), c("CogC", "LOC"), c("CogC", "MaxNest"), c("LOC", "CC"), c("LOC", "MaxNest"), c("MaxNest", "CC"))
  diff_tbl <- purrr::map_dfr(DIFFS, function(d) {
    b <- boot_agree[, d[1]] - boot_agree[, d[2]]
    ci_t <- quantile(b, c(0.025, 0.975))
    ci_p <- boot_ratio_ci(bh$W, bh$psum(agr[[d[1]]] - agr[[d[2]]], agr$pid), bh$psum(rep(1, nrow(agr)), agr$pid))
    est <- mean(agr[[d[1]]]) - mean(agr[[d[2]]])
    tibble::tibble(comparison = paste(d[1], "minus", d[2]), estimate = est, task_low = ci_t[[1]], task_high = ci_t[[2]],
                   participant_low = ci_p[["low"]], participant_high = ci_p[["high"]],
                   excludes_zero_task_level = ci_t[[1]] > 0 | ci_t[[2]] < 0, prop_resamples_positive = mean(b > 0))
  })
  save_table(diff_tbl, "rq2_task_bootstrap_differences")
  validate("task bootstrap: the resampled agreement is centred on the observed agreement",
           max(abs(colMeans(boot_agree) - full$agreement)) < 0.01, sprintf("largest gap %.4f", max(abs(colMeans(boot_agree) - full$agreement))))
  for (i in seq_len(nrow(diff_tbl))) {
    r <- diff_tbl[i, ]
    record(paste0("agreement difference, task-level bootstrap: ", r$comparison), r$estimate, r$task_low, r$task_high, n = 750,
           test = "three-stage cluster bootstrap (tasks, pairs within tasks, participants within pairs), 10,000 resamples",
           section = "RQ2: task robustness",
           note = sprintf("participant-only 95%% CI %+.3f to %+.3f", r$participant_low, r$participant_high))
  }
  cogc_top <- mean(apply(boot_agree, 1, function(v) KEY[which.max(v)] == "CogC"))
  same_order <- mean(apply(boot_agree, 1, function(v) paste(KEY[order(-v)], collapse = " > ") == MAIN_ORDER))
  record("task-level bootstrap: share of resamples in which CogC has the highest agreement", cogc_top, n = N_BOOT, section = "RQ2: task robustness")
  record("task-level bootstrap: share of resamples with the full ranking", same_order, n = N_BOOT, section = "RQ2: task robustness",
         note = paste("ranking:", MAIN_ORDER))

  fmt_pp <- function(x) sprintf("%+.1f", 100 * x)
  table_png(diff_tbl |> transmute(Difference = comparison, `Estimate (pp)` = fmt_pp(estimate),
                                  `95% CI, tasks / pairs / participants` = sprintf("%s to %s", fmt_pp(task_low), fmt_pp(task_high)),
                                  `95% CI, participants only` = sprintf("%s to %s", fmt_pp(participant_low), fmt_pp(participant_high)),
                                  `Excludes 0 (task level)` = ifelse(excludes_zero_task_level, "yes", "no")),
            "rq2_task_bootstrap_differences", title = "Pairwise differences in agreement, with task-level uncertainty",
            subtitle = "Percentage points; 10,000 resamples", wrap_note = "Task level: resample the 10 tasks, then the pairs within each task, then the participants who saw each pair.")

  saveRDS(list(loto = wide_loto, diffs = diff_tbl, cogc_top = cogc_top, same_order = same_order), file.path(PATHS$work, "task_robustness.rds"))
  save_figure_registry("12a_task_robustness")
  save_numbers("12a_task_robustness")
  save_validation("12a_task_robustness")
  cat("Task robustness done\n")
})

# -----------------------------------------------------------------------------
# SECTION 12b_commit_rate_and_measures
#
# a. Responses where only one of two metrics agrees (CogC / LOC / MaxNest vs CC), split by whether CC
#    ties on the pair and whether the participant chose a side
# b. Commit rate (share of decisive responses where the metric separates the pair) and direction accuracy
#    (share of those it gets the right way round), for the four key metrics: scatter plot
# c. The same quantities, the tie rate over all 750 responses and the agreement, for the 13 measures
#    in fig06b: table and a scatter of agreement against tie rate
# Participant cluster-bootstrap 95% CIs throughout (same resamples as the other survey scripts).
# -----------------------------------------------------------------------------
local({
  set.seed(SEED)   # label placement (ggrepel) and jitter draw from the RNG; fix it per section
  suppressPackageStartupMessages(library(ggrepel))
  participants <- readRDS(file.path(PATHS$work, "participants.rds"))
  scored <- readRDS(file.path(PATHS$work, "scored_rq2.rds"))
  responses <- readRDS(file.path(PATHS$work, "responses.rds"))
  rq2 <- readRDS(file.path(PATHS$work, "rq2_results.rds"))
  pids <- participants$pid
  bh <- boot_helpers(pids)
  W <- bh$W; psum <- bh$psum

  # est = sum(num & den) / sum(den), with a participant cluster-bootstrap interval
  ratio_ci <- function(pid, num, den) {
    ci <- boot_ratio_ci(W, psum(num & den, pid), psum(den, pid))
    tibble::tibble(est = sum(num & den) / sum(den), low = ci[["low"]], high = ci[["high"]], n_num = sum(num & den), n_den = sum(den))
  }

  # ---- a. Who agrees when only one of two metrics does --------------------------------------------------------
  wide <- scored |> select(pid, item, human, metric, predicted) |> pivot_wider(names_from = metric, values_from = predicted)
  validate("decomposition input has 750 responses", nrow(wide) == 750)
  decomp_only <- purrr::map_dfr(c("cognitive", "loc", "max_nesting"), function(m) {
    pm <- wide[[m]]; pc <- wide$cc; h <- wide$human
    one <- function(flag, direction) wide[flag, ] |>
      transmute(item, comparison = paste(METRIC_LABELS[m], "vs CC"), direction,
                cc = ifelse(pc[flag] == 0, "CC ties", "CC separates"),
                participant = ifelse(h[flag] == 0, "participant: no difference", "participant chose a side"),
                other_metric = ifelse(pm[flag] == 0, paste(METRIC_LABELS[m], "ties"), paste(METRIC_LABELS[m], "separates")))
    bind_rows(one(pm == h & pc != h, paste("Only", METRIC_LABELS[m], "agrees")), one(pc == h & pm != h, "Only CC agrees"))
  })
  decomp_tbl <- decomp_only |> count(comparison, direction, cc, participant, other_metric, name = "responses") |>
    left_join(decomp_only |> distinct(comparison, direction, cc, participant, other_metric, item) |>
                count(comparison, direction, cc, participant, other_metric, name = "pairs"),
              by = c("comparison", "direction", "cc", "participant", "other_metric"))
  save_table(decomp_tbl, "rq2_only_one_agrees_decomposition")
  tot <- decomp_only |> count(comparison, direction, name = "total")
  validate("only-one-agrees counts: CogC-only minus CC-only equals the agreement gap (428 - 320 = 108)",
           with(tot, total[comparison == "CogC vs CC" & direction == "Only CogC agrees"] - total[comparison == "CogC vs CC" & direction == "Only CC agrees"]) == 108)
  for (i in seq_len(nrow(tot))) {
    r <- tot[i, ]
    d <- decomp_only |> filter(comparison == r$comparison, direction == r$direction)
    record(paste0(r$comparison, ": ", r$direction, ", responses"), r$total, section = "RQ2: only-one-agrees")
    record(paste0(r$comparison, ": ", r$direction, ", on pairs where CC ties"), sum(d$cc == "CC ties"), denominator = r$total,
           section = "RQ2: only-one-agrees", note = sprintf("%d distinct pairs", n_distinct(d$item[d$cc == "CC ties"])))
    record(paste0(r$comparison, ": ", r$direction, ", participant chose a side"), sum(d$participant == "participant chose a side"),
           denominator = r$total, section = "RQ2: only-one-agrees")
    record(paste0(r$comparison, ": ", r$direction, ", CC separates and participant said no difference"),
           sum(d$cc == "CC separates" & d$participant == "participant: no difference"), denominator = r$total, section = "RQ2: only-one-agrees")
    record(paste0(r$comparison, ": ", r$direction, ", CC separates and participant chose a side"),
           sum(d$cc == "CC separates" & d$participant == "participant chose a side"), denominator = r$total, section = "RQ2: only-one-agrees")
  }

  # ---- b/c. Tie rate, commit rate, direction accuracy and agreement for the 13 measures ---------------------
  ALL_MEASURES <- c(cc = "CC", cognitive = "CogC", loc = "LOC", max_nesting = "MaxNest",
                    avg_nesting = "Average nesting", hal_vol = "Halstead volume", hal_eff = "Halstead effort",
                    fan_out = "Fan-out", params = "Parameter count", avg_id_words = "Words per identifier",
                    comment_count = "Comment count", has_javadoc = "Has Javadoc")
  ALL_MEASURES["recursive"] <- "Recursive"     # not inside c(): `recursive` is an argument name of c()
  snip <- read_csv(PATHS$snippets, show_col_types = FALSE)
  meas_tbl <- purrr::map_dfr(names(ALL_MEASURES), function(mk) {
    a <- snip[[mk]][match(responses$method_a_id, snip$id)]; b <- snip[[mk]][match(responses$method_b_id, snip$id)]
    pred <- sign(as.numeric(a) - as.numeric(b)); agree <- pred == responses$human
    dec <- responses$human != 0; sep <- pred != 0; all_rows <- rep(TRUE, nrow(responses)); pid <- responses$pid
    t <- ratio_ci(pid, pred == 0, all_rows); a_ <- ratio_ci(pid, agree, all_rows)
    cm <- ratio_ci(pid, sep, dec); dr <- ratio_ci(pid, agree, dec & sep)
    tibble::tibble(metric = mk, measure = ALL_MEASURES[[mk]], key = mk %in% METRICS,
                   tie_rate = t$est, tie_low = t$low, tie_high = t$high,
                   agreement = a_$est, agree_low = a_$low, agree_high = a_$high, n_agree = a_$n_num,
                   commit_rate = cm$est, commit_low = cm$low, commit_high = cm$high, n_decisive = cm$n_den, n_separating = cm$n_num,
                   direction_accuracy = dr$est, dir_low = dr$low, dir_high = dr$high, n_correct = dr$n_num, n_direction = dr$n_den)
  })
  key_chk <- meas_tbl |> filter(key) |> left_join(rq2$agreement |> select(metric, n_agree_main = n_agree, low_main = all_low, high_main = all_high), by = "metric")
  validate("13-measure table: the four key metrics reproduce the main agreement and its interval",
           all(key_chk$n_agree == key_chk$n_agree_main) && all(abs(key_chk$agree_low - key_chk$low_main) < 1e-12) &&
             all(abs(key_chk$agree_high - key_chk$high_main) < 1e-12))
  validate("13-measure table: commit rate and tie rate are consistent for the key metrics (separating responses <= decisive)",
           all(meas_tbl$n_separating <= meas_tbl$n_decisive) && all(meas_tbl$n_decisive == 675))
  save_table(meas_tbl, "rq2_measures_tie_commit_direction")
  for (i in seq_len(nrow(meas_tbl))) {
    r <- meas_tbl[i, ]
    tst <- "participant cluster bootstrap 95% CI"
    record(paste0(r$measure, ": tie rate over all 750 responses"), r$tie_rate, r$tie_low, r$tie_high, n = round(r$tie_rate * 750), denominator = 750,
           test = tst, section = "RQ2: commit rate")
    record(paste0(r$measure, ": commit rate (share of decisive responses where it separates the pair)"), r$commit_rate, r$commit_low, r$commit_high,
           n = r$n_separating, denominator = r$n_decisive, test = tst, section = "RQ2: commit rate")
    record(paste0(r$measure, ": direction accuracy (right way round, when it separates and the participant chose a side)"), r$direction_accuracy,
           r$dir_low, r$dir_high, n = r$n_correct, denominator = r$n_direction, test = tst, section = "RQ2: commit rate")
  }

  # Scatter 1: commit rate against direction accuracy, four key metrics
  key_pts <- meas_tbl |> filter(key) |> mutate(measure = factor(measure, levels = unname(METRIC_LABELS)))
  p_commit <- ggplot(key_pts, aes(commit_rate, direction_accuracy, colour = measure)) +
    geom_hline(yintercept = 0.5, linetype = "dashed", colour = "#777777", linewidth = 0.35) +
    geom_errorbar(aes(ymin = dir_low, ymax = dir_high), width = 0, linewidth = 0.5) +
    geom_errorbar(aes(xmin = commit_low, xmax = commit_high), width = 0, linewidth = 0.5, orientation = "y") +
    geom_point(size = 3) +
    geom_text_repel(aes(label = measure), size = 3.2, family = FONT_FAMILY, show.legend = FALSE, box.padding = 0.7, seed = SEED, min.segment.length = 0) +
    scale_colour_manual(values = METRIC_COLOURS, guide = "none") +
    scale_x_continuous(labels = scales::label_percent(), limits = c(0, 1)) +
    scale_y_continuous(labels = scales::label_percent(), limits = c(0.4, 1)) +
    labs(x = "Commit rate: share of decisive responses it separates",
         y = "Direction accuracy (right way round)") +
    theme_report()
  save_fig(p_commit, "diag_rq2_commit_vs_direction", height_cm = 8.5, rq = "RQ2",
           purpose = "Commit rate against direction accuracy for CC, CogC, LOC and MaxNest (95% participant-bootstrap intervals; dashed line = 50%)")

  # Scatter 2: agreement against tie rate, 13 measures
  sc2 <- meas_tbl |> mutate(group = ifelse(key, measure, "Other measurement"))
  p_tie <- ggplot(sc2, aes(tie_rate, agreement, colour = group)) +
    geom_errorbar(aes(ymin = agree_low, ymax = agree_high), width = 0, linewidth = 0.4, alpha = 0.7) +
    geom_errorbar(aes(xmin = tie_low, xmax = tie_high), width = 0, linewidth = 0.4, alpha = 0.7, orientation = "y") +
    geom_point(aes(size = key)) +
    geom_text_repel(aes(label = measure, fontface = ifelse(key, "bold", "plain")), size = 2.9, family = FONT_FAMILY, show.legend = FALSE,
                    box.padding = 0.45, max.overlaps = Inf, seed = SEED, min.segment.length = 0.1) +
    scale_colour_manual(values = c(METRIC_COLOURS, `Other measurement` = "#8C8C8C"), guide = "none") +
    scale_size_manual(values = c(`TRUE` = 3.2, `FALSE` = 1.9), guide = "none") +
    scale_x_continuous(labels = scales::label_percent(), limits = c(0, 1)) +
    scale_y_continuous(labels = scales::label_percent(), limits = c(0, 0.75)) +
    labs(x = "Tie rate: share of the 750 responses where the measure gives the two methods the same value",
         y = "Agreement with participants (all 750 responses)") +
    theme_report()
  save_fig(p_tie, "diag_rq2_measures_tie_rate_vs_agreement", height_cm = 9.5, rq = "RQ2",
           purpose = "Agreement against tie rate for the 13 measures in fig06b; the four key metrics are coloured")

  fmt_ci <- function(e, l, h) ifelse(is.na(e), "–", sprintf("%.0f%% (%.0f–%.0f)", 100 * e, 100 * l, 100 * h))   # "–": the measure never separates a pair
  table_png(meas_tbl |> transmute(Measure = measure,
                                  `Tie rate` = fmt_ci(tie_rate, tie_low, tie_high),
                                  `Commit rate` = fmt_ci(commit_rate, commit_low, commit_high),
                                  `Direction accuracy` = fmt_ci(direction_accuracy, dir_low, dir_high),
                                  Agreement = fmt_ci(agreement, agree_low, agree_high)),
            "rq2_measures_tie_commit_direction", title = "Tie rate, commit rate, direction accuracy and agreement",
            subtitle = "13 measures; participant-bootstrap 95% intervals",
            wrap_note = "Tie and agreement: all 750 responses. Commit and direction: the 675 responses where the participant chose a side.")

  save_figure_registry("12b_commit_rate_and_measures")
  save_numbers("12b_commit_rate_and_measures")
  save_validation("12b_commit_rate_and_measures")
  cat("Commit rate analyses done\n")
})

# -----------------------------------------------------------------------------
# SECTION 12c_ordinal_models
#
# a. Cumulative-link mixed model of the rating on the signed, rank-scaled measurement differences of CC, CogC,
#    LOC and MaxNest, with random intercepts for participant and pair. Coefficients with Wald 95% CIs and
#    likelihood-ratio tests for dropping each metric; does CogC add anything beyond LOC, and LOC beyond CogC?
# b. Within-task ordinal Bradley-Terry model: a latent perceived-complexity score for every snippet
#    (the original of each task = 0), and the within-task Spearman correlation of each metric with the scores.
# Needs the 'ordinal' package.
# -----------------------------------------------------------------------------
local({
  set.seed(SEED)   # label placement (ggrepel) and jitter draw from the RNG; fix it per section
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
})

# -----------------------------------------------------------------------------
# SECTION 12d_forest_and_tie_bars
#
# a. fig08_a: forest plot. For every pair where CC ties and another metric (CogC, MaxNest or LOC) separates it,
#    the share of decisive responses choosing the method that metric rates lower (Wilson 95% CI), with the
#    pooled estimate (participant cluster bootstrap) at the bottom of each panel.
# b. fig10: grouped bars. For each metric, the share of responses where it gives the two methods the same value,
#    split by the participant's answer (no difference / slightly / much), with participant-bootstrap 95% CIs.
# No titles. The bar chart is exported 1568 px wide.
# -----------------------------------------------------------------------------
local({
  set.seed(SEED)   # label placement (ggrepel) and jitter draw from the RNG; fix it per section
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
})

# -----------------------------------------------------------------------------
# SECTION 12e_biplot_and_all_tie
#
# a. PCA biplot: first two components of the four key metrics (log(1 + x), standardised, fitted on the whole
#    main corpus); a 30,000-method random sample as a density, loading arrows, and the 34 survey snippets
#    (originals orange, variants blue), labelling only snippets outside the corpus 90% ellipse.
# b. Forest plot: share of decisive responses preferring the later version on the seven pairs where all four
#    key metrics tie (comments / Javadoc / naming changes), Wilson 95% CIs, reference line at 50%.
# No titles.
# -----------------------------------------------------------------------------
local({
  set.seed(SEED)   # label placement (ggrepel) and jitter draw from the RNG; fix it per section
  suppressPackageStartupMessages(library(ggrepel))
  participants <- readRDS(file.path(PATHS$work, "participants.rds"))
  responses <- readRDS(file.path(PATHS$work, "responses.rds"))
  rq2 <- readRDS(file.path(PATHS$work, "rq2_results.rds"))
  snip <- read_csv(PATHS$snippets, show_col_types = FALSE)
  pids <- participants$pid
  bh <- boot_helpers(pids)

  # ---- a. PCA biplot ----------------------------------------------------------------------------------------------
  d <- readRDS(file.path(PATHS$work, "corpus_key.rds"))
  m <- d[main == TRUE]
  X <- log1p(as.matrix(m[, ..METRICS])); colnames(X) <- unname(METRIC_LABELS[METRICS])
  pr <- prcomp(X, center = TRUE, scale. = TRUE)
  var_share <- pr$sdev^2 / sum(pr$sdev^2)
  validate("biplot: the PCA reproduces the corpus PC1 share recorded in the corpus script (88.7%)", abs(var_share[1] - 0.8873) < 0.01,
           sprintf("%.4f", var_share[1]))
  set.seed(SEED)
  idx <- sample.int(nrow(X), 30000)
  project <- function(M) scale(M, center = pr$center, scale = pr$scale) %*% pr$rotation[, 1:2]
  samp <- as.data.frame(project(X[idx, ])); names(samp) <- c("PC1", "PC2")
  S <- as.matrix(snip[, METRICS]); colnames(S) <- unname(METRIC_LABELS[METRICS])
  sn <- as.data.frame(project(log1p(S))); names(sn) <- c("PC1", "PC2")
  sn$id <- snip$id; sn$kind <- ifelse(snip$variant == "ORIG", "Original", "Variant")
  mu <- colMeans(samp); cv <- cov(samp); rad <- sqrt(qchisq(0.90, 2))
  ev <- eigen(cv); th <- seq(0, 2 * pi, length.out = 200)
  ell <- as.data.frame(t(mu + ev$vectors %*% diag(sqrt(ev$values)) %*% rbind(rad * cos(th), rad * sin(th)))); names(ell) <- c("PC1", "PC2")
  sn$maha <- sqrt(mahalanobis(sn[, c("PC1", "PC2")], mu, cv)); sn$outside <- sn$maha > rad
  share_in_ellipse_sample <- mean(sqrt(mahalanobis(samp, mu, cv)) <= rad)
  validate("biplot: the 90% ellipse holds about 90% of the sampled corpus methods", abs(share_in_ellipse_sample - 0.9) < 0.03, sprintf("%.3f", share_in_ellipse_sample))
  record("PCA biplot: survey snippets outside the corpus 90% ellipse in PC1-PC2", sum(sn$outside), denominator = nrow(sn), section = "RQ1: biplot",
         note = paste(sn$id[sn$outside], collapse = ", "))
  record("PCA biplot: PC1 share of variance", var_share[1], n = nrow(X), section = "RQ1: biplot", note = "log(1+x), standardised, main corpus")
  record("PCA biplot: PC2 share of variance", var_share[2], n = nrow(X), section = "RQ1: biplot")
  save_table(sn |> select(id, kind, PC1, PC2, maha, outside), "rq1_biplot_snippet_scores")
  ld <- as.data.frame(pr$rotation[, 1:2]); ld$metric <- rownames(ld)
  # Arrows are scaled so the longest reaches about 80% of the way to the snippet farthest from the centre
  karrow <- 0.8 * max(sqrt(sn$PC1^2 + sn$PC2^2)) / max(sqrt(ld$PC1^2 + ld$PC2^2))
  ld <- ld |> mutate(x = PC1 * karrow, y = PC2 * karrow)
  p_biplot <- ggplot() +
    geom_bin2d(data = samp, aes(PC1, PC2), bins = 90) +
    scale_fill_viridis_c(trans = "log10", name = "Corpus methods per cell", option = "D", direction = -1, alpha = 0.9,
                         guide = guide_colourbar(order = 2, barwidth = 6, barheight = 0.5, title.position = "top")) +
    geom_path(data = ell, aes(PC1, PC2), colour = "#333333", linewidth = 0.45, linetype = "dashed") +
    geom_segment(data = ld, aes(x = 0, y = 0, xend = x, yend = y), arrow = arrow(length = unit(0.15, "cm")), linewidth = 0.7, colour = "#222222") +
    geom_text_repel(data = ld, aes(x = x, y = y, label = metric), size = 3.2, family = FONT_FAMILY, fontface = "bold", colour = "#222222",
                    box.padding = 0.9, point.padding = 0.3, seed = SEED, segment.size = 0.2, min.segment.length = 0.3) +
    geom_point(data = sn, aes(PC1, PC2, colour = kind, shape = kind), size = 2.4) +
    geom_text_repel(data = sn[sn$outside, ], aes(PC1, PC2, label = id, colour = kind), size = 2.6, family = FONT_FAMILY, seed = SEED, max.overlaps = Inf,
                    box.padding = 0.35, segment.size = 0.25, min.segment.length = 0, show.legend = FALSE) +
    scale_colour_manual(values = c(Original = ORIG_COLOUR, Variant = REFACTOR_COLOUR), name = "Survey snippets") +
    scale_shape_manual(values = c(Original = 16, Variant = 17), name = "Survey snippets") +
    labs(x = sprintf("PC1 (%.1f%% of the variance)", 100 * var_share[1]), y = sprintf("PC2 (%.1f%% of the variance)", 100 * var_share[2])) +
    theme_report() + theme(legend.box = "horizontal", legend.title = element_text(size = 8), legend.box.just = "bottom") +
    guides(colour = guide_legend(order = 1), shape = guide_legend(order = 1))
  save_fig(p_biplot, "diag_rq1_pca_biplot", height_cm = 11, rq = "RQ1",
           purpose = "PCA biplot: corpus density (30,000-method sample), loadings of the four metrics, and the 34 survey snippets (originals orange, variants blue); dashed ellipse holds 90% of corpus methods; only snippets outside it are labelled")

  # ---- b. All-tie pairs ---------------------------------------------------------------------------------------------
  all_tie <- rq2$all_tie
  what <- c(Q1C = "comments", Q2C = "Javadoc", Q5C = "naming", Q5D = "comments", Q5J = "naming vs comments", Q6B = "naming", Q7C = "comments")
  validate("all-tie forest: the seven all-tie pairs are the ones described in the snippet catalogue", setequal(all_tie$item, names(what)), paste(all_tie$item, collapse = ", "))
  at <- all_tie |>
    mutate(decisive = chose_A + chose_B, k = chose_B, share = k / decisive,
           label = sprintf("%s  %s vs %s (%s)", item, method_a_id, method_b_id, what[item]), pooled = FALSE)
  w <- t(mapply(function(k, n) wilson_ci(k, n), at$k, at$decisive))
  at$low <- w[, 1]; at$high <- w[, 2]
  tie_resp <- responses |> filter(item %in% all_tie$item)
  pool <- boot_ratio_ci(bh$W, bh$psum(tie_resp$human == 1 & tie_resp$human != 0, tie_resp$pid), bh$psum(tie_resp$human != 0, tie_resp$pid))
  pool_row <- tibble::tibble(item = "Pooled", label = "Pooled (participant bootstrap)", k = sum(tie_resp$human == 1), decisive = sum(tie_resp$human != 0),
                             share = sum(tie_resp$human == 1) / sum(tie_resp$human != 0), low = pool[["low"]], high = pool[["high"]], pooled = TRUE)
  fa <- bind_rows(at |> select(item, label, k, decisive, share, low, high, pooled), pool_row)
  validate("all-tie forest: pooled counts match the all-tie numbers recorded earlier (61 of 75)", pool_row$k == 61 && pool_row$decisive == 75,
           sprintf("%d of %d", pool_row$k, pool_row$decisive))
  save_table(fa, "rq2_all_tie_forest")
  record("all-tie pairs: pooled share of decisive responses preferring the later version (participant bootstrap interval)", pool_row$share, pool_row$low, pool_row$high,
         n = pool_row$k, denominator = pool_row$decisive, test = "participant cluster bootstrap 95% CI", section = "RQ2: all-tie pairs",
         note = sprintf("%d of the 7 pairs have a Wilson interval above 50%%", sum(at$low > 0.5)))
  fa <- fa |> arrange(pooled, desc(share)) |> mutate(label = factor(label, levels = rev(label)))
  p_alltie <- ggplot(fa, aes(share, label)) +
    geom_vline(xintercept = 0.5, linetype = "dashed", colour = "#777777", linewidth = 0.4) +
    geom_errorbar(aes(xmin = low, xmax = high, colour = pooled), width = 0.28, orientation = "y", linewidth = 0.55) +
    geom_point(aes(shape = pooled, colour = pooled, size = pooled)) +
    geom_text(aes(x = 1.02, label = sprintf("%d/%d", k, decisive)), hjust = 0, size = 2.7, family = FONT_FAMILY) +
    scale_colour_manual(values = c(`FALSE` = "#4D4D4D", `TRUE` = "#B2182B"), guide = "none") +
    scale_shape_manual(values = c(`FALSE` = 16, `TRUE` = 18), guide = "none") +
    scale_size_manual(values = c(`FALSE` = 2.2, `TRUE` = 4), guide = "none") +
    scale_x_continuous(labels = scales::label_percent(), limits = c(0, 1.12), breaks = seq(0, 1, 0.25), expand = c(0, 0)) +
    labs(x = "Share of decisive responses preferring the later version (B)", y = NULL) +
    theme_report() + theme(panel.grid.major.y = element_blank())
  save_fig(p_alltie, "diag_rq2_all_tie_forest", height_cm = 7, rq = "RQ2",
           purpose = "The seven pairs where CC, CogC, LOC and MaxNest all tie: share of decisive responses preferring the later version, with Wilson 95% CIs per pair and the pooled participant-bootstrap estimate in red; dashed line = 50%")

  save_figure_registry("12e_biplot_and_all_tie")
  save_numbers("12e_biplot_and_all_tie")
  save_validation("12e_biplot_and_all_tie")
  cat("Biplot and all-tie figures done\n")
})
