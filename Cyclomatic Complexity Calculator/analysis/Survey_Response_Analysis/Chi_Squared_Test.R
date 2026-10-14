################################################################################
#  Chi-squared tests for the code-readability survey
#  ---------------------------------------------------------------------------
#  Chi-squared works on CATEGORICAL COUNTS, so it applies to the raw 1-5 ratings
#  (and their collapsed direction), NOT to the 0-400 complexity scores (those
#  are continuous -> use correlation, which the other scripts already do).
#
#  This script runs the two defensible uses:
#
#    TEST 1 - Goodness of fit (per comparison, and pooled)
#      "Is the response split different from 'no preference'?"
#      Null = respondents equally likely to choose any of the 5 options.
#      A significant result means people had a real, non-random opinion.
#      (Only run on comparisons with enough responses; small n is flagged.)
#
#    TEST 2 - Independence: rating vs respondent attribute
#      "Does a respondent attribute (Java experience, degree) change how they
#       rate complexity?"  Cross-tabulate attribute x rating and test whether
#       they are independent. This is the scientifically interesting one.
#      Ratings are collapsed to 3 directions (A-simpler / no diff / B-simpler)
#      and attributes are collapsed to fewer levels so expected cell counts are
#      healthy. Falls back to Monte-Carlo / Fisher when cells are still sparse.
#
#  For every test we report the statistic, df, p-value, AND an effect size
#  (Cramer's V), because with 757 ratings even trivial differences can be
#  "significant" - the effect size tells you if it MATTERS.
#
#  Runs alongside the other scripts and reads the same CSV.
#  HOW TO RUN:  Rscript chi_squared_tests.R   (or Source in RStudio)
################################################################################


## ============================================================================
## 0. LOCATE SCRIPT + CONFIG
## ============================================================================
get_script_dir <- function() {
  a <- commandArgs(FALSE); m <- grep("^--file=", a, value = TRUE)
  if (length(m)) return(dirname(normalizePath(sub("^--file=", "", m[1]))))
  for (k in sys.nframe():1) { sf <- attr(sys.function(k), "srcref")
  if (!is.null(sf)) { f <- attr(sf, "srcfile")
  if (!is.null(f) && !is.null(f$filename) && nzchar(f$filename))
    return(dirname(normalizePath(f$filename))) } }
  if (requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()) {
    p <- tryCatch(rstudioapi::getSourceEditorContext()$path, error = function(e) "")
    if (nzchar(p)) return(dirname(normalizePath(p))) }
  message("NOTE: using working dir: ", getwd()); getwd()
}
script_dir <- get_script_dir(); message("Script folder: ", script_dir)

config <- list(
  csv_file = "700_survey.csv",
  out_dir  = "chi_squared_output",
  require_finished = TRUE,
  # A comparison needs at least this many responses for its own goodness-of-fit
  # test to be reported as reliable (chi-squared wants ~5 expected per cell;
  # 5 cells x 5 = 25). Smaller ones are still shown but flagged low_power.
  min_n_goodness = 25,
  make_plots = TRUE
)
resolve_path <- function(p) if (grepl("^(/|[A-Za-z]:|\\\\\\\\)", p)) p else file.path(script_dir, p)
config$csv_file <- resolve_path(config$csv_file)
config$out_dir  <- resolve_path(config$out_dir)


## ============================================================================
## 1. PAIR MAP (same 43 comparisons as the other scripts)
## ============================================================================
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
## 2. SETUP + LOAD (same robust loader/parsers as the other scripts)
## ============================================================================
ensure_pkg <- function(p) if (!requireNamespace(p, quietly = TRUE)) {
  message("Installing: ", p); install.packages(p, repos = "https://cloud.r-project.org") }
ensure_pkg("openxlsx"); if (config$make_plots) ensure_pkg("ggplot2")
library(openxlsx)
dir.create(config$out_dir, showWarnings = FALSE, recursive = TRUE)
plot_dir <- file.path(config$out_dir, "plots")
if (config$make_plots) dir.create(plot_dir, showWarnings = FALSE, recursive = TRUE)

