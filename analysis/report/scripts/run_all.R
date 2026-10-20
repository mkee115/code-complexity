# =============================================================================
# run_all.R
# Runs the whole report analysis in order. Run from the R project (analysis/report/):
#     source("scripts/run_all.R")
# or from a terminal:  Rscript scripts/run_all.R
# Every output is regenerated; the output folders are emptied first so nothing stale remains.
# =============================================================================

if (!dir.exists("scripts") && dir.exists("../scripts")) setwd("..")
if (!dir.exists("scripts") && dir.exists("analysis/report/scripts")) setwd("analysis/report")

for (d in list.dirs("output", recursive = FALSE))
  unlink(d, recursive = TRUE)
for (f in c("output/report_numbers.csv", "output/figure_index.csv", "output/sessionInfo.txt"))
  if (file.exists(f)) file.remove(f)

steps <- c(
  "scripts/01_load_data.R",         # load and validate the survey and the corpus
  "scripts/02_analysis.R",          # RQ1, RQ2, RQ3 and sensitivity analyses
  "scripts/03_figures.R",           # all figures, plus the extra RQ2 robustness analyses
  "scripts/04_tables_and_export.R"  # tables, report numbers, figure index, validation log, privacy scan
)
t0 <- Sys.time()
for (s in steps) {
  message("\n==== ", s, " ====")
  source(s, local = new.env())
}
message("\nFinished in ", round(difftime(Sys.time(), t0, units = "mins"), 1), " minutes")
