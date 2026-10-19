################################################################################
#  Code-Readability Survey — Analysis Script
#  ---------------------------------------------------------------------------
#  Input : a Qualtrics CSV export (the "700_survey_*.csv" format).
#  Output: tidy CSVs + plots summarising, for every version-pair, whether
#          respondents found Method A or Method B easier to understand.
#
#  HOW TO RUN
#  ----------
#    1. Put this file and your CSV in the same folder.
#    2. Edit the CONFIG block below (just the csv_file line, usually).
#    3. From a terminal:   Rscript analyse_survey.R
#       ...or open in RStudio and click "Source".
#
#  The script installs any missing packages automatically the first time.
#
#  WHAT THE SURVEY LOOKS LIKE (so the reshape logic makes sense)
#  ------------------------------------------------------------
#    * Qualtrics writes THREE header lines: the machine column names, then a
#      human question-text row, then a JSON "ImportId" row. Real respondents
#      start on line 4. This script drops the two metadata rows automatically.
#    * Each readability comparison is one "item" with three columns:
#         Q<grp><pair>i_1  -> the 1-5 rating  ("which is easier to understand")
#         Q<grp><pair>ii   -> free text: "explain what the code does"
#         Q<grp><pair>iii  -> free text: optional "what made it easier/harder"
#      e.g. Q5Hi_1 / Q5Hii / Q5Hiii  is group 5, pair H.
#    * Every respondent sees only a RANDOM SUBSET of items, so the rating
#      matrix is mostly blank. That is expected, not missing data to worry about.
#
#  THE 1-5 SCALE
#  -------------
#    Method A is ALWAYS the lower code version, Method B the higher version.
#      1 = Method A is MUCH easier to understand
#      2 = Method A is SLIGHTLY easier
#      3 = No difference
#      4 = Method B is SLIGHTLY easier
#      5 = Method B is MUCH easier
#    So a mean below 3 leans A-is-simpler; above 3 leans B-is-simpler.
################################################################################


## ============================================================================
## 0. LOCATE  — make paths work regardless of how the script was launched
## ============================================================================
## `Rscript analyse_survey.R` sets the working directory to wherever you ran
## it from, and RStudio's "Source" button does NOT change the working
## directory to the script's folder by default. Either way, force the working
## directory to this file's own folder so the relative csv_file / out_dir
## paths below always resolve correctly.

set_script_dir <- function() {
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- grep("^--file=", args, value = TRUE)
  if (length(file_arg) > 0) {
    setwd(dirname(normalizePath(sub("^--file=", "", file_arg[1]))))
    return(invisible(TRUE))
  }
  if (requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()) {
    ctx <- tryCatch(rstudioapi::getSourceEditorContext(), error = function(e) NULL)
    if (!is.null(ctx) && nzchar(ctx$path)) {
      setwd(dirname(ctx$path))
      return(invisible(TRUE))
    }
  }
  invisible(FALSE)
}
if (!set_script_dir()) {
  message("Could not auto-detect the script's folder; using the current working ",
          "directory (", getwd(), "). If csv_file below isn't found, setwd() ",
          "to this script's folder manually.")
}


## ============================================================================
## 1. CONFIG  — the only part you normally edit
## ============================================================================

config <- list(
  # Path to the Qualtrics CSV. Relative to where you run the script.
  csv_file = "700 survey.csv",

  # Where results are written (created if it does not exist).
  out_dir = "survey_output",

  # --- Data-quality filters -------------------------------------------------
  # Keep only rows where Qualtrics marked the response Finished == 1.
  require_finished = TRUE,

  # Drop responses faster than this many seconds (likely not read properly).
  # Set to 0 to disable. 60s is a gentle floor; raise once you see real timings.
  min_duration_sec = 0,

  # --- Java comprehension screening ----------------------------------------
  # These are attention/comprehension checks with known correct answers.
  # Fill in the correct CHOICE NUMBERS once confirmed from Qualtrics.
  # (Qualtrics stores multiple-choice answers as the choice index, not text.)
  # Leave a value as NA to skip scoring that question.
  # A respondent's "java_score" = number of these answered correctly (0-3).
  java_answer_key = c("Java Q1" = 3, "Java Q2" = 1, "Java Q3" = 4),

  # Optionally exclude respondents scoring below this on the Java check.
  # 0 keeps everyone; 2 would keep only those who got >=2 of 3 right.
  min_java_score = 0,

  # --- Plotting -------------------------------------------------------------
  make_plots = TRUE,       # set FALSE to skip all charts
  plot_width = 9,
  plot_height = 6
)