read_qualtrics <- function(path) {
  d <- utils::read.csv(path, header = TRUE, check.names = FALSE,
                       stringsAsFactors = FALSE, colClasses = "character",
                       quote = "\"", fill = TRUE, na.strings = c("", "NA"))
  names(d)[1] <- sub("^\ufeff", "", names(d)[1])
  if (nrow(d) > 2) d[-(1:2), , drop = FALSE] else d[0, , drop = FALSE]
}
parse_finished <- function(x) { x <- trimws(tolower(as.character(x)))
ifelse(x %in% c("1","true","t","yes","finished"), 1,
       ifelse(x %in% c("0","false","f","no",""), 0, NA)) }
parse_rating <- function(x) {
  s <- trimws(as.character(x)); out <- rep(NA_real_, length(s))
  a <- suppressWarnings(as.numeric(s)); ok <- !is.na(a) & a %in% 1:5; out[ok] <- a[ok]
  t <- gsub("\\s+", " ", tolower(s)); is_txt <- is.na(out) & nzchar(t)
  out[is_txt & grepl("method a", t) & grepl("much", t)]      <- 1
  out[is_txt & grepl("method a", t) & grepl("slight", t)]    <- 2
  out[is_txt & grepl("no difference|neither|same|equal", t)] <- 3
  out[is_txt & grepl("method b", t) & grepl("slight", t)]    <- 4
  out[is_txt & grepl("method b", t) & grepl("much", t)]      <- 5
  out
}

if (!file.exists(config$csv_file)) stop("CSV not found: ", config$csv_file)
resp <- read_qualtrics(config$csv_file)
if (config$require_finished) {
  fin <- parse_finished(resp[["Finished"]])
  if (sum(fin == 1, na.rm = TRUE) > 0) resp <- resp[!is.na(fin) & fin == 1, , drop = FALSE]
}
message(sprintf("Respondents used: %d", nrow(resp)))
resp$respondent_id <- sprintf("R%03d", seq_len(nrow(resp)))


## ============================================================================
## 3. LONG FORMAT: one row per rating, with respondent attributes attached
## ============================================================================
# Collapse the 5-point rating into 3 directions for the sparser tables.
dir3 <- function(r) factor(ifelse(r <= 2, "A simpler",
                                  ifelse(r == 3, "No difference", "B simpler")),
                           levels = c("A simpler", "No difference", "B simpler"))

# Collapse the demographic attributes into fewer, balanced levels so expected
# counts stay healthy. EDIT these groupings if you prefer different bins.
collapse_experience <- function(x) {
  x <- tolower(trimws(as.character(x)))
  out <- rep(NA_character_, length(x))
  out[grepl("none|tiny|up to 100", x)]            <- "Novice (<=100 LOC)"
  out[grepl("small|100-500", x)]                  <- "Intermediate (100-500)"
  out[grepl("medium|large|500-2000|2000", x)]     <- "Experienced (500+)"
  factor(out, levels = c("Novice (<=100 LOC)", "Intermediate (100-500)",
                         "Experienced (500+)"))
}
collapse_degree <- function(x) {
  x <- tolower(trimws(as.character(x)))
  out <- rep(NA_character_, length(x))
  out[grepl("bachelor|honours|honour", x)] <- "Undergrad/Honours"
  out[grepl("master|postgraduate|diploma|phd|doctor", x)] <- "Postgraduate"
  factor(out, levels = c("Undergrad/Honours", "Postgraduate"))
}

rating_cols <- grep("i_1$", names(resp), value = TRUE)
long <- do.call(rbind, lapply(rating_cols, function(col) {
  item <- sub("i_1$", "", col)
  data.frame(
    respondent_id = resp$respondent_id,
    item = item,
    rating = parse_rating(resp[[col]]),
    experience = collapse_experience(resp[["Demographic Q2"]]),
    degree     = collapse_degree(resp[["Demographic Q1"]]),
    stringsAsFactors = FALSE)
}))
long <- long[!is.na(long$rating), , drop = FALSE]
long <- merge(long, pair_map[, c("item","group","problem")], by = "item", all.x = TRUE)
long$rating <- as.integer(long$rating)
long$direction <- dir3(long$rating)
long$rating_lab <- factor(long$rating, levels = 1:5,
                          labels = c("A much","A slight","No diff","B slight","B much"))
