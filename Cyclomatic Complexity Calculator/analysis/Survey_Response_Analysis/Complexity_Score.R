################################################################################
#  Code-Readability Survey — Complexity Score (0-400)
#  ---------------------------------------------------------------------------
#  Turns the pairwise "which is easier to understand?" ratings into a single
#  0-400 complexity score for every individual code snippet.
#
#  This is a SEPARATE, self-contained script from analyse_survey.R. Run either
#  independently. It reads the same Qualtrics CSV.
#
#  HOW TO RUN
#    Rscript complexity_score.R          (or open in RStudio and Source)
#  Missing packages install themselves the first time.
#
#  ---------------------------------------------------------------------------
#  THE SCORING RULE (as specified)
#  ---------------------------------------------------------------------------
#  Each comparison rates two snippets on a 1-5 scale, where Method A is always
#  the LOWER version and Method B the HIGHER version of that pair:
#      1 = A much less complex     2 = A slightly less complex
#      3 = no difference
#      4 = B slightly less complex 5 = B much less complex
#
#  We convert "how complex is THIS snippet" onto a 0-400 axis:
#      much LESS complex   -> 0
#      slightly less       -> 100
#      neutral             -> 200
#      slightly more       -> 300
#      much MORE complex   -> 400
#
#  So from snippet A's point of view the rating maps straight through:
#      A_value(rating) = (rating - 1) * 100        # 1->0 ... 5->400
#  From snippet B's point of view the axis is FLIPPED (B after A in the pair):
#      B_value(rating) = (5 - rating) * 100        # 1->400 ... 5->0
#
#  For one comparison we take the PROPORTION of respondents at each rating
#  (neutral included) and multiply by the mapped value, then sum:
#      comparison_score = sum_over_ratings( proportion * value )
#  giving one 0-400 number for A and one for B in that comparison.
#
#  A snippet is in several comparisons (one per other snippet in its group).
#  Its FINAL score is the mean of its comparison scores, over the comparisons
#  that actually received responses (empty comparisons are skipped).
################################################################################


## ============================================================================
## 0. LOCATE THIS SCRIPT  — so paths work no matter the working directory
## ============================================================================
## When you source() a file, R does NOT move the working directory into the
## script's folder, so a bare "700_survey.csv" is looked for wherever your
## console happens to be pointing. This block finds the folder THIS script
## lives in and anchors every path to it, so the CSV (which sits next to the
## script) and the output folders are always found.
##
## It works whether you Source in RStudio, run with Rscript, or source() from
## the console. If all detection fails it falls back to getwd() with a note.

get_script_dir <- function() {
  # 1) Rscript:  --file=/path/to/script.R
  a <- commandArgs(FALSE)
  m <- grep("^--file=", a, value = TRUE)
  if (length(m)) return(dirname(normalizePath(sub("^--file=", "", m[1]))))
  # 2) source():  the sourced path is stored on the call stack
  for (k in sys.nframe():1) {
    of <- sys.function(k)
    sf <- attr(of, "srcref")
    if (!is.null(sf)) {
      f <- attr(sf, "srcfile")
      if (!is.null(f) && !is.null(f$filename) && nzchar(f$filename))
        return(dirname(normalizePath(f$filename)))
    }
  }
  # 3) RStudio Source button
  if (requireNamespace("rstudioapi", quietly = TRUE) &&
      rstudioapi::isAvailable()) {
    p <- tryCatch(rstudioapi::getSourceEditorContext()$path, error = function(e) "")
    if (nzchar(p)) return(dirname(normalizePath(p)))
  }
  message("NOTE: couldn't detect the script folder; using working directory: ", getwd())
  getwd()
}

script_dir <- get_script_dir()
message("Script folder: ", script_dir)


## ============================================================================
## 1. CONFIG
## ============================================================================
## csv_file and out_dir are resolved RELATIVE TO THE SCRIPT FOLDER (above),
## so you can leave them as bare names as long as the CSV sits beside this
## script. To point elsewhere, use an absolute path — that is honoured as-is.
config <- list(
  csv_file = "700_survey.csv",
  out_dir  = "complexity_output",
  
  # Data-quality filters (kept consistent with analyse_survey.R).
  require_finished = TRUE,
  min_duration_sec = 0,
  
  make_plots  = TRUE,
  plot_width  = 10,
  plot_height = 7
)

# Anchor relative paths to the script folder; leave absolute paths as given.
resolve_path <- function(p) if (grepl("^(/|[A-Za-z]:|\\\\\\\\)", p)) p else file.path(script_dir, p)
config$csv_file <- resolve_path(config$csv_file)
config$out_dir  <- resolve_path(config$out_dir)