## ============================================================================
## 2. PAIR LABELS  — what each Q<grp><pair> actually compares
## ============================================================================
## This is the human-readable key so the output says
##   "05-H : V2 (LinkedHashSet) vs V4 (ORIG+comments)"
## instead of the opaque "Q5H".
##
## Columns:
##   item     = the Qualtrics stem (Q<grp><pair>), matches the CSV
##   group    = problem number (1-10)
##   problem  = short name of the coding task
##   method_a = lower version shown as "Method A"
##   method_b = higher version shown as "Method B"
##   apriori  = the researchers' own prior rating on the same 1-5 scale
##              (optional; used only to compare intuition vs. respondents.
##               Put NA if you don't want the comparison.)
##
## If you add/rename items in Qualtrics, update this table to match. Any item
## found in the CSV but missing here is still analysed — it just gets a
## generic label and a warning.

pair_labels <- read.csv(text = "
item,group,problem,method_a,method_b,apriori
Q1A,1,Letter grade,ORIG nested if,V1 else-if chain,5
Q1B,1,Letter grade,ORIG nested if,V2 chained ternary,4
Q1C,1,Letter grade,ORIG nested if,V3 nested+Javadoc,4
Q1D,1,Letter grade,V1 else-if chain,V2 chained ternary,2
Q1E,1,Letter grade,V1 else-if chain,V3 nested+Javadoc,1
Q1F,1,Letter grade,V2 chained ternary,V3 nested+Javadoc,3
Q2A,2,Password check,ORIG compound &&,V1 guard clauses,4
Q2B,2,Password check,ORIG compound &&,V2 named helpers,5
Q2C,2,Password check,ORIG compound &&,V3 compound+Javadoc,4
Q2D,2,Password check,V1 guard clauses,V2 named helpers,4
Q2E,2,Password check,V1 guard clauses,V3 compound+Javadoc,2
Q2F,2,Password check,V2 named helpers,V3 compound+Javadoc,2
Q3A,3,Sum of digits,ORIG recursive ifs,V1 iterative while,4
Q3B,3,Sum of digits,ORIG recursive ifs,V2 recursive ternary,2
Q3C,3,Sum of digits,V1 iterative while,V2 recursive ternary,1
Q4A,4,Max in 2D array,ORIG nested loops,V1 rowMax helper,2
Q5A,5,Remove duplicates,ORIG nested scan,V1 contains check,5
Q5B,5,Remove duplicates,ORIG nested scan,V2 LinkedHashSet,5
Q5C,5,Remove duplicates,ORIG nested scan,V3 verbose nested,3
Q5D,5,Remove duplicates,ORIG nested scan,V4 ORIG+comments,4
Q5E,5,Remove duplicates,V1 contains check,V2 LinkedHashSet,4
Q5F,5,Remove duplicates,V1 contains check,V3 verbose nested,1
Q5G,5,Remove duplicates,V1 contains check,V4 ORIG+comments,2
Q5H,5,Remove duplicates,V2 LinkedHashSet,V3 verbose nested,1
Q5I,5,Remove duplicates,V2 LinkedHashSet,V4 ORIG+comments,2
Q5J,5,Remove duplicates,V3 verbose nested,V4 ORIG+comments,4
Q6A,6,Frequency count,ORIG containsKey,V1 getOrDefault,5
Q6B,6,Frequency count,ORIG containsKey,V2 verbose containsKey,2
Q6C,6,Frequency count,V1 getOrDefault,V2 verbose containsKey,1
Q7A,7,Merge sorted arrays,ORIG three whiles,V1 arraycopy tails,4
Q7B,7,Merge sorted arrays,ORIG three whiles,V2 concat+sort,5
Q7C,7,Merge sorted arrays,ORIG three whiles,V3 commented whiles,4
Q7D,7,Merge sorted arrays,V1 arraycopy tails,V2 concat+sort,4
Q7E,7,Merge sorted arrays,V1 arraycopy tails,V3 commented whiles,4
Q8A,8,Roman numeral,ORIG nested lookahead,V1 compound lookahead,4
Q8B,8,Roman numeral,ORIG nested lookahead,V2 right-to-left,3
Q8C,8,Roman numeral,V1 compound lookahead,V2 right-to-left,2
Q9A,9,Binary search,ORIG nested if/else,V1 else-if chain,4
Q9B,9,Binary search,ORIG nested if/else,V2 Arrays.binarySearch,5
Q9C,9,Binary search,V1 else-if chain,V2 Arrays.binarySearch,4
Q10A,10,Balanced brackets,ORIG explicit compares,V1 indexOf trick,2
Q10B,10,Balanced brackets,ORIG explicit compares,V2 indexOf+helper,3
Q10C,10,Balanced brackets,ORIG explicit compares,V3 commented explicit,4
", stringsAsFactors = FALSE, strip.white = TRUE)


## ============================================================================
## 3. SETUP  — packages
## ============================================================================
## Uses tidyverse if available; otherwise falls back to base R so the core
## tables still get produced. Plots need ggplot2.

ensure_pkg <- function(pkg) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    message(sprintf("Installing missing package: %s", pkg))
    install.packages(pkg, repos = "https://cloud.r-project.org")
  }
}