message(sprintf("Total ratings: %d across %d comparisons.",
                nrow(long), length(unique(long$item))))


## ============================================================================
## 4. Helper: run a chi-squared test safely with effect size + fallback
## ============================================================================
## Returns a one-row data.frame. Rules:
##  - If any expected count < 5 (or a 2xk with small n), also run a
##    Monte-Carlo p-value (simulate.p.value) which is valid for sparse tables.
##  - Report Cramer's V as effect size (0 = none, ~0.1 small, ~0.3 medium,
##    ~0.5 large).
run_chisq <- function(tab, label, kind) {
  tab <- as.matrix(tab)
  n <- sum(tab)
  # drop all-zero rows/cols
  tab <- tab[rowSums(tab) > 0, colSums(tab) > 0, drop = FALSE]
  if (nrow(tab) < 2 || ncol(tab) < 2 && kind == "independence")
    return(data.frame(test = label, kind = kind, n = n, note = "not enough non-empty categories",
                      statistic = NA, df = NA, p_value = NA, method = NA,
                      cramers_v = NA, stringsAsFactors = FALSE))
  supp <- suppressWarnings(chisq.test(tab))          # to get expected counts
  min_exp <- min(supp$expected)
  sparse <- min_exp < 5
  test <- if (sparse) suppressWarnings(chisq.test(tab, simulate.p.value = TRUE, B = 20000))
  else supp
  # Cramer's V
  chi <- unname(test$statistic)
  k <- min(nrow(tab), ncol(tab))
  V <- sqrt((chi / n) / (k - 1))
  data.frame(
    test = label, kind = kind, n = n,
    note = if (sparse) sprintf("sparse (min expected %.1f) -> Monte-Carlo p", min_exp) else "ok",
    statistic = round(chi, 2),
    df = if (sparse) NA else unname(test$parameter),
    p_value = signif(test$p.value, 4),
    method = if (sparse) "chisq (simulated, B=20000)" else "chisq (Pearson)",
    cramers_v = round(V, 3),
    stringsAsFactors = FALSE)
}
V_label <- function(v) ifelse(is.na(v), "-",
                              ifelse(v < 0.1, "negligible", ifelse(v < 0.3, "small",
                                                                   ifelse(v < 0.5, "medium", "large"))))


## ============================================================================
## TEST 1 - GOODNESS OF FIT per comparison (vs "no preference" = uniform)
## ============================================================================
## For each comparison, are the 5 counts different from equal (1/5 each)?
gof <- do.call(rbind, lapply(split(long, long$item), function(d) {
  counts <- table(factor(d$rating, levels = 1:5))
  n <- sum(counts)
  tt <- suppressWarnings(chisq.test(as.numeric(counts),
                                    p = rep(1/5, 5), simulate.p.value = (n < 25), B = 20000))
  data.frame(
    item = d$item[1], group = d$group[1], problem = d$problem[1],
    n = n,
    n_A_much = counts[1], n_A_slight = counts[2], n_neutral = counts[3],
    n_B_slight = counts[4], n_B_much = counts[5],
    chi_sq = round(unname(tt$statistic), 2),
    p_value = signif(tt$p.value, 4),
    reliable = ifelse(n >= config$min_n_goodness, "yes", "LOW POWER (small n)"),
    stringsAsFactors = FALSE)
}))
gof <- gof[order(gof$p_value), ]
gof$significant_05 <- ifelse(gof$p_value < 0.05, "*", "")
rownames(gof) <- NULL