# Helpful error if the CSV still isn't there, naming what IS in the folder.
if (!file.exists(config$csv_file)) {
  csvs <- list.files(script_dir, pattern = "\\.csv$", ignore.case = TRUE)
  stop("Could not find the CSV at:\n  ", config$csv_file,
       "\n\nCSV files found next to the script:\n  ",
       if (length(csvs)) paste(csvs, collapse = "\n  ") else "(none)",
       "\n\nFix: set config$csv_file to one of those names (or an absolute path).")
}


## ============================================================================
## 2. PAIR MAP  — every comparison item -> its group and its two snippets
## ============================================================================
## item      = Qualtrics stem (matches the "<item>i_1" rating column)
## group     = problem number (1-10)
## problem   = short task name
## snippet_a = the LOWER version in this pair  (scored with A_value)
## snippet_b = the HIGHER version in this pair (scored with B_value, flipped)
##
## The set of snippets in a group is inferred from this table, so if you add a
## version or a pair in Qualtrics, just add the row(s) here.

pair_map <- read.csv(text = "
item,group,problem,snippet_a,snippet_b
Q1A,1,Letter grade,ORIG,V1
Q1B,1,Letter grade,ORIG,V2
Q1C,1,Letter grade,ORIG,V3
Q1D,1,Letter grade,V1,V2
Q1E,1,Letter grade,V1,V3
Q1F,1,Letter grade,V2,V3
Q2A,2,Password check,ORIG,V1
Q2B,2,Password check,ORIG,V2
Q2C,2,Password check,ORIG,V3
Q2D,2,Password check,V1,V2
Q2E,2,Password check,V1,V3
Q2F,2,Password check,V2,V3
Q3A,3,Sum of digits,ORIG,V1
Q3B,3,Sum of digits,ORIG,V2
Q3C,3,Sum of digits,V1,V2
Q4A,4,Max in 2D array,ORIG,V1
Q5A,5,Remove duplicates,ORIG,V1
Q5B,5,Remove duplicates,ORIG,V2
Q5C,5,Remove duplicates,ORIG,V3
Q5D,5,Remove duplicates,ORIG,V4
Q5E,5,Remove duplicates,V1,V2
Q5F,5,Remove duplicates,V1,V3
Q5G,5,Remove duplicates,V1,V4
Q5H,5,Remove duplicates,V2,V3
Q5I,5,Remove duplicates,V2,V4
Q5J,5,Remove duplicates,V3,V4
Q6A,6,Frequency count,ORIG,V1
Q6B,6,Frequency count,ORIG,V2
Q6C,6,Frequency count,V1,V2
Q7A,7,Merge sorted arrays,ORIG,V1
Q7B,7,Merge sorted arrays,ORIG,V2
Q7C,7,Merge sorted arrays,ORIG,V3
Q7D,7,Merge sorted arrays,V1,V2
Q7E,7,Merge sorted arrays,V1,V3
Q8A,8,Roman numeral,ORIG,V1
Q8B,8,Roman numeral,ORIG,V2
Q8C,8,Roman numeral,V1,V2
Q9A,9,Binary search,ORIG,V1
Q9B,9,Binary search,ORIG,V2
Q9C,9,Binary search,V1,V2
Q10A,10,Balanced brackets,ORIG,V1
Q10B,10,Balanced brackets,ORIG,V2
Q10C,10,Balanced brackets,ORIG,V3
", stringsAsFactors = FALSE, strip.white = TRUE)


## ============================================================================
## 2b. STATIC METRICS  (for the normalised grouped bar chart)
## ============================================================================
## One row per method; snippets with helpers have several rows. Aggregated to
## one value per snippet below: CC & Cognitive SUMMED, MaxNest MAX. Halstead
## intentionally omitted. Update these rows if the metric table changes.

metrics_raw <- read.csv(text = "
ID,method,CC,Cognitive,MaxNest
01-ORIG,grade,5,14,4
01-V1,grade,5,4,1
01-V2,grade,5,5,4
01-V3,grade,5,4,0
02-ORIG,check,6,2,1
02-V1,check,6,5,1
02-V2,check,4,1,0
02-V2,hasMinLength,1,0,0
02-V2,hasLowerAndUpper,2,1,0
02-V2,hasDigit,1,0,0
02-V3,check,6,2,1
03-ORIG,sd,3,4,1
03-V1,sd,2,1,1
03-V2,sd,3,4,1
04-ORIG,max,4,6,3
04-V1,max,4,6,3
05-ORIG,dedupe,5,8,3
05-V1,dedupe,3,3,2
05-V2,dedupe,1,0,0
05-V3,removeDuplicates,5,8,3
06-ORIG,tally,3,4,2
06-V1,tally,2,1,1
06-V2,countByValue,3,4,2
07-ORIG,merge,6,7,2
07-V1,merge,4,5,2
07-V2,merge,1,0,0
07-V3,merge,6,7,2
08-ORIG,roman,4,8,3
08-ORIG,value,8,1,1
08-V1,roman,4,5,2
08-V1,value,8,1,1
08-V2,roman,3,4,2
08-V2,value,8,1,1
09-ORIG,bs,4,8,3
09-V1,bs,4,5,3
09-V2,bs,2,1,0
10-ORIG,balanced,15,28,4
10-V1,balanced,6,10,4
10-V2,balanced,6,8,4
10-V2,matches,1,0,0
10-V3,balanced,15,28,4
", stringsAsFactors = FALSE, strip.white = TRUE)


## ============================================================================
## 3. SETUP
## ============================================================================
ensure_pkg <- function(pkg) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    message("Installing missing package: ", pkg)
    install.packages(pkg, repos = "https://cloud.r-project.org")
  }
}
ensure_pkg("openxlsx")               # writes the multi-sheet workbook with all math
if (config$make_plots) ensure_pkg("ggplot2")
library(openxlsx)