have_tidyverse <- suppressWarnings(requireNamespace("dplyr", quietly = TRUE) &&
                                   requireNamespace("tidyr", quietly = TRUE))
if (config$make_plots) ensure_pkg("ggplot2")

# base R's read.csv()/scan() chokes on this export (mis-parses embedded quotes
# in free-text answers, e.g. reports "EOF within quoted string" and silently
# shreds rows). readr's parser handles it correctly, so it's required.
ensure_pkg("readr")

# Rating scale labels, reused everywhere.
scale_levels <- 1:5
scale_labels <- c(
  "1" = "A much easier",
  "2" = "A slightly easier",
  "3" = "No difference",
  "4" = "B slightly easier",
  "5" = "B much easier"
)

dir.create(config$out_dir, showWarnings = FALSE, recursive = TRUE)
plot_dir <- file.path(config$out_dir, "plots")
if (config$make_plots) dir.create(plot_dir, showWarnings = FALSE, recursive = TRUE)


## ============================================================================
## 4. LOAD  — read the Qualtrics CSV and strip the metadata rows
## ============================================================================

message("Reading: ", config$csv_file)

# Row 1 = column names. Rows 2-3 = Qualtrics metadata. Read everything as
# character so downstream `num()` conversions have consistent input.
all_rows <- readr::read_csv(config$csv_file, col_names = TRUE,
                            col_types = readr::cols(.default = readr::col_character()),
                            show_col_types = FALSE, progress = FALSE)
parse_issues <- readr::problems(all_rows)
if (nrow(parse_issues) > 0) {
  warning(sprintf("readr reported %d parsing issue(s) while reading the CSV; ",
                  nrow(parse_issues)),
          "results may be affected. Run readr::problems() on a fresh read to inspect.")
}

header <- names(all_rows)
qtext  <- as.data.frame(all_rows[1, , drop = FALSE], stringsAsFactors = FALSE)
# Row 2 of the data is the Qualtrics "ImportId" JSON metadata row; discard it.
raw    <- as.data.frame(all_rows[-c(1, 2), , drop = FALSE], stringsAsFactors = FALSE)

message(sprintf("Loaded %d raw response rows, %d columns.",
                nrow(raw), ncol(raw)))

if (nrow(raw) == 0) {
  stop("No respondent rows found after skipping the 3 Qualtrics header lines. ",
       "Check that the CSV really is a Qualtrics export.")
}


## ============================================================================
## 5. CLEAN  — type conversion, quality filters, Java scoring
## ============================================================================

num <- function(x) suppressWarnings(as.numeric(x))

raw$Duration_sec <- num(raw[["Duration (in seconds)"]])
raw$Progress_num <- num(raw[["Progress"]])
raw$Finished_num <- num(raw[["Finished"]])

