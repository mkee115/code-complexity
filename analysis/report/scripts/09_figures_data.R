# =============================================================================
# 09_figures_data.R
# Section 1 (data and corpus): the corpus distributions and the position check.
# Figures are PNG, 300 dpi, A4 text width, written to the output folder of their report
# section (see section_of in lib/plot_output.R). Supporting and appendix figures are named
# diag_*. The one-sentence takeaway for each figure is in scripts/figure_takeaways.csv.
# =============================================================================

source("scripts/00_setup.R")
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
