# =============================================================================
# lib/checks_numbers.R
# The validation log (every data check must pass) and the report-number
# register (every quoted number is recorded through record()).
# =============================================================================

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
