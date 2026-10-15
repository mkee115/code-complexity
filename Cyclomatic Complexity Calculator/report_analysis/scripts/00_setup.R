# =============================================================================
# 00_setup.R
# Shared setup for the report analysis: packages, paths, seed, metric order
# and colours, figure and table helpers, validation log, report-number
# recording, and the bootstrap/concordance helpers used by every other script.
# Every script sources this first. Run from the R project (report_analysis/).
# =============================================================================

suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
  library(tidyr)
  library(ggplot2)
  library(data.table)
})

# Work from report_analysis/ whether run from the project or from scripts/
if (!dir.exists("data") && dir.exists("../data")) setwd("..")
stopifnot(dir.exists("data/survey"), dir.exists("data/survey/snippets"))

PATHS <- list(
  survey_raw  = "data/survey/survey_responses_raw.csv",
  pairs       = "data/survey/comparison_pairs.csv",
  snippets    = "data/survey/snippets/snippet_metrics.csv",
  catalogue   = "data/survey/snippets/snippet_catalogue.csv",
  corpus_dir  = "data/corpus",
  figures     = "output/figures",        # report-ready figures
  diagnostics = "output/diagnostics",    # exploratory / diagnostic figures, validation log
  tables      = "output/tables",         # CSV results and table PNGs
  work        = "output/work"            # intermediate files shared between scripts
)
for (d in PATHS[c("figures", "diagnostics", "tables", "work")]) dir.create(d, showWarnings = FALSE, recursive = TRUE)

SEED <- 2026
N_BOOT <- 10000
ALPHA <- 0.05

# ---- Metrics: one order, one name, one colour everywhere ---------------------
METRICS <- c("cc", "cognitive", "loc", "max_nesting")
METRIC_LABELS <- c(cc = "CC", cognitive = "CogC", loc = "LOC", max_nesting = "MaxNest")
METRIC_COLOURS <- c(CC = "#E69F00", CogC = "#0072B2", LOC = "#009E73", MaxNest = "#CC79A7")  # Okabe-Ito
metric_factor <- function(x) factor(METRIC_LABELS[x], levels = METRIC_LABELS)

# Original vs refactored variants (a separate scheme from the metric colours)
ORIG_COLOUR <- "#D55E00"
REFACTOR_COLOUR <- "#56B4E9"

# Response / outcome categories use greys and a blue-orange diverging pair, not metric colours
OUTCOME_RIGHT <- "#2166AC"; OUTCOME_WRONG <- "#B2182B"; OUTCOME_TIE <- "#EF8A62"
OUTCOME_NODIFF <- "#BDBDBD"; OUTCOME_BOTH_NODIFF <- "#636363"

# ---- Figures: A4 text width (16 cm), serif font, 300 dpi PNG only ------------
TEXT_WIDTH_CM <- 16
FONT_FAMILY <- "serif"

theme_report <- function(base_size = 9.5) {
  theme_minimal(base_size = base_size, base_family = FONT_FAMILY) +
    theme(
      panel.grid.minor = element_blank(),
      panel.grid.major = element_line(colour = "#E5E5E5", linewidth = 0.3),
      axis.text = element_text(colour = "#333333"),
      axis.title = element_text(colour = "#222222"),
      strip.text = element_text(face = "bold", hjust = 0),
      plot.title = element_text(face = "bold", size = base_size + 1.5),
      plot.subtitle = element_text(colour = "#444444", size = base_size - 0.5),
      plot.title.position = "plot",
      legend.position = "bottom",
      legend.title = element_blank(),
      plot.margin = margin(4, 6, 4, 4)
    )
}

# main = TRUE writes to output/figures (report candidates); FALSE to output/diagnostics
.registry <- new.env()
.registry$figs <- list()
save_fig <- function(plot, name, height_cm, width_cm = TEXT_WIDTH_CM, main = TRUE,
                     rq = NA, purpose = NA) {
  dir <- if (main) PATHS$figures else PATHS$diagnostics
  ggsave(file.path(dir, paste0(name, ".png")), plot, width = width_cm, height = height_cm,
         units = "cm", dpi = 300, bg = "white")
  .registry$figs[[name]] <- tibble::tibble(figure = paste0(name, ".png"),
    folder = basename(dir), research_question = rq, purpose = purpose)
  invisible(name)
}

save_table <- function(df, name) {
  write_csv(df, file.path(PATHS$tables, paste0(name, ".csv")))
  invisible(df)
}

