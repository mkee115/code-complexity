library(readr)
library(dplyr)
library(tidyr)
library(ggplot2)
library(data.table)

base <- "C:/Users/Bailey/OneDrive - The University of Auckland/2026/Part 4 Project/code-complexity/Cyclomatic Complexity Calculator/analysis"

config <- list(
  survey_csv = file.path(base, "Survey_Response_Analysis/700_survey.csv"),
  variant_metrics_csv = file.path(base, "Survey_Response_Analysis/variant_metrics.csv"),
  corpus_csv = file.path(base, "data_tables/cc_data.csv"),
  out_dir = file.path(base, "poster_figures"),
  min_progress = 100,
  labels = c(cc = "Cyclomatic Complexity", cognitive = "Cognitive Complexity", max_nesting = "Max Nesting Depth", loc = "Lines of Code"),
  short_labels = c(cc = "CC", cognitive = "Cognitive", max_nesting = "Max nesting", loc = "LOC"),
  variant_cols = c(group = "group", variant = "variant", cc = "cc", cognitive = "cognitive", max_nesting = "max_nesting", loc = "loc"),
  corpus_cols = c(cc = "cc", cognitive = "cognitive_complexity", max_nesting = "max_nesting", loc = "loc"),
  bg = "#F8F8F8",
  sizes = list(
    rq1_scree = c(8, 5),
    rq2_agreement = c(9, 5.5),
    rq2_gap = c(185, 84) / 25.4,
    rq3_winrate = c(165, 117) / 25.4,
    cc_distribution = c(130, 72) / 25.4,
    corr_heatmap = c(130, 72) / 25.4
  )
)

pal <- list(purple = "#5B2BB5", mid = "#A78BDA", light = "#D9CCF0", accent = "#C02AA8", grey = "#C2BDB4", dark_grey = "#6B6577")
key <- names(config$labels)
dir.create(config$out_dir, showWarnings = FALSE)

check_cols <- function(have, need, file) {
  missing <- setdiff(need, have)
  if (length(missing) > 0) {
    stop(basename(file), " is missing: ", paste(missing, collapse = ", "), "\nAvailable columns: ", paste(have, collapse = ", "), call. = FALSE)
  }
}

theme_original <- function() {
  theme_minimal(base_size = 11) +
    theme(
      plot.title = element_text(face = "bold", size = 13, hjust = 0.5),
      plot.subtitle = element_text(hjust = 0.5, colour = "#555555"),
      plot.background = element_rect(fill = config$bg, colour = NA),
      panel.grid.major = element_line(colour = "#E2E2E2", linewidth = 0.4),
      panel.grid.minor = element_blank(),
      axis.ticks = element_line(colour = "#777777"),
      axis.text = element_text(colour = "#444444"),
      legend.background = element_rect(fill = "white", colour = "#DDDDDD"),
      strip.text = element_text(face = "plain", size = 11, hjust = 0)
    )
}

theme_clear <- function() {
  theme_void(base_size = 11) +
    theme(axis.text = element_text(colour = "#444444"), legend.position = "none", plot.margin = margin(8, 8, 8, 8))
}

save_fig <- function(p, name, bg = config$bg) {
  s <- config$sizes[[name]]
  ggsave(file.path(config$out_dir, paste0(name, ".png")), p, width = s[1], height = s[2], units = "in", dpi = 300, bg = bg)
}