# Pooled goodness of fit across ALL ratings (are people non-random overall?)
pooled_counts <- table(factor(long$rating, levels = 1:5))
pooled_gof_test <- chisq.test(as.numeric(pooled_counts), p = rep(1/5, 5))
pooled_gof <- data.frame(
  test = "Pooled: all ratings vs uniform (no preference)",
  n = sum(pooled_counts),
  chi_sq = round(unname(pooled_gof_test$statistic), 2),
  df = unname(pooled_gof_test$parameter),
  p_value = signif(pooled_gof_test$p.value, 4),
  stringsAsFactors = FALSE)


## ============================================================================
## TEST 2 - INDEPENDENCE: rating direction vs respondent attribute
## ============================================================================
## Pooled across all comparisons. Does experience / degree change the
## A-simpler / No-difference / B-simpler split?
indep_tests <- list()

tab_exp <- table(long$experience, long$direction)
indep_tests[["Experience x direction"]] <-
  run_chisq(tab_exp, "Experience x rating direction (3-way)", "independence")

tab_deg <- table(long$degree, long$direction)
indep_tests[["Degree x direction"]] <-
  run_chisq(tab_deg, "Degree x rating direction (3-way)", "independence")

# Also the full 5-level rating (more detail, more sparsity -> likely simulated)
tab_exp5 <- table(long$experience, long$rating_lab)
indep_tests[["Experience x rating5"]] <-
  run_chisq(tab_exp5, "Experience x rating (5-point)", "independence")

independence <- do.call(rbind, indep_tests)
independence$effect <- V_label(independence$cramers_v)
rownames(independence) <- NULL


## ============================================================================
## 5. WRITE WORKBOOK
## ============================================================================
wb <- createWorkbook()
hdr <- createStyle(textDecoration = "bold", fgFill = "#1F3864", fontColour = "white",
                   halign = "center", border = "TopBottomLeftRight",
                   borderColour = "#BFBFBF", wrapText = TRUE)
bodyst <- createStyle(border = "TopBottomLeftRight", borderColour = "#E6E6E6", valign = "top")
add_sheet <- function(name, df, note = NULL) {
  addWorksheet(wb, name); start <- 1
  if (!is.null(note)) { writeData(wb, name, note, startRow = 1)
    addStyle(wb, name, createStyle(textDecoration = "italic", fontColour = "#555555"), rows = 1, cols = 1)
    start <- 3 }
  writeData(wb, name, df, startRow = start, headerStyle = hdr, withFilter = TRUE)
  addStyle(wb, name, bodyst, rows = (start+1):(start+nrow(df)), cols = 1:ncol(df),
           gridExpand = TRUE, stack = TRUE)
  setColWidths(wb, name, cols = 1:ncol(df), widths = "auto")
  freezePane(wb, name, firstActiveRow = start + 1)
}

readme <- data.frame(Question = c(
  "What is chi-squared doing here?",
  "Why not use it on the 0-400 scores?",
  "Test 1 (Goodness of fit)",
  "Test 2 (Independence)",
  "Cramer's V",
  "Sparse tables",
  "Reading the result"),
  Answer = c(
    "Testing categorical response COUNTS (the 1-5 ratings), not the continuous complexity scores.",
    "Those are continuous numbers; use correlation (see metrics_vs_survey.R), not chi-squared.",
    "Per comparison: is the response split different from 'no preference' (uniform)? Significant = people had a real opinion.",
    "Does a respondent attribute (experience, degree) change the rating? Significant = the groups rate differently.",
    "Effect size: <0.1 negligible, 0.1-0.3 small, 0.3-0.5 medium, >0.5 large. With 757 ratings, check this, not just p.",
    "When expected cell counts < 5, a Monte-Carlo p-value (20,000 sims) is used instead of the chi-squared approximation.",
    "A small p with a negligible Cramer's V means 'detectable but trivial'. Look for small p AND a non-trivial V."),
  stringsAsFactors = FALSE)
add_sheet("README", readme)
add_sheet("Test1 goodness of fit", gof,
          note = "Per comparison vs 'no preference'. p<0.05 (starred) = the split is non-random. 'reliable' flags small-n tests.")
