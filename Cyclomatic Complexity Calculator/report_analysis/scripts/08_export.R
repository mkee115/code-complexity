# =============================================================================
# 08_export.R
# Combines everything: report_numbers.csv, the validation log, the figure index,
# sessionInfo.txt; then a privacy scan of every output file.
# =============================================================================

source("scripts/00_setup.R")

# ---- report_numbers.csv --------------------------------------------------------------------
parts <- list.files(PATHS$work, pattern = "^numbers_.*\\.csv$", full.names = TRUE)
numbers <- bind_rows(lapply(parts, read_csv, show_col_types = FALSE, col_types = cols(.default = "c"))) |>
  mutate(across(c(value, ci_low, ci_high, n, denominator, p), ~ suppressWarnings(as.numeric(.x))))
validate("report_numbers: every number has a name and a section", !anyNA(numbers$name) && !anyNA(numbers$section))
key <- c("name", "subset", "section", "denominator", "n")
validate("report_numbers: no duplicated entries", !anyDuplicated(numbers[key]),
         paste(sum(duplicated(numbers[key])), "duplicates"))
write_csv(numbers, "output/report_numbers.csv")
cat(nrow(numbers), "numbers recorded from", length(parts), "scripts\n")

# ---- Figure index ----------------------------------------------------------------------------------
fparts <- list.files(PATHS$work, pattern = "^figures_.*\\.csv$", full.names = TRUE)
index <- bind_rows(lapply(fparts, read_csv, show_col_types = FALSE, col_types = cols(.default = "c")))
tk_file <- "scripts/figure_takeaways.csv"
if (file.exists(tk_file)) {
  index <- index |> left_join(read_csv(tk_file, show_col_types = FALSE, col_types = cols(.default = "c")), by = "figure")
} else {
  index$takeaway <- NA
  index$suggested_use <- NA
}
index <- index |> arrange(folder != "figures", figure)
on_disk <- c(list.files(PATHS$figures, pattern = "\\.png$"), list.files(PATHS$diagnostics, pattern = "^(fig|diag).*\\.png$"))
validate("every figure on disk is in the figure index", all(on_disk %in% index$figure), paste(setdiff(on_disk, index$figure), collapse = ", "))
validate("every figure has a suggested takeaway", !anyNA(index$takeaway), paste(index$figure[is.na(index$takeaway)], collapse = ", "),
         stop_on_fail = FALSE)
write_csv(index, "output/figure_index.csv")

# ---- Session info -------------------------------------------------------------------------------------
writeLines(capture.output(sessionInfo()), "output/sessionInfo.txt")

# ---- Privacy scan: no identifying survey information anywhere in the outputs ----------------------------
bad_cols <- c("IPAddress", "LocationLatitude", "LocationLongitude", "RecipientEmail", "RecipientFirstName",
              "RecipientLastName", "ResponseId", "ExternalReference")
files <- list.files("output", pattern = "\\.(csv|txt)$", recursive = TRUE, full.names = TRUE)
files <- files[!grepl("sessionInfo", files)]
ip_pattern <- "(^|[^0-9.])[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}($|[^0-9.])"
hits <- character()
for (f in files) {
  if (any(grepl(ip_pattern, readLines(f, warn = FALSE)))) hits <- c(hits, paste(f, "(IP-like value)"))
  if (grepl("\\.csv$", f) && any(bad_cols %in% names(read_csv(f, n_max = 0, show_col_types = FALSE))))
    hits <- c(hits, paste(f, "(identifying column)"))
}
validate("no identifying survey columns or IP addresses in any output file", length(hits) == 0, paste(hits, collapse = "; "))

# ---- Validation log: all scripts plus the checks above ---------------------------------------------------
vparts <- list.files(PATHS$work, pattern = "^validation_.*\\.csv$", full.names = TRUE)
vlog <- bind_rows(c(lapply(vparts, read_csv, show_col_types = FALSE, col_types = cols(.default = "c")),
                       lapply(.checks$rows, function(x) mutate(x, passed = as.character(passed))))) |>
  mutate(passed = as.character(passed) == "TRUE")
write_csv(vlog, file.path(PATHS$diagnostics, "validation_log.csv"))
cat(sprintf("Validation log: %d checks, %d not passed\n", nrow(vlog), sum(!vlog$passed)))
if (any(!vlog$passed)) print(vlog |> filter(!passed) |> select(check, detail))
cat("Export complete\n")