# Render a small table as a PNG (for tables that go straight into the report)
table_png <- function(df, name, title = NULL, subtitle = NULL, width_cm = TEXT_WIDTH_CM,
                      main = TRUE, left_cols = 1, wrap_note = NULL) {
  df <- as.data.frame(lapply(df, as.character), stringsAsFactors = FALSE, check.names = FALSE)
  df[is.na(df)] <- ""
  nr <- nrow(df); nc <- ncol(df)
  chars <- vapply(seq_len(nc), function(j) max(nchar(c(names(df)[j], df[[j]])), 3), numeric(1))
  w <- chars + 2.2
  pt <- min(9, 0.92 * (width_cm / sum(w)) / 0.0176)
  if (pt < 6.5) {                       # widen the table rather than shrink the text
    pt <- 6.5
    width_cm <- sum(w) * 0.0176 * 6.5 / 0.92
  } else if (pt >= 9) {                 # narrow table: fit to its content
    width_cm <- sum(w) * 0.0176 * 9 / 0.92
  }
  xr <- cumsum(w); xl <- c(0, head(xr, -1)); xc <- (xl + xr) / 2
  row_h <- pt * 0.0353 * 1.9                         # cm
  title_h <- (if (!is.null(title)) 0.9 else 0) + (if (!is.null(subtitle)) 0.55 else 0)
  height_cm <- (nr + 1) * row_h + title_h + 0.3 + (if (!is.null(wrap_note)) 0.55 else 0)
  cells <- tibble::tibble(
    row = rep(seq_len(nr), times = nc), col = rep(seq_len(nc), each = nr),
    label = unlist(df, use.names = FALSE),
    x = ifelse(col <= left_cols, xl[col] + 0.6, xc[col]),
    hj = ifelse(col <= left_cols, 0, 0.5))
  head <- tibble::tibble(col = seq_len(nc), label = names(df),
                         x = ifelse(col <= left_cols, xl[col] + 0.6, xc[col]),
                         hj = ifelse(col <= left_cols, 0, 0.5))
  zebra <- tibble::tibble(row = seq_len(nr)[seq_len(nr) %% 2 == 0])
  mm <- pt / 2.845
  p <- ggplot() +
    annotate("rect", xmin = 0, xmax = sum(w), ymin = 0, ymax = 1, fill = "#E4E4E4") +
    geom_rect(data = zebra, aes(xmin = 0, xmax = sum(w), ymin = row, ymax = row + 1), fill = "#F6F6F6") +
    geom_text(data = head, aes(x, 0.5, label = label, hjust = hj), family = FONT_FAMILY,
              fontface = "bold", size = mm) +
    geom_text(data = cells, aes(x, row + 0.5, label = label, hjust = hj), family = FONT_FAMILY, size = mm) +
    annotate("segment", x = 0, xend = sum(w), y = c(0, 1, nr + 1), yend = c(0, 1, nr + 1),
             colour = "#555555", linewidth = 0.3) +
    scale_y_reverse(limits = c(nr + 1, 0), expand = c(0, 0)) +
    scale_x_continuous(limits = c(0, sum(w)), expand = c(0, 0)) +
    labs(title = title, subtitle = subtitle, caption = wrap_note) +
    theme_void(base_family = FONT_FAMILY) +
    theme(plot.title = element_text(face = "bold", size = pt + 1.5, margin = margin(b = 3)),
          plot.subtitle = element_text(size = pt - 0.5, colour = "#444444", margin = margin(b = 4)),
          plot.caption = element_text(size = pt - 1, colour = "#444444", hjust = 0, margin = margin(t = 4)),
          plot.title.position = "plot", plot.caption.position = "plot",
          plot.margin = margin(4, 6, 4, 6))
  dir <- if (main) PATHS$tables else PATHS$diagnostics
  ggsave(file.path(dir, paste0("tbl_", name, ".png")), p, width = width_cm, height = height_cm,
         units = "cm", dpi = 300, bg = "white", limitsize = FALSE)
  invisible(df)
}

# ---- Validation log: every data check is recorded and must pass --------------
.checks <- new.env()
.checks$rows <- list()
validate <- function(name, passed, detail = "", stop_on_fail = TRUE) {
  passed <- isTRUE(passed)
  .checks$rows[[length(.checks$rows) + 1]] <- tibble::tibble(
    check = name, passed = passed, detail = as.character(detail), time = format(Sys.time(), "%Y-%m-%d %H:%M"))
  cat(sprintf("[%s] %s%s\n", if (passed) "PASS" else "FAIL", name,
              if (nzchar(detail)) paste0(": ", detail) else ""))
  if (!passed && stop_on_fail) stop("Validation failed: ", name, ". ", detail, call. = FALSE)
  invisible(passed)
}
save_validation <- function(script) {
  out <- bind_rows(.checks$rows)
  write_csv(out, file.path(PATHS$work, paste0("validation_", script, ".csv")))
  .checks$rows <- list()
  invisible(out)
}
save_figure_registry <- function(script) {
  out <- bind_rows(.registry$figs)
  if (nrow(out)) write_csv(out, file.path(PATHS$work, paste0("figures_", script, ".csv")))
  .registry$figs <- list()
}