dir.create(config$out_dir, showWarnings = FALSE, recursive = TRUE)
# Per-mode subfolders (normal / decisive) are created inside emit_mode() below.

# Rating -> value maps, defined once.
A_value <- function(r) (r - 1) * 100     # snippet A perspective
B_value <- function(r) (5 - r) * 100     # snippet B perspective (flipped)

rating_names <- c("much_less", "slightly_less", "neutral", "slightly_more", "much_more")

## ----------------------------------------------------------------------------
## Rating normaliser: Qualtrics can export this question as NUMERIC codes (1-5)
## or as CHOICE TEXT ("Method A is much less complex", ...). This maps either
## form to the 1-5 scale used everywhere below:
##   1 = A much less complex ... 3 = No difference ... 5 = B much less complex
## Unrecognised values become NA (and are counted/reported so nothing is lost
## silently).
## ----------------------------------------------------------------------------
parse_rating <- function(x) {
  raw_chr <- trimws(as.character(x))
  out <- rep(NA_real_, length(raw_chr))
  
  # a) already numeric 1-5?
  as_num <- suppressWarnings(as.numeric(raw_chr))
  ok_num <- !is.na(as_num) & as_num %in% 1:5
  out[ok_num] <- as_num[ok_num]
  
  # b) choice text -> code. Match leniently: lowercase, collapse spaces, and
  #    key off "method a/b" + "much/slightly" + "no difference".
  t <- tolower(raw_chr)
  t <- gsub("\\s+", " ", t)
  is_txt <- is.na(out) & nzchar(t)
  out[is_txt & grepl("method a", t) & grepl("much", t)]     <- 1
  out[is_txt & grepl("method a", t) & grepl("slight", t)]   <- 2
  out[is_txt & grepl("no difference|neither|same|equal", t)]<- 3
  out[is_txt & grepl("method b", t) & grepl("slight", t)]   <- 4
  out[is_txt & grepl("method b", t) & grepl("much", t)]     <- 5
  out
}


## ============================================================================
## 4. LOAD & CLEAN
## ============================================================================
## Qualtrics writes THREE header lines (column names, question text, ImportId
## JSON) and then respondents. Free-text answers often contain NEWLINES inside
## quotes, so one respondent's record can span several physical lines. That is
## why a line-based `skip = 3` corrupts the data — it can stop mid-record and
## knock every column out of alignment (the symptom: Finished stops being 1).
##
## The fix: read the file WITH its real header (so quoting/embedded newlines are
## honoured), then drop the first TWO data rows (the metadata) by POSITION.

message("Reading: ", config$csv_file)

read_qualtrics <- function(path) {
  # One parse, respecting RFC-4180 quoting (handles newlines inside quotes).
  d <- utils::read.csv(path, header = TRUE, check.names = FALSE,
                       stringsAsFactors = FALSE, colClasses = "character",
                       quote = "\"", fill = TRUE, na.strings = c("", "NA"))
  # Strip a UTF-8 BOM that Windows exports sometimes prepend to the 1st name.
  names(d)[1] <- sub("^\ufeff", "", names(d)[1])
  # Rows 1-2 are Qualtrics metadata (question text + ImportId). Drop by position.
  meta_rows <- min(2L, nrow(d))
  if (meta_rows > 0) d <- d[-seq_len(meta_rows), , drop = FALSE]
  rownames(d) <- NULL
  d
}

raw <- read_qualtrics(config$csv_file)
if (nrow(raw) == 0)
  stop("No respondent rows after dropping the 2 Qualtrics metadata rows.")

# Guard: confirm the Finished column exists and looks sane. If almost nothing
# is 1, the file probably parsed misaligned — tell the user rather than
# silently filtering everyone out.
if (!"Finished" %in% names(raw))
  stop("No 'Finished' column found. Column names read were:\n  ",
       paste(utils::head(names(raw), 12), collapse = ", "), " ...")

num <- function(x) suppressWarnings(as.numeric(x))
raw$Duration_sec <- num(raw[["Duration (in seconds)"]])