# --- Java comprehension score --------------------------------------------
key <- config$java_answer_key
key <- key[!is.na(key)]
if (length(key) > 0) {
  score_mat <- sapply(names(key), function(col) {
    as.integer(num(raw[[col]]) == key[[col]])
  })
  # sapply on 1 row returns a vector; force a matrix
  if (is.null(dim(score_mat))) score_mat <- t(as.matrix(score_mat))
  raw$java_score <- rowSums(score_mat, na.rm = TRUE)
} else {
  raw$java_score <- NA_integer_
}

n_start <- nrow(raw)
resp <- raw

if (config$require_finished) {
  resp <- resp[!is.na(resp$Finished_num) & resp$Finished_num == 1, , drop = FALSE]
}
if (config$min_duration_sec > 0) {
  resp <- resp[is.na(resp$Duration_sec) |
               resp$Duration_sec >= config$min_duration_sec, , drop = FALSE]
}
if (config$min_java_score > 0 && length(key) > 0) {
  resp <- resp[!is.na(resp$java_score) &
               resp$java_score >= config$min_java_score, , drop = FALSE]
}

message(sprintf("Respondents kept after filters: %d of %d.",
                nrow(resp), n_start))

if (nrow(resp) == 0) {
  stop("All respondents were filtered out. Loosen the filters in CONFIG ",
       "(e.g. min_duration_sec, min_java_score, require_finished).")
}


## ============================================================================
## 6. RESHAPE  — wide sparse matrix -> long "one rating per row"
## ============================================================================
## Every column ending in "i_1" is a rating item. Melt them, drop the blanks
## (respondents only see a subset), attach the pair labels.

rating_cols <- grep("i_1$", names(resp), value = TRUE)
message(sprintf("Found %d rating columns.", length(rating_cols)))

# Give each kept respondent a stable id.
resp$respondent_id <- if ("ResponseId" %in% names(resp) &&
                          any(nzchar(resp$ResponseId))) {
  resp$ResponseId
} else {
  sprintf("R%03d", seq_len(nrow(resp)))
}

# Build the long frame (base R; works with or without tidyverse).
long_list <- lapply(rating_cols, function(col) {
  item <- sub("i_1$", "", col)     # "Q5Hi_1" -> "Q5H"
  data.frame(
    respondent_id = resp$respondent_id,
    java_score    = resp$java_score,
    duration_sec  = resp$Duration_sec,
    item          = item,
    rating        = num(resp[[col]]),
    stringsAsFactors = FALSE
  )
})
long <- do.call(rbind, long_list)
long <- long[!is.na(long$rating), , drop = FALSE]   # drop unseen items

if (nrow(long) == 0) {
  stop("No non-blank ratings found. Either the survey has no responses yet, ",
       "or the rating columns are named differently than '*i_1'.")
}

# Attach labels; warn about any item present in data but not in pair_labels.
long <- merge(long, pair_labels, by = "item", all.x = TRUE, sort = FALSE)
unlabelled <- unique(long$item[is.na(long$group)])
if (length(unlabelled) > 0) {
  warning("Items in the data but missing from pair_labels (generic labels used): ",
          paste(unlabelled, collapse = ", "))
  long$problem[is.na(long$problem)]  <- "UNLABELLED"
  long$method_a[is.na(long$method_a)] <- "Method A"
  long$method_b[is.na(long$method_b)] <- "Method B"
}

# A tidy readable label for each pair, and the rating as a factor for plots.
long$pair_label  <- sprintf("%s: %s vs %s", long$item, long$method_a, long$method_b)
long$rating_fac  <- factor(long$rating, levels = scale_levels,
                           labels = scale_labels[as.character(scale_levels)])

# Direction buckets: who did this respondent favour?
long$favours <- cut(long$rating,
                    breaks = c(-Inf, 2.5, 3.5, Inf),
                    labels = c("Method A (lower ver)",
                               "No difference",
                               "Method B (higher ver)"))

message(sprintf("Long format: %d individual ratings across %d distinct items.",
                nrow(long), length(unique(long$item))))


## ============================================================================
## 7. SUMMARISE  — per-pair statistics
## ============================================================================
## For each version-pair: how many rated it, the mean/median on the 1-5 scale,
## how the votes split A / tie / B, a "net" score (positive => B seen simpler),
## and (if provided) the researchers' prior rating for comparison.

