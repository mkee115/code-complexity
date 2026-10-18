# =============================================================================
# run_all.R
# Runs the whole report analysis in order. Run from the R project (report_analysis/):
#     source("scripts/run_all.R")
# or from a terminal:  Rscript scripts/run_all.R
# Every output is regenerated; the output folders are emptied first so nothing stale remains.
# =============================================================================

if (!dir.exists("data") && dir.exists("../data")) setwd("..")

for (d in list.dirs("output", recursive = FALSE))
  unlink(d, recursive = TRUE)
for (f in c("output/report_numbers.csv", "output/figure_index.csv", "output/sessionInfo.txt"))
  if (file.exists(f)) file.remove(f)

steps <- c(
  # load and validate the data
  "scripts/01_load_survey.R",
  "scripts/02_load_corpus.R",
  # analyses
  "scripts/03_rq1_corpus.R",
  "scripts/04_rq1_survey.R",
  "scripts/05_rq2_agreement.R",
  "scripts/06_rq2_grids.R",
  "scripts/07_rq3_refactoring.R",
  "scripts/08_sensitivity.R",
  # figures (one script per report section) and tables
  "scripts/09_figures_data.R",
  "scripts/10_figures_rq1.R",
  "scripts/11_figures_rq2.R",
  "scripts/12_figures_rq3.R",
  # extra RQ2 robustness analyses and their figures
  "scripts/12a_task_robustness.R",
  "scripts/12b_commit_rate_and_measures.R",
  "scripts/12c_ordinal_models.R",
  "scripts/12d_forest_and_tie_bars.R",
  "scripts/12e_biplot_and_all_tie.R",
  "scripts/13_tables.R",
  # report numbers, figure index, privacy scan, validation log
  "scripts/14_export.R"
)
t0 <- Sys.time()
for (s in steps) {
  message("\n==== ", s, " ====")
  source(s, local = new.env())
}
message("\nFinished in ", round(difftime(Sys.time(), t0, units = "mins"), 1), " minutes")