pairs <- tribble(
  ~item, ~a, ~b,
  "Q1A", "ORIG", "V1", "Q1B", "ORIG", "V2", "Q1C", "ORIG", "V3",
  "Q1D", "V1", "V2", "Q1E", "V1", "V3", "Q1F", "V2", "V3",
  "Q2A", "ORIG", "V1", "Q2B", "ORIG", "V2", "Q2C", "ORIG", "V3",
  "Q2D", "V1", "V2", "Q2E", "V1", "V3", "Q2F", "V2", "V3",
  "Q3A", "ORIG", "V1", "Q3B", "ORIG", "V2", "Q3C", "V1", "V2",
  "Q4A", "ORIG", "V1",
  "Q5A", "ORIG", "V1", "Q5B", "ORIG", "V2", "Q5C", "ORIG", "V3", "Q5D", "ORIG", "V4",
  "Q5E", "V1", "V2", "Q5F", "V1", "V3", "Q5G", "V1", "V4",
  "Q5H", "V2", "V3", "Q5I", "V2", "V4", "Q5J", "V3", "V4",
  "Q6A", "ORIG", "V1", "Q6B", "ORIG", "V2", "Q6C", "V1", "V2",
  "Q7A", "ORIG", "V1", "Q7B", "ORIG", "V2", "Q7C", "ORIG", "V3",
  "Q7D", "V1", "V2", "Q7E", "V1", "V3", "Q7F", "V2", "V3",
  "Q8A", "ORIG", "V1", "Q8B", "ORIG", "V2", "Q8C", "V1", "V2",
  "Q9A", "ORIG", "V1", "Q9B", "ORIG", "V2", "Q9C", "V1", "V2",
  "Q10A", "ORIG", "V1", "Q10B", "ORIG", "V2", "Q10C", "V1", "V2"
) |>
  mutate(group = as.integer(gsub("^Q|[A-Z]$", "", item)))

rating_labels <- c("Method A is much less complex", "Method A is slightly less complex", "No difference", "Method B is slightly less complex", "Method B is much less complex")

survey <- read_csv(config$survey_csv, col_types = cols(.default = col_character()), show_col_types = FALSE)[-(1:2), ]
check_cols(names(survey), c("Progress", "Status"), config$survey_csv)

long <- survey |>
  rename(any_of(c(Q7Fi_1 = "Q126_1"))) |>
  filter(as.numeric(Progress) >= config$min_progress, !Status %in% c("1", "Survey Preview")) |>
  mutate(rid = row_number()) |>
  select(rid, matches("^Q[0-9]+[A-Z]i_1$")) |>
  pivot_longer(-rid, names_to = "item", values_to = "rating") |>
  mutate(item = gsub("i_1", "", item, fixed = TRUE), rating = match(rating, rating_labels)) |>
  filter(!is.na(rating)) |>
  inner_join(pairs, by = "item")

vm_raw <- read_csv(config$variant_metrics_csv, show_col_types = FALSE)
check_cols(names(vm_raw), unname(config$variant_cols), config$variant_metrics_csv)

vm <- vm_raw |>
  rename(any_of(config$variant_cols)) |>
  mutate(group = as.integer(group)) |>
  select(group, variant, any_of(key)) |>
  pivot_longer(-c(group, variant), names_to = "metric", values_to = "value")

scored <- long |>
  inner_join(vm, by = c("group", "a" = "variant"), relationship = "many-to-many") |>
  inner_join(vm, by = c("group", "b" = "variant", "metric"), suffix = c("_a", "_b")) |>
  mutate(
    human = sign(rating - 3),
    predicted = sign(value_a - value_b),
    label = factor(config$labels[metric], levels = config$labels)
  )

agreement <- scored |>
  group_by(label) |>
  summarise(
    pct_decisive = 100 * mean((predicted == human)[human != 0]),
    pct_all = 100 * mean(predicted == human),
    n_decisive = sum(human != 0),
    pct_when_differs = 100 * mean((predicted == human)[human != 0 & predicted != 0]),
    n_when_differs = sum(human != 0 & predicted != 0),
    .groups = "drop"
  )
print(agreement)

basis_levels <- c("vs. all responses", "vs. decisive responses (excl. 'no difference')")

agree_long <- agreement |>
  mutate(label = reorder(label, pct_decisive)) |>
  select(label, pct_decisive, pct_all) |>
  pivot_longer(-label, names_to = "basis", values_to = "pct") |>
  mutate(basis = factor(ifelse(basis == "pct_all", basis_levels[1], basis_levels[2]), levels = basis_levels))

p_agree <- ggplot(agree_long, aes(pct, label, fill = basis)) +
  geom_col(position = position_dodge(width = 0.8), width = 0.75) +
  geom_text(aes(label = paste0(round(pct), "%")), position = position_dodge(width = 0.8), hjust = -0.2, size = 3, colour = "#444444") +
  geom_vline(xintercept = 50, linetype = "dashed", colour = "#888888") +
  annotate("text", x = 50, y = Inf, label = "chance", vjust = -0.3, size = 3, colour = "#888888") +
  scale_fill_manual(values = setNames(c(pal$light, pal$purple), basis_levels), name = NULL) +
  scale_x_continuous(limits = c(0, 100), breaks = seq(0, 100, 20)) +
  guides(fill = guide_legend(reverse = TRUE)) +
  coord_cartesian(clip = "off") +
  labs(title = "Which complexity metric best predicts perceived complexity?", x = "Agreement with participants' choice (%)", y = NULL) +
  theme_original() +
  theme(legend.position = c(0.8, 0.08), legend.text = element_text(size = 8.5), legend.key.size = unit(0.4, "cm"), panel.grid.major.y = element_blank(), plot.title = element_text(margin = margin(b = 14)))