summarise_pairs <- function(df) {
  parts <- split(df, df$item)
  out <- lapply(parts, function(d) {
    n     <- nrow(d)
    a     <- sum(d$rating <= 2)
    tie   <- sum(d$rating == 3)
    b     <- sum(d$rating >= 4)
    data.frame(
      item        = d$item[1],
      group       = d$group[1],
      problem     = d$problem[1],
      method_a    = d$method_a[1],
      method_b    = d$method_b[1],
      n_ratings   = n,
      mean_rating = round(mean(d$rating), 2),
      median      = median(d$rating),
      sd          = round(sd(d$rating), 2),
      pct_favours_A   = round(100 * a  / n, 1),
      pct_no_diff     = round(100 * tie / n, 1),
      pct_favours_B   = round(100 * b  / n, 1),
      # net direction on a -1..+1 scale: (B votes - A votes)/n
      net_toward_B    = round((b - a) / n, 2),
      apriori         = d$apriori[1],
      stringsAsFactors = FALSE
    )
  })
  res <- do.call(rbind, out)
  # verdict label from the mean
  res$verdict <- cut(res$mean_rating,
                     breaks = c(-Inf, 2.4, 2.75, 3.25, 3.6, Inf),
                     labels = c("A much easier", "A slightly easier",
                                "No clear difference",
                                "B slightly easier", "B much easier"))
  # does the crowd's direction agree with the researchers' prior?
  res$apriori_dir <- cut(res$apriori, breaks = c(-Inf, 2.5, 3.5, Inf),
                         labels = c("A", "tie", "B"))
  res$crowd_dir   <- cut(res$mean_rating, breaks = c(-Inf, 2.5, 3.5, Inf),
                         labels = c("A", "tie", "B"))
  res$agrees_with_prior <- ifelse(is.na(res$apriori), NA,
                                  as.character(res$apriori_dir) ==
                                  as.character(res$crowd_dir))
  res <- res[order(res$group, res$item), ]
  rownames(res) <- NULL
  res
}

pair_summary <- summarise_pairs(long)

# Per-problem roll-up: on average across its pairs, did simplifying help?
group_summary <- do.call(rbind, lapply(split(long, long$group), function(d) {
  data.frame(
    group        = d$group[1],
    problem      = d$problem[1],
    n_pairs      = length(unique(d$item)),
    n_ratings    = nrow(d),
    mean_rating  = round(mean(d$rating), 2),
    pct_favours_A = round(100 * mean(d$rating <= 2), 1),
    pct_no_diff   = round(100 * mean(d$rating == 3), 1),
    pct_favours_B = round(100 * mean(d$rating >= 4), 1),
    stringsAsFactors = FALSE
  )
}))
group_summary <- group_summary[order(group_summary$group), ]
rownames(group_summary) <- NULL

# Respondent-level coverage: how many items each person answered.
resp_summary <- do.call(rbind, lapply(split(long, long$respondent_id), function(d) {
  data.frame(
    respondent_id = d$respondent_id[1],
    java_score    = d$java_score[1],
    duration_sec  = d$duration_sec[1],
    items_rated   = nrow(d),
    mean_rating   = round(mean(d$rating), 2),
    stringsAsFactors = FALSE
  )
}))
resp_summary <- resp_summary[order(-resp_summary$items_rated), ]
rownames(resp_summary) <- NULL


## ============================================================================
## 8. WRITE TABLES
## ============================================================================

write.csv(long,          file.path(config$out_dir, "ratings_long.csv"),     row.names = FALSE)
write.csv(pair_summary,  file.path(config$out_dir, "pair_summary.csv"),     row.names = FALSE)
write.csv(group_summary, file.path(config$out_dir, "group_summary.csv"),    row.names = FALSE)
write.csv(resp_summary,  file.path(config$out_dir, "respondent_summary.csv"), row.names = FALSE)

message("Wrote tables to: ", normalizePath(config$out_dir))


## ============================================================================
## 9. PLOTS
## ============================================================================

# Helper: use ggrepel for non-overlapping point labels if installed, else plain
# text. Defined here (before the plot block) so it exists when called below.
ggrepel_or_text <- function(df) {
  if (requireNamespace("ggrepel", quietly = TRUE)) {
    ggrepel::geom_text_repel(data = df, ggplot2::aes(label = item),
                             size = 3, max.overlaps = 50)
  } else {
    ggplot2::geom_text(data = df, ggplot2::aes(label = item),
                       size = 3, vjust = -0.8, check_overlap = TRUE)
  }
}