# Finished may be exported as 1/0 (numeric export) OR True/False (text export).
# Normalise both to a logical, then to 1/0.
parse_finished <- function(x) {
  x <- trimws(tolower(as.character(x)))
  out <- rep(NA, length(x))
  out[x %in% c("1", "true", "t", "yes", "finished")] <- 1
  out[x %in% c("0", "false", "f", "no", "")]        <- 0
  out
}
raw$Finished_num <- parse_finished(raw[["Finished"]])

n_finished <- sum(raw$Finished_num == 1, na.rm = TRUE)
if (config$require_finished && n_finished == 0) {
  warning("The 'Finished' column has no completed responses after parsing. ",
          "Distinct values seen: ",
          paste(utils::head(unique(raw[["Finished"]]), 10), collapse = ", "),
          ".\nProceeding WITHOUT the finished filter so you can see the data. ",
          "Set config$require_finished <- FALSE to silence this.")
  config$require_finished <- FALSE
}

resp <- raw
if (config$require_finished)
  resp <- resp[!is.na(resp$Finished_num) & resp$Finished_num == 1, , drop = FALSE]
if (config$min_duration_sec > 0)
  resp <- resp[is.na(resp$Duration_sec) |
                 resp$Duration_sec >= config$min_duration_sec, , drop = FALSE]
message(sprintf("Respondents kept: %d of %d (%d marked finished).",
                nrow(resp), nrow(raw), n_finished))
if (nrow(resp) == 0) stop("All respondents filtered out; loosen CONFIG filters.")


## ============================================================================
## 5. PER-COMPARISON MATH
## ============================================================================
## For each item: tally counts at ratings 1-5, turn into proportions (neutral
## included), and compute the A-side and B-side 0-400 scores. Items with zero
## responses are dropped (skipped), per spec.

# Sanity check: how many rating cells fail to map to 1-5 (excluding blanks)?
.all_rating_cols <- paste0(pair_map$item, "i_1")
.all_rating_cols <- .all_rating_cols[.all_rating_cols %in% names(resp)]
.rawvals <- unlist(resp[.all_rating_cols], use.names = FALSE)
.rawvals <- .rawvals[!is.na(.rawvals) & nzchar(trimws(.rawvals))]
.parsed  <- parse_rating(.rawvals)
if (any(is.na(.parsed))) {
  bad <- unique(.rawvals[is.na(.parsed)])
  warning("Some rating values were not recognised and will be ignored: ",
          paste(utils::head(bad, 8), collapse = " | "),
          if (length(bad) > 8) sprintf(" (+%d more)", length(bad) - 8) else "")
}

per_comparison <- do.call(rbind, lapply(seq_len(nrow(pair_map)), function(i) {
  it   <- pair_map$item[i]
  col  <- paste0(it, "i_1")
  if (!col %in% names(resp)) return(NULL)
  r    <- parse_rating(resp[[col]])
  r    <- r[!is.na(r)]
  n    <- length(r)
  if (n == 0) return(NULL)                      # skip unanswered comparison
  
  cnt  <- sapply(1:5, function(k) sum(r == k))  # counts at each rating
  prop <- cnt / n                               # proportions incl. neutral
  a_score <- sum(prop * A_value(1:5))
  b_score <- sum(prop * B_value(1:5))
  
  # --- DECISIVE variant: drop neutral (rating 3), rescale to 0/100/200/300 ---
  # much less->0, slightly less->100, slightly more->200, much more->300.
  # Proportions are taken over DECISIVE votes only, so the denominator is the
  # non-neutral count (n_dec) and often < n. A comparison with no decisive
  # votes contributes nothing (NA) and is skipped in the decisive average.
  n_dec <- n - cnt[3]
  if (n_dec > 0) {
    dec_prop  <- c(cnt[1], cnt[2], cnt[4], cnt[5]) / n_dec   # ml, sl, sm, mm
    a_dec <- sum(dec_prop * c(0, 100, 200, 300))             # A perspective
    b_dec <- sum(dec_prop * c(300, 200, 100, 0))             # B perspective (flip)
  } else {
    a_dec <- NA_real_; b_dec <- NA_real_
  }
  
  data.frame(
    group     = pair_map$group[i],
    problem   = pair_map$problem[i],
    item      = it,
    snippet_a = pair_map$snippet_a[i],
    snippet_b = pair_map$snippet_b[i],
    n         = n,
    n_decisive = n_dec,
    # raw counts
    n_much_less = cnt[1], n_slightly_less = cnt[2], n_neutral = cnt[3],
    n_slightly_more = cnt[4], n_much_more = cnt[5],
    # proportions (of the A->B reading)
    p_much_less = round(prop[1], 3), p_slightly_less = round(prop[2], 3),
    p_neutral = round(prop[3], 3), p_slightly_more = round(prop[4], 3),
    p_much_more = round(prop[5], 3),
    # the two directional scores (normal, 0-400)
    A_score = round(a_score, 1),
    B_score = round(b_score, 1),
    # decisive directional scores (0-300, neutral excluded)
    A_score_decisive = round(a_dec, 1),
    B_score_decisive = round(b_dec, 1),
    stringsAsFactors = FALSE
  )
}))

