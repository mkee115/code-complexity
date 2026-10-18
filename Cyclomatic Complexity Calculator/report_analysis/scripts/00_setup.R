# =============================================================================
# 00_setup.R
# Every analysis script starts with source("scripts/00_setup.R"). It loads the
# shared configuration and helpers from scripts/lib/ (run from report_analysis/).
# =============================================================================

if (!dir.exists("scripts/lib") && dir.exists("../scripts/lib")) setwd("..")
for (f in c("config", "plot_output", "checks_numbers", "stats"))
  source(file.path("scripts/lib", paste0(f, ".R")))