save_fig(p_agree, "rq2_agreement")

gap <- scored |>
  filter(metric %in% c("cc", "cognitive")) |>
  mutate(
    strength = factor(c("No difference", "Slightly", "Much")[abs(rating - 3) + 1], levels = c("No difference", "Slightly", "Much")),
    gap = abs(value_a - value_b)
  )

gap_box <- gap |>
  group_by(label, strength) |>
  summarise(s = list(boxplot.stats(gap)$stats), .groups = "drop") |>
  mutate(ymin = sapply(s, `[`, 1), lower = sapply(s, `[`, 2), middle = sapply(s, `[`, 3), upper = sapply(s, `[`, 4), ymax = sapply(s, `[`, 5))

p_gap <- ggplot(gap_box, aes(strength, fill = strength)) +
  geom_errorbar(aes(ymin = ymin, ymax = ymax), width = 0.25, colour = "#333333") +
  geom_boxplot(aes(ymin = ymin, lower = lower, middle = middle, upper = upper, ymax = ymax), stat = "identity", width = 0.5, colour = "#333333", median.linewidth = 0.8) +
  facet_wrap(~label, scales = "free_y") +
  scale_fill_manual(values = c(pal$grey, pal$mid, pal$purple), guide = "none") +
  labs(title = "Bigger metric gaps -> stronger stated preference?", x = "How strongly the response favoured one side", y = "|Δ metric| between the two methods shown") +
  theme_original() +
  theme(plot.title = element_text(hjust = 0), panel.spacing.x = unit(1.5, "lines"), panel.grid.major.x = element_blank())
save_fig(p_gap, "rq2_gap")

winrate <- bind_rows(
  long |> transmute(group, variant = a, win = c(1, 1, 0.5, 0, 0)[rating]),
  long |> transmute(group, variant = b, win = c(0, 0, 0.5, 1, 1)[rating])
) |>
  group_by(group, variant) |>
  summarise(win_rate = 100 * mean(win), n = n(), .groups = "drop") |>
  mutate(
    label = reorder(sprintf("%02d-%s", group, variant), win_rate),
    kind = ifelse(variant == "ORIG", "Original", "Refactored variant")
  )

p_rq3 <- ggplot(winrate, aes(win_rate, label, fill = kind)) +
  geom_col(width = 0.7) +
  geom_text(aes(label = paste0(round(win_rate), "%")), hjust = -0.2, size = 2.4, colour = "#444444") +
  geom_vline(xintercept = 50, linetype = "dashed", colour = "#888888") +
  scale_fill_manual(values = c(Original = pal$accent, `Refactored variant` = pal$purple), name = NULL) +
  scale_x_continuous(limits = c(0, 100), breaks = seq(0, 100, 20), expand = c(0, 0)) +
  labs(
    title = "Every code variant, ranked by how often it was judged less complex",
    x = "Share of comparisons judged less complex (%, ties split 50/50)", y = NULL
  ) +
  theme_original() +
  theme(
    axis.text.y = element_text(size = 7), panel.grid.major.y = element_blank(),
    legend.position = c(0.85, 0.08), legend.text = element_text(size = 8), legend.key.size = unit(0.3, "cm"),
    plot.margin = margin(5.5, 14, 5.5, 5.5), plot.title = element_text(size = 11.5)
  )
save_fig(p_rq3, "rq3_winrate")

check_cols(names(fread(config$corpus_csv, nrows = 0)), unname(config$corpus_cols), config$corpus_csv)
corpus <- fread(config$corpus_csv, select = unname(config$corpus_cols))
setnames(corpus, unname(config$corpus_cols), names(config$corpus_cols))

