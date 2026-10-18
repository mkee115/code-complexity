# =============================================================================
# 14_export.R
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
index <- index |> arrange(folder, desc(importance), figure)
on_disk <- basename(list.files(file.path(PATHS$out, SECTIONS), pattern = "^(fig|diag).*[.]png$", recursive = TRUE))
validate("every figure on disk is in the figure index", all(on_disk %in% index$figure), paste(setdiff(on_disk, index$figure), collapse = ", "))
validate("every figure has a suggested takeaway", !anyNA(index$takeaway), paste(index$figure[is.na(index$takeaway)], collapse = ", "),
         stop_on_fail = FALSE)
write_csv(index, "output/figure_index.csv")

# One folder with a copy of every main and supporting figure, for viewing them together. Files are prefixed with
# their report section number so they sort in report order (the originals stay where they are).
view_dir <- file.path(PATHS$out, "figures_main_and_supporting")
unlink(view_dir, recursive = TRUE); dir.create(view_dir, recursive = TRUE)
to_copy <- index |> filter(suggested_use %in% c("main", "supporting")) |>
  mutate(src = file.path(PATHS$out, folder, importance, figure), dest = file.path(view_dir, paste0(substr(folder, 1, 1), "_", figure)))
validate("main and supporting figures: every source file exists", all(file.exists(to_copy$src)), paste(to_copy$figure[!file.exists(to_copy$src)], collapse = ", "))
file.copy(to_copy$src, to_copy$dest)
# ... and the version without title and subtitle, next to each one (suffix _no_title). A figure that never had a
# title or subtitle gives an identical file, so only the figures where the two versions differ get a second copy.
nt <- to_copy |> mutate(src_nt = file.path(PATHS$out, "figures_no_titles", folder, figure),
                        dest_nt = sub("[.]png$", "_no_title.png", dest))
validate("main and supporting figures: every title-free version exists", all(file.exists(nt$src_nt)),
         paste(nt$figure[!file.exists(nt$src_nt)], collapse = ", "))
differs <- unname(tools::md5sum(nt$src)) != unname(tools::md5sum(nt$src_nt))
file.copy(nt$src_nt[differs], nt$dest_nt[differs])
cat(sprintf("Copied %d main and supporting figures to %s, plus %d title-free versions\n", nrow(to_copy), view_dir, sum(differs)))

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
vparts <- list.files(PATHS$work, pattern = "^validation_[0-9].*\\.csv$", full.names = TRUE)
vlog <- bind_rows(c(lapply(vparts, read_csv, show_col_types = FALSE, col_types = cols(.default = "c")),
                       lapply(.checks$rows, function(x) mutate(x, passed = as.character(passed))))) |>
  mutate(passed = as.character(passed) == "TRUE")
write_csv(vlog, file.path(PATHS$work, "validation_log.csv"))
cat(sprintf("Validation log: %d checks, %d not passed\n", nrow(vlog), sum(!vlog$passed)))
if (any(!vlog$passed)) print(vlog |> filter(!passed) |> select(check, detail))
cat("Export complete\n")
