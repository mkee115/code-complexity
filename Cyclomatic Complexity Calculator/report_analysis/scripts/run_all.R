# =============================================================================
# run_all.R
# Runs the whole report analysis in order. Run from the R project (report_analysis/):
#     source("scripts/run_all.R")
# or from a terminal:  Rscript scripts/run_all.R
# Every output is regenerated; the output folders are emptied first so nothing stale remains.
# =============================================================================

if (!dir.exists("data") && dir.exists("../data")) setwd("..")

for (d in c("output/figures", "output/diagnostics", "output/tables", "output/work"))
  if (dir.exists(d)) unlink(list.files(d, full.names = TRUE), recursive = TRUE)
for (f in c("output/report_numbers.csv", "output/figure_index.csv", "output/sessionInfo.txt"))
  if (file.exists(f)) file.remove(f)

steps <- c(
  "scripts/01_load_survey.R",
  "scripts/02_corpus.R",
  "scripts/03_rq1_corpus.R",
  "scripts/03_rq1_survey.R",
  "scripts/04_rq2.R",
  "scripts/04b_rq2_grids.R",
  "scripts/05_rq3.R",
  "scripts/06_sensitivity.R",
  "scripts/07_figures.R",
  "scripts/07_tables.R",
  "scripts/08_export.R"
)
t0 <- Sys.time()
for (s in steps) {
  message("\n==== ", s, " ====")
  source(s, local = new.env())
}
message("\nFinished in ", round(difftime(Sys.time(), t0, units = "mins"), 1), " minutes")