# ---- Report numbers: every quoted number goes through record() ---------------
.numbers <- new.env()
.numbers$rows <- list()

record <- function(name, value, ci_low = NA, ci_high = NA, n = NA, denominator = NA, test = NA,
                   p = NA, section = NA, subset = NA, note = NA) {
  .numbers$rows[[length(.numbers$rows) + 1]] <- tibble::tibble(
    name = name, value = value, ci_low = ci_low, ci_high = ci_high, n = n, denominator = denominator,
    test = test, p = p, section = section, subset = subset, note = note)
  invisible(value)
}

save_numbers <- function(script) {
  out <- bind_rows(.numbers$rows)
  write_csv(out, file.path(PATHS$work, paste0("numbers_", script, ".csv")))
  .numbers$rows <- list()
  invisible(out)
}

# ---- Participant-level cluster bootstrap -------------------------------------
# Responses from one participant are not independent, so CIs resample whole
# participants. boot_weights() gives an N_BOOT x P matrix of how many times each
# participant appears in each resample; any ratio of per-participant sums can
# then be bootstrapped with one matrix multiplication.
boot_weights <- function(n_participants, n_boot = N_BOOT, seed = SEED) {
  set.seed(seed)
  idx <- matrix(sample.int(n_participants, n_participants * n_boot, replace = TRUE), nrow = n_boot)
  t(apply(idx, 1, tabulate, nbins = n_participants))
}

# Per-participant sum of x (participants with no rows in the subset contribute 0)
participant_sum <- function(x, pid, pids) {
  s <- tapply(as.numeric(x), factor(pid, levels = pids), sum)
  s[is.na(s)] <- 0
  as.vector(s)
}

# Percentile CI of a ratio of sums: numerator / denominator per participant
boot_ratio_ci <- function(W, num, den, level = 0.95) {
  est <- as.vector((W %*% num) / (W %*% den))
  q <- quantile(est, c((1 - level) / 2, 1 - (1 - level) / 2), na.rm = TRUE)
  c(low = unname(q[1]), high = unname(q[2]))
}

# Wilson score interval for a proportion (x may be fractional when a
# "No difference" counts as half a win)
wilson_ci <- function(x, n, level = 0.95) {
  z <- qnorm(1 - (1 - level) / 2)
  p <- x / n
  centre <- (p + z^2 / (2 * n)) / (1 + z^2 / n)
  half <- z * sqrt(p * (1 - p) / n + z^2 / (4 * n^2)) / (1 + z^2 / n)
  c(low = centre - half, high = centre + half)
}

pct <- function(x, digits = 0) sprintf(paste0("%.", digits, "f%%"), 100 * x)
fmt_p <- function(p) ifelse(is.na(p), "", ifelse(p < 0.001, "< .001", sub("^0", "", sprintf("%.3f", p))))
fmt_ci <- function(est, lo, hi, digits = 1) sprintf(paste0("%.", digits, "f%% (%.", digits, "f–%.", digits, "f)"),
                                                      100 * est, 100 * lo, 100 * hi)

# ---- RQ1: pairwise concordance between two metrics ---------------------------
# For one pair of methods, two metrics are concordant if they order the methods
# the same way, discordant if they order them oppositely; otherwise one metric
# separates the methods while the other ties (a resolution difference), or both
# tie. s1, s2 are sign(value_a - value_b) under each metric.
CONCORDANCE_LEVELS <- c("Concordant", "One ties, other separates", "Both tie", "Discordant")
CONCORDANCE_COLOURS <- c("Concordant" = "#2166AC", "One ties, other separates" = "#EF8A62",
                         "Both tie" = "#BDBDBD", "Discordant" = "#B2182B")
concordance_class <- function(s1, s2) {
  out <- ifelse(s1 == 0 & s2 == 0, "Both tie",
         ifelse(s1 == 0 | s2 == 0, "One ties, other separates",
         ifelse(s1 == s2, "Concordant", "Discordant")))
  factor(out, levels = CONCORDANCE_LEVELS)
}
METRIC_PAIRS <- utils::combn(METRICS, 2, simplify = FALSE)
metric_pair_label <- function(m1, m2) paste(METRIC_LABELS[m1], METRIC_LABELS[m2], sep = " – ")