if (is.null(per_comparison) || nrow(per_comparison) == 0)
  stop("No answered comparisons found. Is the survey empty, or columns renamed?")

message(sprintf("Answered comparisons: %d of %d.",
                nrow(per_comparison), nrow(pair_map)))


## ============================================================================
## 6. EXPAND TO ONE ROW PER (SNIPPET, COMPARISON)
## ============================================================================
## Each answered comparison contributes a score to BOTH of its snippets: the
## A-side score to snippet_a, the (flipped) B-side score to snippet_b. This is
## the table the final per-snippet average is built from — it shows exactly
## which comparisons feed each snippet and with what value.

a_side <- data.frame(
  group = per_comparison$group, problem = per_comparison$problem,
  snippet = per_comparison$snippet_a, role = "A (lower)",
  item = per_comparison$item,
  vs = per_comparison$snippet_b, n = per_comparison$n,
  score = per_comparison$A_score,
  score_decisive = per_comparison$A_score_decisive,
  n_decisive = per_comparison$n_decisive,
  stringsAsFactors = FALSE)

b_side <- data.frame(
  group = per_comparison$group, problem = per_comparison$problem,
  snippet = per_comparison$snippet_b, role = "B (higher)",
  item = per_comparison$item,
  vs = per_comparison$snippet_a, n = per_comparison$n,
  score = per_comparison$B_score,
  score_decisive = per_comparison$B_score_decisive,
  n_decisive = per_comparison$n_decisive,
  stringsAsFactors = FALSE)

contributions <- rbind(a_side, b_side)
ver_order <- c(ORIG = 0, V1 = 1, V2 = 2, V3 = 3, V4 = 4)
contributions <- contributions[order(contributions$group,
                                     ver_order[contributions$snippet],
                                     contributions$item), ]
rownames(contributions) <- NULL


## ============================================================================
## 7. FINAL PER-SNIPPET SCORE  (mean over answered comparisons)
## ============================================================================
final <- do.call(rbind, lapply(
  split(contributions, list(contributions$group, contributions$snippet), drop = TRUE),
  function(d) {
    # Decisive: weighted mean over decisive votes (weight = n_decisive), using
    # only comparisons that had at least one decisive vote.
    dec_ok <- !is.na(d$score_decisive) & d$n_decisive > 0
    dec_score <- if (any(dec_ok))
      sum(d$score_decisive[dec_ok] * d$n_decisive[dec_ok]) / sum(d$n_decisive[dec_ok])
    else NA_real_
    data.frame(
      group          = d$group[1],
      problem        = d$problem[1],
      snippet        = d$snippet[1],
      n_comparisons  = nrow(d),                 # comparisons that had data
      total_responses = sum(d$n),               # respondents summed across them
      sum_of_scores  = round(sum(d$score), 1),
      complexity_score = round(mean(d$score), 1),          # NORMAL (0-400)
      decisive_responses = sum(d$n_decisive[dec_ok]),
      complexity_score_decisive = round(dec_score, 1),     # DECISIVE (0-300)
      stringsAsFactors = FALSE)}))
final <- final[order(final$group, ver_order[final$snippet]), ]
rownames(final) <- NULL

# Rank within each problem (1 = simplest).
final$rank_in_group <- ave(final$complexity_score, final$group,
                           FUN = function(x) rank(x, ties.method = "min"))


## ============================================================================
## 8. AGGREGATE STATIC METRICS  (one value per snippet, for comparison charts)
## ============================================================================
metrics_raw$group   <- as.integer(sub("-.*$", "", metrics_raw$ID))
metrics_raw$version <- sub("^[^-]*-", "", metrics_raw$ID)
snip_metrics <- do.call(rbind, lapply(split(metrics_raw, metrics_raw$ID), function(d)
  data.frame(group = d$group[1], snippet = d$version[1],
             Cyclomatic = sum(d$CC), Cognitive = sum(d$Cognitive),
             MaxNest = max(d$MaxNest), stringsAsFactors = FALSE)))

# min-max normaliser across all snippets (global 0-1); flat vectors -> 0.5
norm_global <- function(v) {
  rng <- range(v, na.rm = TRUE)
  if (diff(rng) == 0) return(ifelse(is.na(v), NA, 0.5))
  (v - rng[1]) / diff(rng)
}


