# =============================================================================
# 00_setup.R
# Every analysis script starts with source("scripts/00_setup.R"). It loads the
# shared configuration and helpers from scripts/lib/ (run from analysis/report/).
# =============================================================================

if (!dir.exists("scripts/lib") && dir.exists("../scripts/lib")) setwd("..")
if (!dir.exists("scripts/lib") && dir.exists("analysis/report/scripts/lib")) setwd("analysis/report")
for (f in c("config", "plot_output", "checks_numbers", "stats"))
  source(file.path("scripts/lib", paste0(f, ".R")))
