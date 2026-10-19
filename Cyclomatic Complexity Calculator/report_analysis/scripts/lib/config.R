# =============================================================================
# lib/config.R
# Paths, random seed, the four key metrics (one order, one name, one colour
# everywhere), report sections and plotting constants.
# =============================================================================

suppressPackageStartupMessages({
  library(readr)
  library(dplyr)
  library(tidyr)
  library(ggplot2)
  library(data.table)
})

stopifnot(dir.exists("data/survey"), dir.exists("data/survey/snippets"))

PATHS <- list(
  survey_raw  = "data/survey/survey_responses_raw.csv",
  pairs       = "data/survey/comparison_pairs.csv",
  snippets    = "data/survey/snippets/snippet_metrics.csv",
  catalogue   = "data/survey/snippets/snippet_catalogue.csv",
  corpus_dir  = "data/corpus",
  out         = "output",
  work        = "output/_pipeline"       # intermediate files passed between scripts, and the validation log
)
# Every figure and table is written to the folder of the report section it belongs to
SECTIONS <- c(data = "1_data_and_corpus", rq1 = "2_rq1_do_metrics_agree",
              rq2 = "3_rq2_agreement_with_programmers", rq3 = "4_rq3_refactoring")
for (d in c(file.path(rep(PATHS$out, 12), rep(SECTIONS, each = 3), c("important", "optional", "csv")), PATHS$work))
  dir.create(d, showWarnings = FALSE, recursive = TRUE)
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