## ============================================================================
## 9. EMIT EACH MODE  (normal / decisive) into its own subfolder
## ============================================================================
## Everything below is produced ONCE PER MODE. The only difference between the
## two folders is which survey score is used:
##   normal   -> complexity_score          (0-400, neutrals included)
##   decisive -> complexity_score_decisive (0-300, neutrals excluded)
## Each folder gets: the workbook, CSVs, the single-metric survey chart
## (01_final_scores_by_problem.png), one clustered survey-vs-metric chart per
## static metric, plus the response-split and version-trend charts.

have_ggplot <- config$make_plots && requireNamespace("ggplot2", quietly = TRUE)
if (config$make_plots && !have_ggplot)
  message("ggplot2 unavailable; skipping plots. Workbooks and CSVs still written.")

# shared workbook styles
hdr <- createStyle(textDecoration = "bold", fgFill = "#1F3864",
                   fontColour = "white", halign = "center", border = "TopBottomLeftRight",
                   borderColour = "#BFBFBF", wrapText = TRUE)
body_style <- createStyle(border = "TopBottomLeftRight", borderColour = "#E0E0E0",
                          valign = "top")
score_style <- createStyle(numFmt = "0.0", halign = "center")

emit_mode <- function(mode) {
  stopifnot(mode %in% c("normal", "decisive"))
  is_dec     <- mode == "decisive"
  score_col  <- if (is_dec) "complexity_score_decisive" else "complexity_score"
  axis_max   <- if (is_dec) 300 else 400
  mid        <- if (is_dec) 150 else 200
  score_desc <- if (is_dec) "decisive (0-300, neutral votes excluded)"
  else "normal (0-400, neutral votes included)"
  
  out_dir  <- file.path(config$out_dir, mode)
  plot_dir <- file.path(out_dir, "plots")
  dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)
  if (have_ggplot) dir.create(plot_dir, showWarnings = FALSE, recursive = TRUE)
  
  # This mode's per-snippet score, with a stable name for plotting/joins.
  fin <- final
  fin$snippet <- factor(fin$snippet, levels = names(ver_order))
  fin$grp_lab <- sprintf("Q%d %s", fin$group, fin$problem)
  fin$score   <- fin[[score_col]]
  
  ## ---- 9.1 workbook + CSVs ------------------------------------------------
  wb <- createWorkbook()
  add_sheet <- function(name, df, note = NULL) {
    addWorksheet(wb, name); start <- 1
    if (!is.null(note)) {
      writeData(wb, name, note, startRow = 1)
      mergeCells(wb, name, cols = 1:min(8, ncol(df)), rows = 1)
      addStyle(wb, name, createStyle(textDecoration = "italic", fontColour = "#555555"),
               rows = 1, cols = 1, gridExpand = TRUE)
      start <- 3
    }
    writeData(wb, name, df, startRow = start, headerStyle = hdr, withFilter = TRUE)
    addStyle(wb, name, body_style, rows = (start + 1):(start + nrow(df)),
             cols = 1:ncol(df), gridExpand = TRUE, stack = TRUE)
    setColWidths(wb, name, cols = 1:ncol(df), widths = "auto")
    freezePane(wb, name, firstActiveRow = start + 1)
  }
  
  readme <- data.frame(Field = c(
    "This folder", "Survey score used", "Scale (rating 1-5)",
    "Normal axis (0-400)", "Decisive axis (0-300)",
    "Comparison score", "Final snippet score", "Empty comparisons",
    "Clustered charts"),
    Explanation = c(
      sprintf("The '%s' variant. Identical to the other folder except for the survey score.", mode),
      score_desc,
      "1=A much less complex, 2=A slightly less, 3=no difference, 4=B slightly less, 5=B much less complex. A=lower version, B=higher version.",
      "NORMAL: 0=much LESS complex, 100=slightly less, 200=neutral, 300=slightly more, 400=much MORE complex. Proportions include neutral.",
      "DECISIVE: neutral DROPPED; remaining votes map much less->0, slightly less->100, slightly more->200, much more->300; proportions over decisive votes only; per-snippet value is a weighted mean over comparisons (weight = decisive vote count).",
      "sum over ratings of ( proportion * value ), per comparison.",
      "mean of a snippet's comparison scores, over comparisons that received responses.",
      "Comparisons with zero responses are skipped.",
      "01 = survey score per snippet. 04/05/06 = survey vs one static metric (Cyclomatic/Cognitive/Max nesting), each min-max normalised so bar heights are comparable."),
    stringsAsFactors = FALSE)
  add_sheet("README", readme)
  
  fin_cols <- c("group","problem","snippet","n_comparisons",
                "total_responses","complexity_score","decisive_responses",
                "complexity_score_decisive","rank_in_group")
  add_sheet("Final scores", fin[, fin_cols],
            note = sprintf("Per-snippet scores. This folder's charts use the %s score.", mode))
  add_sheet("Comparison math", per_comparison,
            note = "One row per answered comparison: counts, proportions, and both normal (0-400) and decisive (0-300) A/B scores.")
  add_sheet("Snippet contributions", contributions,
            note = "One row per (snippet, comparison). Final scores are means of the 'score' (normal) / weighted means of 'score_decisive' rows here.")
  
  hl <- which(fin_cols %in% c("complexity_score","complexity_score_decisive"))
  addStyle(wb, "Final scores", score_style,
           rows = 4:(3 + nrow(fin)), cols = hl,
           gridExpand = TRUE, stack = TRUE)
  
  saveWorkbook(wb, file.path(out_dir, "complexity_scores.xlsx"), overwrite = TRUE)
  write.csv(fin,            file.path(out_dir, "final_scores.csv"),          row.names = FALSE)
  write.csv(per_comparison, file.path(out_dir, "comparison_math.csv"),       row.names = FALSE)
  write.csv(contributions,  file.path(out_dir, "snippet_contributions.csv"), row.names = FALSE)
  
  if (!have_ggplot) { message("Wrote tables for '", mode, "'."); return(invisible()) }
  library(ggplot2)
  
  ## ---- 9.2 chart 01: survey score only, faceted by problem (as before) ----
  p1 <- ggplot(fin, aes(x = snippet, y = score, fill = score)) +
    geom_col(width = 0.7) +
    geom_hline(yintercept = mid, linetype = "dashed", colour = "grey45") +
    geom_text(aes(label = round(score)), vjust = -0.4, size = 3) +
    facet_wrap(~ grp_lab, scales = "free_x") +
    scale_fill_gradient2(low = "#1b7837", mid = "#f7f7f7", high = "#b2182b",
                         midpoint = mid, limits = c(0, axis_max), name = "Score") +
    scale_y_continuous(limits = c(0, axis_max * 1.05),
                       breaks = seq(0, axis_max, 100)) +
    labs(title = sprintf("Complexity score per code snippet (0-%d)", axis_max),
         subtitle = sprintf("%s. 0 = simplest, %d = most complex. Dashed line = neutral (%d).",
                            tools::toTitleCase(score_desc), axis_max, mid),
         x = NULL, y = "Complexity score") +
    theme_minimal(base_size = 11) +
    theme(plot.title = element_text(face = "bold"),
          panel.grid.major.x = element_blank())
  ggsave(file.path(plot_dir, "01_final_scores_by_problem.png"), p1,
         width = config$plot_width, height = config$plot_height, dpi = 150)
  
  ## ---- 9.3 charts 04-06: survey vs EACH static metric, clustered ----------
  # Join metrics onto this mode's score, normalise both to 0-1 globally so the
  # two bars per snippet are comparable heights. One chart per metric.
  fin_chr <- fin; fin_chr$snippet <- as.character(fin_chr$snippet)
  cmp <- merge(fin_chr[, c("group","problem","grp_lab","snippet","score")],
               snip_metrics, by = c("group","snippet"), all.x = TRUE)
  cmp$Survey_n     <- norm_global(cmp$score)
  cmp$Cyclomatic_n <- norm_global(cmp$Cyclomatic)
  cmp$Cognitive_n  <- norm_global(cmp$Cognitive)
  cmp$MaxNest_n    <- norm_global(cmp$MaxNest)
  
  metric_defs <- list(
    list(col = "Cyclomatic_n", nm = "Cyclomatic",  colour = "#d6604d", file = "04_survey_vs_cyclomatic.png"),
    list(col = "Cognitive_n",  nm = "Cognitive",   colour = "#f4a582", file = "05_survey_vs_cognitive.png"),
    list(col = "MaxNest_n",    nm = "Max nesting", colour = "#762a83", file = "06_survey_vs_maxnest.png"))
  
  for (md in metric_defs) {
    long_m <- rbind(
      data.frame(cmp[c("group","grp_lab","snippet")],
                 metric = "Survey", value = cmp$Survey_n, stringsAsFactors = FALSE),
      data.frame(cmp[c("group","grp_lab","snippet")],
                 metric = md$nm,    value = cmp[[md$col]], stringsAsFactors = FALSE))
    long_m$metric  <- factor(long_m$metric, levels = c("Survey", md$nm))
    long_m$snippet <- factor(long_m$snippet, levels = names(ver_order))
    
    pm <- ggplot(long_m, aes(x = snippet, y = value, fill = metric)) +
      geom_col(position = position_dodge(width = 0.8), width = 0.75) +
      facet_wrap(~ grp_lab, scales = "free_x") +
      scale_fill_manual(values = setNames(c("#2166ac", md$colour), c("Survey", md$nm)),
                        name = NULL) +
      scale_y_continuous(limits = c(0, 1.05), breaks = c(0, 0.5, 1)) +
      labs(title = sprintf("Survey complexity vs %s", md$nm),
           subtitle = sprintf("%s survey score. Both min-max normalised across all snippets (0 = lowest, 1 = highest).",
                              tools::toTitleCase(mode)),
           x = NULL, y = "Normalised height (0-1)") +
      theme_minimal(base_size = 11) +
      theme(plot.title = element_text(face = "bold"),
            legend.position = "bottom",
            panel.grid.major.x = element_blank(),
            axis.text.x = element_text(size = 8))
    ggsave(file.path(plot_dir, md$file), pm,
           width = config$plot_width, height = config$plot_height, dpi = 150)
  }
  
  ## ---- 9.4 chart 02: response split per comparison ------------------------
  split_df <- do.call(rbind, lapply(seq_len(nrow(per_comparison)), function(i) {
    pc <- per_comparison[i, ]
    data.frame(
      item = pc$item,
      pair = sprintf("Q%d %s: %s vs %s", pc$group, pc$problem, pc$snippet_a, pc$snippet_b),
      category = factor(rating_names, levels = rating_names),
      proportion = as.numeric(pc[paste0("p_", rating_names)]),
      stringsAsFactors = FALSE)
  }))
  cat_labels <- c(much_less = "A much less complex", slightly_less = "A slightly less",
                  neutral = "No difference", slightly_more = "B slightly less",
                  much_more = "B much less complex")
  # In decisive mode, drop the neutral band and renormalise to decisive votes.
  if (is_dec) {
    split_df <- split_df[split_df$category != "neutral", ]
    split_df$proportion <- ave(split_df$proportion, split_df$pair,
                               FUN = function(p) if (sum(p) > 0) p / sum(p) else p)
    cat_labels <- cat_labels[names(cat_labels) != "neutral"]
  }
  split_df$pair <- factor(split_df$pair, levels = rev(unique(split_df$pair)))
  band_cols <- c(much_less = "#1b7837", slightly_less = "#a6dba0",
                 neutral = "#bdbdbd", slightly_more = "#f4a582", much_more = "#b2182b")
  p2 <- ggplot(split_df, aes(x = proportion, y = pair, fill = category)) +
    geom_col(width = 0.75) +
    scale_fill_manual(values = band_cols[names(cat_labels)], labels = cat_labels, name = NULL) +
    scale_x_continuous(labels = function(x) paste0(x * 100, "%")) +
    labs(title = "Response split for every comparison",
         subtitle = if (is_dec) "Decisive votes only (neutral excluded, renormalised)."
         else "Green = lower version (A) called simpler; red = higher version (B) called simpler.",
         x = "Share of respondents", y = NULL) +
    theme_minimal(base_size = 10) +
    theme(legend.position = "bottom", plot.title = element_text(face = "bold"))
  ggsave(file.path(plot_dir, "02_comparison_response_split.png"), p2,
         width = config$plot_width, height = max(7, 0.32 * nrow(per_comparison)),
         dpi = 150, limitsize = FALSE)
  
  ## ---- 9.5 chart 03: score across versions per problem --------------------
  p3 <- ggplot(fin, aes(x = snippet, y = score, group = grp_lab, colour = grp_lab)) +
    geom_line(alpha = 0.6) + geom_point(size = 2) +
    geom_hline(yintercept = mid, linetype = "dashed", colour = "grey60") +
    scale_y_continuous(limits = c(0, axis_max), breaks = seq(0, axis_max, 100)) +
    labs(title = "Complexity across versions, by problem",
         subtitle = "Do later versions (refactors) score lower than ORIG?",
         x = "Version", y = "Complexity score", colour = NULL) +
    theme_minimal(base_size = 11) +
    theme(plot.title = element_text(face = "bold"))
  ggsave(file.path(plot_dir, "03_score_across_versions.png"), p3,
         width = config$plot_width, height = config$plot_height, dpi = 150)
  
  message(sprintf("Wrote '%s' folder: workbook, CSVs, and %d plots.", mode, 6))
}

emit_mode("normal")
emit_mode("decisive")


## ============================================================================
## 10. CONSOLE REPORT
## ============================================================================
cat("\n", strrep("=", 68), "\n  COMPLEXITY SCORES (normal 0-400 & decisive 0-300)\n",
    strrep("=", 68), "\n\n", sep = "")
cat(sprintf("Respondents: %d   |   Answered comparisons: %d of %d   |   Snippets scored: %d\n\n",
            nrow(resp), nrow(per_comparison), nrow(pair_map), nrow(final)))
print(final[, c("group", "problem", "snippet", "n_comparisons",
                "complexity_score", "complexity_score_decisive", "rank_in_group")],
      row.names = FALSE)
cat("\nOutput layout under '", config$out_dir, "/':\n", sep = "")
cat("  normal/    complexity_scores.xlsx, *.csv, plots/ (01 survey, 04-06 survey-vs-metric, 02 split, 03 trend)\n")
cat("  decisive/  same set, using the neutral-excluded 0-300 survey score\n")
cat("\nDone.\n")