if (config$make_plots && requireNamespace("ggplot2", quietly = TRUE)) {
  library(ggplot2)

  # Consistent diverging colours: A = teal, tie = grey, B = orange.
  fill_scale <- scale_fill_manual(
    values = c("1" = "#1b7837", "2" = "#a6dba0",
               "3" = "#bdbdbd",
               "4" = "#f4a582", "5" = "#b2182b"),
    labels = scale_labels, name = "Rating"
  )

  # ---- 9a. Stacked distribution per pair (the main picture) ---------------
  # One horizontal bar per version-pair, split by rating. Ordered by mean so
  # the pairs where B "won" cluster at one end.
  plot_df <- long
  ord <- pair_summary[order(pair_summary$mean_rating), ]
  plot_df$pair_label <- factor(plot_df$pair_label,
                               levels = unique(
                                 sprintf("%s: %s vs %s",
                                         ord$item, ord$method_a, ord$method_b)))
  plot_df$rating_chr <- factor(as.character(plot_df$rating), levels = c("1","2","3","4","5"))

  p1 <- ggplot(plot_df, aes(y = pair_label, fill = rating_chr)) +
    geom_bar(position = "fill") +
    fill_scale +
    scale_x_continuous(labels = function(x) paste0(x*100, "%")) +
    labs(title = "Which method felt easier to understand?",
         subtitle = "Each bar = one version-pair. Green = lower version (A) easier; red = higher version (B) easier.",
         x = "Share of respondents", y = NULL) +
    theme_minimal(base_size = 11) +
    theme(legend.position = "bottom",
          plot.title = element_text(face = "bold"))
  ggsave(file.path(plot_dir, "01_pair_rating_distribution.png"), p1,
         width = config$plot_width, height = max(6, 0.3 * nrow(pair_summary)),
         dpi = 150, limitsize = FALSE)

  # ---- 9b. Mean rating per pair with the 3.0 "no difference" line ---------
  ms <- pair_summary
  ms$pair_label <- factor(sprintf("%s: %s vs %s", ms$item, ms$method_a, ms$method_b),
                          levels = sprintf("%s: %s vs %s",
                                           ord$item, ord$method_a, ord$method_b))
  p2 <- ggplot(ms, aes(x = mean_rating, y = pair_label)) +
    annotate("rect", xmin = 1, xmax = 3, ymin = -Inf, ymax = Inf,
             alpha = 0.05, fill = "#1b7837") +
    annotate("rect", xmin = 3, xmax = 5, ymin = -Inf, ymax = Inf,
             alpha = 0.05, fill = "#b2182b") +
    geom_vline(xintercept = 3, linetype = "dashed", colour = "grey40") +
    geom_point(aes(size = n_ratings), colour = "#2166ac") +
    scale_x_continuous(limits = c(1, 5), breaks = 1:5,
                       labels = c("A much", "A slight", "tie", "B slight", "B much")) +
    labs(title = "Mean readability rating per version-pair",
         subtitle = "Left of the dashed line: lower version (A) seen as simpler. Right: higher version (B).",
         x = "Mean rating (1-5)", y = NULL, size = "n") +
    theme_minimal(base_size = 11) +
    theme(plot.title = element_text(face = "bold"))
  ggsave(file.path(plot_dir, "02_pair_mean_rating.png"), p2,
         width = config$plot_width, height = max(6, 0.3 * nrow(pair_summary)),
         dpi = 150, limitsize = FALSE)

  # ---- 9c. Per-problem roll-up -------------------------------------------
  gs <- group_summary
  gs$label <- sprintf("Q%s %s", gs$group, gs$problem)
  gs$label <- factor(gs$label, levels = gs$label[order(gs$mean_rating)])
  p3 <- ggplot(gs, aes(x = mean_rating, y = label)) +
    geom_vline(xintercept = 3, linetype = "dashed", colour = "grey40") +
    geom_col(aes(fill = mean_rating > 3), width = 0.6) +
    scale_fill_manual(values = c("FALSE" = "#1b7837", "TRUE" = "#b2182b"),
                      guide = "none") +
    scale_x_continuous(breaks = 1:5) +
    coord_cartesian(xlim = c(1, 5)) +
    labs(title = "Average readability direction by coding problem",
         subtitle = "Pooled across all version-pairs within each problem",
         x = "Mean rating (1 = A easier ... 5 = B easier)", y = NULL) +
    theme_minimal(base_size = 11) +
    theme(plot.title = element_text(face = "bold"))
  ggsave(file.path(plot_dir, "03_problem_rollup.png"), p3,
         width = config$plot_width, height = config$plot_height, dpi = 150)

  # ---- 9d. Crowd vs. researchers' prior (only if apriori supplied) --------
  if (any(!is.na(pair_summary$apriori))) {
    cmp <- pair_summary[!is.na(pair_summary$apriori), ]
    p4 <- ggplot(cmp, aes(x = apriori, y = mean_rating)) +
      annotate("segment", x = 1, y = 1, xend = 5, yend = 5,
               linetype = "dotted", colour = "grey50") +
      geom_hline(yintercept = 3, colour = "grey85") +
      geom_vline(xintercept = 3, colour = "grey85") +
      geom_point(aes(size = n_ratings, colour = agrees_with_prior)) +
      ggrepel_or_text(cmp) +
      scale_colour_manual(values = c("TRUE" = "#1b7837", "FALSE" = "#b2182b"),
                          na.value = "grey60", name = "Same direction?") +
      scale_x_continuous(limits = c(1, 5), breaks = 1:5) +
      scale_y_continuous(limits = c(1, 5), breaks = 1:5) +
      labs(title = "Researchers' prior vs. respondents' mean",
           subtitle = "On the dotted line = perfect agreement. Off-diagonal = respondents disagreed with the prior.",
           x = "Researchers' a-priori rating", y = "Respondents' mean rating") +
      theme_minimal(base_size = 11) +
      theme(plot.title = element_text(face = "bold"))
    ggsave(file.path(plot_dir, "04_prior_vs_crowd.png"), p4,
           width = config$plot_width, height = config$plot_height, dpi = 150)
  }

  message("Wrote plots to: ", normalizePath(plot_dir))
} else if (config$make_plots) {
  message("ggplot2 not available; skipped plots. Tables were still written.")
}