band_labels <- c("1", "2-5", "6-10", "11-20", "21+")
bands <- corpus[, .N, by = .(band = cut(cc, c(0, 1, 5, 10, 20, Inf), labels = band_labels))][order(band)]
bands[, `:=`(pct = 100 * N / sum(N), over = band %in% c("11-20", "21+"))]

p_cc <- ggplot(bands, aes(band, pct, fill = over)) +
  geom_col(width = 0.6) +
  geom_text(aes(label = sprintf(ifelse(pct < 10, "%.1f%%", "%.0f%%"), pct)), vjust = -0.4, size = 3, colour = "#444444") +
  scale_fill_manual(values = c(`FALSE` = pal$purple, `TRUE` = pal$accent), guide = "none") +
  scale_y_continuous(expand = expansion(mult = c(0, 0.12))) +
  labs(x = "Cyclomatic Complexity") +
  theme_clear() +
  theme(axis.text.y = element_blank(), axis.title.x = element_text(colour = "#444444", size = 17, margin = margin(t = 8)))
save_fig(p_cc, "cc_distribution", bg = "transparent")

ord <- c("loc", "cc", "cognitive", "max_nesting")
cm <- cor(corpus[, ..ord], use = "pairwise.complete.obs")
print(round(cm, 2))

heat <- as.data.frame(as.table(cm)) |>
  setNames(c("row", "col", "r")) |>
  filter(match(col, ord) <= match(row, ord)) |>
  mutate(
    row = factor(config$short_labels[as.character(row)], levels = rev(config$short_labels[ord])),
    col = factor(config$short_labels[as.character(col)], levels = config$short_labels[ord])
  )

p_heat <- ggplot(heat, aes(col, row, fill = r)) +
  geom_tile(width = 0.94, height = 0.94) +
  geom_text(aes(label = sprintf("%.2f", r), colour = r > 0.6), size = 3.5) +
  scale_fill_gradient(low = pal$light, high = pal$purple, limits = c(0.3, 1)) +
  scale_colour_manual(values = c(`TRUE` = "white", `FALSE` = "#333333")) +
  scale_x_discrete(labels = function(x) sub(" ", "\n", x)) +
  theme_clear()
save_fig(p_heat, "corr_heatmap", bg = "transparent")

pca_cols <- c("cc", "cognitive", "loc", "max_nesting")
check_cols(names(vm_raw), pca_cols, config$variant_metrics_csv)

pca <- prcomp(vm_raw[pca_cols], center = TRUE, scale. = TRUE)
scree <- tibble(
  pc = factor(paste0("PC", seq_along(pca$sdev)), levels = paste0("PC", seq_along(pca$sdev))),
  var = 100 * pca$sdev^2 / sum(pca$sdev^2),
  cum = cumsum(var)
)
print(scree)

p_rq1 <- ggplot(scree, aes(pc)) +
  geom_col(aes(y = var, fill = "% variance"), width = 0.6) +
  geom_text(data = filter(scree, var >= 15), aes(y = var, label = paste0(round(var), "%")), vjust = 1.6, size = 3, colour = "white", fontface = "bold") +
  geom_text(data = filter(scree, var < 15), aes(y = var, label = paste0(round(var), "%")), vjust = -0.6, size = 3, colour = "#444444") +
  geom_line(aes(y = cum, colour = "Cumulative %", group = 1), linewidth = 0.9) +
  geom_point(aes(y = cum, colour = "Cumulative %"), size = 2) +
  geom_text(aes(y = cum, label = paste0(round(cum), "%")), vjust = -1, size = 3, colour = pal$accent, fontface = "bold") +
  scale_fill_manual(values = pal$purple, name = NULL) +
  scale_colour_manual(values = pal$accent, name = NULL) +
  scale_y_continuous(limits = c(0, 108), breaks = seq(0, 100, 20), expand = c(0, 0)) +
  labs(title = sprintf("Scree plot: all %d principal components of the complexity metrics", length(pca_cols)), x = NULL, y = "% variance explained") +
  theme_original() +
  theme(
    legend.position = c(0.82, 0.45), legend.spacing.y = unit(0, "pt"),
    legend.background = element_blank(), legend.box.background = element_rect(fill = "white", colour = "#DDDDDD"),
    panel.grid.major.x = element_blank()
  )
save_fig(p_rq1, "rq1_scree")