add_sheet("Test1 pooled", pooled_gof,
          note = "All 757 ratings pooled vs uniform. Almost always significant; confirms people weren't answering randomly overall.")
add_sheet("Test2 independence", independence,
          note = "Does experience/degree change ratings? Look at p_value AND cramers_v/effect together.")
# also write the contingency tables themselves
add_sheet("Table experience x dir", as.data.frame.matrix(tab_exp))
add_sheet("Table degree x dir", as.data.frame.matrix(tab_deg))

saveWorkbook(wb, file.path(config$out_dir, "chi_squared_results.xlsx"), overwrite = TRUE)
write.csv(gof,          file.path(config$out_dir, "goodness_of_fit.csv"), row.names = FALSE)
write.csv(independence, file.path(config$out_dir, "independence_tests.csv"), row.names = FALSE)
message("Wrote workbook + CSVs to: ", normalizePath(config$out_dir))


## ============================================================================
## 6. PLOTS
## ============================================================================
if (config$make_plots && requireNamespace("ggplot2", quietly = TRUE)) {
  library(ggplot2)
  # Attribute x direction: proportion within each attribute level (mosaic-ish).
  mk_prop <- function(tab, attr_name) {
    df <- as.data.frame(tab); names(df) <- c("level", "direction", "n")
    df <- df[df$level != "" & !is.na(df$level), ]
    df$prop <- ave(df$n, df$level, FUN = function(x) if (sum(x)>0) x/sum(x) else x)
    ggplot(df, aes(level, prop, fill = direction)) +
      geom_col(width = 0.7) +
      scale_fill_manual(values = c("A simpler" = "#1b7837",
                                   "No difference" = "#bdbdbd",
                                   "B simpler" = "#b2182b"), name = NULL) +
      scale_y_continuous(labels = function(x) paste0(x*100, "%")) +
      labs(title = sprintf("Rating direction by %s", attr_name),
           subtitle = "If the bars have the same split, the attribute doesn't matter (independence).",
           x = NULL, y = "Share of ratings") +
      theme_minimal(base_size = 11) +
      theme(plot.title = element_text(face = "bold"), legend.position = "bottom")
  }
  ggsave(file.path(plot_dir, "01_direction_by_experience.png"),
         mk_prop(tab_exp, "experience"), width = 8, height = 5.5, dpi = 150)
  ggsave(file.path(plot_dir, "02_direction_by_degree.png"),
         mk_prop(tab_deg, "degree"), width = 7, height = 5.5, dpi = 150)
  message("Wrote plots to: ", normalizePath(plot_dir))
}


## ============================================================================
## 7. CONSOLE REPORT
## ============================================================================
cat("\n", strrep("=", 66), "\n  CHI-SQUARED RESULTS\n", strrep("=", 66), "\n\n", sep = "")
cat("POOLED goodness of fit (all ratings vs no-preference):\n")
cat(sprintf("  chi-sq = %.1f, df = %d, p = %s  ->  %s\n\n",
            pooled_gof$chi_sq, pooled_gof$df, format(pooled_gof$p_value),
            ifelse(pooled_gof$p_value < 0.05, "ratings are NON-random overall",
                   "no overall preference detected")))
cat("INDEPENDENCE tests (does an attribute change the rating?):\n")
print(independence[, c("test","n","statistic","df","p_value","cramers_v","effect","note")],
      row.names = FALSE)
cat("\nGOODNESS OF FIT per comparison - most decisive (smallest p):\n")
print(utils::head(gof[, c("item","problem","n","chi_sq","p_value","significant_05","reliable")], 8),
      row.names = FALSE)
cat("\nInterpretation reminder: with 757 ratings, weigh Cramer's V (effect size)\n")
cat("alongside p. A tiny p with negligible V = real but unimportant.\n")
cat("\nFiles in '", config$out_dir, "/'.\n", sep = "")
cat("Done.\n")