## ============================================================================
## 10. CONSOLE REPORT
## ============================================================================

cat("\n", strrep("=", 70), "\n", sep = "")
cat("  SURVEY ANALYSIS SUMMARY\n")
cat(strrep("=", 70), "\n\n", sep = "")

cat(sprintf("Respondents analysed : %d\n", nrow(resp)))
cat(sprintf("Total ratings given  : %d\n", nrow(long)))
cat(sprintf("Version-pairs covered: %d of %d\n\n",
            length(unique(long$item)), nrow(pair_labels)))

if (length(key) > 0) {
  cat("Java comprehension score (0-3) distribution:\n")
  print(table(factor(resp$java_score, levels = 0:length(key))))
  cat("\n")
}

# Pairs with the least data — where you most need more respondents.
thin <- pair_summary[order(pair_summary$n_ratings), c("item","problem","n_ratings")]
cat("Thinnest-covered pairs (collect more responses here):\n")
print(utils::head(thin, 8), row.names = FALSE)
cat("\n")

# Clearest crowd verdicts.
clear <- pair_summary[order(-abs(pair_summary$net_toward_B)), ]
cat("Strongest readability signals (by net direction):\n")
print(utils::head(
  clear[, c("item","problem","method_a","method_b",
            "n_ratings","mean_rating","verdict")],
  10), row.names = FALSE)
cat("\n")

if (any(!is.na(pair_summary$agrees_with_prior))) {
  agree <- mean(pair_summary$agrees_with_prior, na.rm = TRUE)
  cat(sprintf("Agreement with researchers' prior direction: %.0f%% of scored pairs\n\n",
              100 * agree))
}

cat("Files written to '", config$out_dir, "/':\n", sep = "")
cat("  ratings_long.csv        one row per individual rating (tidy, for re-analysis)\n")
cat("  pair_summary.csv        one row per version-pair (the headline table)\n")
cat("  group_summary.csv       one row per coding problem\n")
cat("  respondent_summary.csv  one row per respondent (coverage & quality)\n")
if (config$make_plots) cat("  plots/                  distribution + mean + roll-up charts\n")
cat("\nDone.\n")