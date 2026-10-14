################################################################################
#  Static Metrics vs. Survey Complexity — Correlation of PAIR DELTAS
#  ---------------------------------------------------------------------------
#  Question: when two versions of the same function differ by X cyclomatic
#  points (or cognitive, or nesting), by how much does the SURVEY-DERIVED
#  complexity score (0-400) differ? And how tightly do those move together?
#
#  For every within-function PAIR (A = lower version, B = higher version) we
#  compute, consistently as (B - A):
#      d_CC        difference in cyclomatic complexity
#      d_Cognitive difference in cognitive complexity
#      d_MaxNest   difference in max nesting depth
#      d_Survey    difference in the survey complexity score (0-400)
#  and then plot / correlate each static delta against d_Survey.
#
#  A positive delta means "the higher version scores higher on that metric."
#  If a static metric tracks the survey well, its points hug a straight line.
#
#  Runs alongside analyse_survey.R and complexity_score.R. Reads the same CSV
#  to rebuild the survey scores, so there is one source of truth for those.
#
#  HOW TO RUN:  Rscript metrics_vs_survey.R      (or Source in RStudio)
################################################################################


## ============================================================================
## 0. LOCATE THIS SCRIPT  (so paths work regardless of working directory)
## ============================================================================
get_script_dir <- function() {
  a <- commandArgs(FALSE); m <- grep("^--file=", a, value = TRUE)
  if (length(m)) return(dirname(normalizePath(sub("^--file=", "", m[1]))))
  for (k in sys.nframe():1) {
    sf <- attr(sys.function(k), "srcref")
    if (!is.null(sf)) { f <- attr(sf, "srcfile")
    if (!is.null(f) && !is.null(f$filename) && nzchar(f$filename))
      return(dirname(normalizePath(f$filename))) }
  }
  if (requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()) {
    p <- tryCatch(rstudioapi::getSourceEditorContext()$path, error = function(e) "")
    if (nzchar(p)) return(dirname(normalizePath(p)))
  }
  message("NOTE: couldn't detect script folder; using working dir: ", getwd()); getwd()
}
script_dir <- get_script_dir()
message("Script folder: ", script_dir)


## ============================================================================
## 1. CONFIG
## ============================================================================
config <- list(
  csv_file = "700_survey.csv",       # same Qualtrics export as the other scripts
  out_dir  = "metrics_vs_survey_output",
  require_finished = TRUE,
  make_plots  = TRUE,
  plot_width  = 8,
  plot_height = 6.5
)
resolve_path <- function(p) if (grepl("^(/|[A-Za-z]:|\\\\\\\\)", p)) p else file.path(script_dir, p)
config$csv_file <- resolve_path(config$csv_file)
config$out_dir  <- resolve_path(config$out_dir)


## ============================================================================
## 2. STATIC METRICS  (embedded — one row per method; helpers on their own row)
## ============================================================================
## Pasted from the metrics table. Snippets with helper methods have several
## rows here; they are aggregated per snippet in step 4:
##   CC, Cognitive -> SUM across the snippet's methods (total a reader faces)
##   MaxNest       -> MAX across methods (deepest nesting anywhere)
## Only the columns we use are kept (Halstead intentionally ignored).

metrics_raw <- read.csv(text = "
ID,method,CC,Cognitive,LOC,MaxNest,FanOut,Params
01-ORIG,grade,5,14,21,4,0,1
01-V1,grade,5,4,15,1,0,1
01-V2,grade,5,5,15,4,0,1
01-V3,grade,5,4,3,0,0,1
01-V4,grade,5,14,21,4,0,1
01-V5,grade,5,14,21,4,0,1
02-ORIG,check,6,2,8,1,5,1
02-V1,check,6,5,18,1,5,1
02-V2,check,4,1,3,0,3,1
02-V2,hasMinLength,1,0,3,0,1,1
02-V2,hasLowerAndUpper,2,1,3,0,3,1
02-V2,hasDigit,1,0,3,0,1,1
02-V3,check,6,2,7,1,5,1
03-ORIG,sd,3,4,9,1,1,1
03-V1,sd,2,1,9,1,1,1
03-V2,sd,3,4,6,1,1,1
04-ORIG,max,4,6,11,3,0,1
04-V1,max,4,6,11,3,0,1
04-V2,max,2,2,7,1,2,1
04-V2,rowMax,3,3,9,2,0,1
04-V3,max,4,6,11,3,0,1
05-ORIG,dedupe,5,8,15,3,4,1
05-V1,dedupe,3,3,9,2,2,1
05-V2,dedupe,1,0,3,0,0,1
05-V3,removeDuplicates,5,8,15,3,4,1
06-ORIG,tally,3,4,12,2,4,1
06-V1,tally,2,1,7,1,2,1
06-V2,countByValue,3,4,12,2,4,1
07-ORIG,merge,6,7,27,2,0,2
07-V1,merge,4,5,16,2,1,2
07-V2,merge,1,0,7,0,2,2
07-V3,merge,6,7,27,2,0,2
08-ORIG,roman,4,8,16,3,3,1
08-ORIG,value,8,1,12,1,0,1
08-V1,roman,4,5,12,2,3,1
08-V1,value,8,1,12,1,0,1
08-V2,roman,3,4,14,2,3,1
08-V2,value,8,1,12,1,0,1
09-ORIG,bs,4,8,17,3,0,2
09-V1,bs,4,5,15,3,0,2
09-V2,bs,2,1,4,0,1,2
10-ORIG,balanced,15,28,26,4,5,1
10-V1,balanced,6,10,17,4,6,1
10-V2,balanced,6,8,14,4,7,1
10-V2,matches,1,0,3,0,1,2
10-V3,balanced,15,28,26,4,5,1
", stringsAsFactors = FALSE, strip.white = TRUE)


## ============================================================================
## 3. PAIR MAP  (must match complexity_score.R — same 43 within-function pairs)
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
## 4. SETUP + aggregate static metrics to one row per snippet
## ============================================================================
ensure_pkg <- function(p) if (!requireNamespace(p, quietly = TRUE)) {
  message("Installing: ", p); install.packages(p, repos = "https://cloud.r-project.org") }
ensure_pkg("openxlsx"); if (config$make_plots) ensure_pkg("ggplot2")
library(openxlsx)
dir.create(config$out_dir, showWarnings = FALSE, recursive = TRUE)
plot_dir <- file.path(config$out_dir, "plots")
if (config$make_plots) dir.create(plot_dir, showWarnings = FALSE, recursive = TRUE)

# Helper: label points with the pair name; use ggrepel if installed, else plain
# text. Defined here so it exists when the plot block runs.
ggrepel_or_text <- function(df, xcol) {
  if (requireNamespace("ggrepel", quietly = TRUE)) {
    ggrepel::geom_text_repel(data = df,
                             ggplot2::aes(x = .data[[xcol]], y = d_Survey, label = item),
                             size = 2.6, max.overlaps = 30, colour = "grey30")
  } else {
    ggplot2::geom_text(data = df,
                       ggplot2::aes(x = .data[[xcol]], y = d_Survey, label = item),
                       size = 2.6, vjust = -0.7, colour = "grey30", check_overlap = TRUE)
  }
}

# group/version keys from the "01-ORIG" style ID.
metrics_raw$group   <- as.integer(sub("-.*$", "", metrics_raw$ID))
metrics_raw$version <- sub("^[^-]*-", "", metrics_raw$ID)

# Aggregate helpers into one value per snippet.
snip_metrics <- do.call(rbind, lapply(split(metrics_raw, metrics_raw$ID), function(d) {
  data.frame(
    group   = d$group[1],
    version = d$version[1],
    CC        = sum(d$CC),          # total cyclomatic across methods
    Cognitive = sum(d$Cognitive),   # total cognitive across methods
    MaxNest   = max(d$MaxNest),     # deepest nesting anywhere
    n_methods = nrow(d),
    stringsAsFactors = FALSE)
}))
rownames(snip_metrics) <- NULL


## ============================================================================
## 5. REBUILD SURVEY COMPLEXITY SCORES  (same logic as complexity_score.R)
## ============================================================================
read_qualtrics <- function(path) {
  d <- utils::read.csv(path, header = TRUE, check.names = FALSE,
                       stringsAsFactors = FALSE, colClasses = "character",
                       quote = "\"", fill = TRUE, na.strings = c("", "NA"))
  names(d)[1] <- sub("^\ufeff", "", names(d)[1])
  if (nrow(d) > 2) d[-(1:2), , drop = FALSE] else d[0, , drop = FALSE]
}
parse_finished <- function(x) {
  x <- trimws(tolower(as.character(x)))
  ifelse(x %in% c("1","true","t","yes","finished"), 1,
         ifelse(x %in% c("0","false","f","no",""), 0, NA))
}
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

if (!file.exists(config$csv_file))
  stop("CSV not found next to the script: ", config$csv_file)
resp <- read_qualtrics(config$csv_file)
if (config$require_finished) {
  fin <- parse_finished(resp[["Finished"]])
  if (sum(fin == 1, na.rm = TRUE) > 0) resp <- resp[!is.na(fin) & fin == 1, , drop = FALSE]
  else message("No finished==1 rows; using all responses.")
}
message(sprintf("Survey respondents used: %d", nrow(resp)))

A_value <- function(r) (r - 1) * 100
B_value <- function(r) (5 - r) * 100

# per-comparison A/B scores
per_comp <- do.call(rbind, lapply(seq_len(nrow(pair_map)), function(i) {
  col <- paste0(pair_map$item[i], "i_1")
  if (!col %in% names(resp)) return(NULL)
  r <- parse_rating(resp[[col]]); r <- r[!is.na(r)]; n <- length(r)
  if (n == 0) return(NULL)
  prop <- sapply(1:5, function(k) sum(r == k)) / n
  data.frame(group = pair_map$group[i], snippet_a = pair_map$snippet_a[i],
             snippet_b = pair_map$snippet_b[i], n = n,
             A_score = sum(prop * A_value(1:5)),
             B_score = sum(prop * B_value(1:5)), stringsAsFactors = FALSE)
}))
# final per-snippet survey score = mean of its comparison scores
contrib <- rbind(
  data.frame(group = per_comp$group, version = per_comp$snippet_a, score = per_comp$A_score),
  data.frame(group = per_comp$group, version = per_comp$snippet_b, score = per_comp$B_score))
survey_scores <- do.call(rbind, lapply(
  split(contrib, list(contrib$group, contrib$version), drop = TRUE),
  function(d) data.frame(group = d$group[1], version = d$version[1],
                         survey_score = mean(d$score), stringsAsFactors = FALSE)))
rownames(survey_scores) <- NULL


## ============================================================================
## 6. BUILD PAIR-LEVEL DELTAS  (B - A for every metric AND the survey score)
## ============================================================================
## Only pairs where BOTH snippets have static metrics AND a survey score are
## usable. Everything else is reported as skipped so nothing is silently lost.

lookup_metric <- function(g, v, col) {
  row <- snip_metrics[snip_metrics$group == g & snip_metrics$version == v, ]
  if (nrow(row) == 0) return(NA_real_)
  row[[col]][1]
}
lookup_survey <- function(g, v) {
  row <- survey_scores[survey_scores$group == g & survey_scores$version == v, ]
  if (nrow(row) == 0) return(NA_real_)
  row$survey_score[1]
}

deltas <- do.call(rbind, lapply(seq_len(nrow(pair_map)), function(i) {
  g <- pair_map$group[i]; a <- pair_map$snippet_a[i]; b <- pair_map$snippet_b[i]
  data.frame(
    group = g, problem = pair_map$problem[i], item = pair_map$item[i],
    pair = sprintf("%s: %s\u2192%s", pair_map$problem[i], a, b),
    A = a, B = b,
    d_CC        = lookup_metric(g, b, "CC")        - lookup_metric(g, a, "CC"),
    d_Cognitive = lookup_metric(g, b, "Cognitive") - lookup_metric(g, a, "Cognitive"),
    d_MaxNest   = lookup_metric(g, b, "MaxNest")   - lookup_metric(g, a, "MaxNest"),
    d_Survey    = lookup_survey(g, b) - lookup_survey(g, a),
    stringsAsFactors = FALSE)
}))

# Coverage report: which pairs dropped and why.
complete <- complete.cases(deltas[, c("d_CC","d_Cognitive","d_MaxNest","d_Survey")])
dropped  <- deltas[!complete, c("group","problem","item","A","B")]
usable   <- deltas[complete, ]
rownames(usable) <- NULL

message(sprintf("Usable pairs (both metrics + survey present): %d of %d.",
                nrow(usable), nrow(deltas)))
if (nrow(dropped) > 0)
  message("Dropped pairs (missing a metric or survey score): ",
          paste(sprintf("%s(%s vs %s)", dropped$item, dropped$A, dropped$B),
                collapse = ", "))
if (nrow(usable) < 3) stop("Too few usable pairs to correlate.")


## ============================================================================
## 7. CORRELATIONS  (Pearson r, Spearman rho, and a simple linear fit)
## ============================================================================
static_metrics <- c(d_CC = "Cyclomatic", d_Cognitive = "Cognitive", d_MaxNest = "Max nesting")

cor_table <- do.call(rbind, lapply(names(static_metrics), function(col) {
  x <- usable[[col]]; y <- usable$d_Survey
  pear <- suppressWarnings(cor.test(x, y, method = "pearson"))
  spear <- suppressWarnings(cor.test(x, y, method = "spearman", exact = FALSE))
  fit <- lm(y ~ x)
  data.frame(
    metric        = static_metrics[[col]],
    delta_col     = col,
    n_pairs       = length(x),
    pearson_r     = round(unname(pear$estimate), 3),
    pearson_p     = signif(pear$p.value, 3),
    r_squared     = round(summary(fit)$r.squared, 3),
    spearman_rho  = round(unname(spear$estimate), 3),
    spearman_p    = signif(spear$p.value, 3),
    slope         = round(unname(coef(fit)[2]), 2),   # survey points per metric point
    intercept     = round(unname(coef(fit)[1]), 2),
    stringsAsFactors = FALSE)
}))
rownames(cor_table) <- NULL


## ============================================================================
## 8. WRITE WORKBOOK  (deltas, correlations, aggregated metrics, survey scores)
## ============================================================================
wb <- createWorkbook()
hdr <- createStyle(textDecoration = "bold", fgFill = "#1F3864", fontColour = "white",
                   halign = "center", border = "TopBottomLeftRight",
                   borderColour = "#BFBFBF", wrapText = TRUE)
body <- createStyle(border = "TopBottomLeftRight", borderColour = "#E6E6E6", valign = "top")
add_sheet <- function(name, df, note = NULL) {
  addWorksheet(wb, name); start <- 1
  if (!is.null(note)) {
    writeData(wb, name, note, startRow = 1)
    addStyle(wb, name, createStyle(textDecoration = "italic", fontColour = "#555555"),
             rows = 1, cols = 1); start <- 3
  }
  writeData(wb, name, df, startRow = start, headerStyle = hdr, withFilter = TRUE)
  addStyle(wb, name, body, rows = (start+1):(start+nrow(df)), cols = 1:ncol(df),
           gridExpand = TRUE, stack = TRUE)
  setColWidths(wb, name, cols = 1:ncol(df), widths = "auto")
  freezePane(wb, name, firstActiveRow = start + 1)
}

readme <- data.frame(Field = c(
  "Purpose","Delta direction","Aggregation","Survey score",
  "Correlations","Slope","Usable pairs","Dropped pairs","Halstead"),
  Explanation = c(
    "How well do static-metric differences between two versions predict the survey complexity difference?",
    "Every delta is (higher version B) minus (lower version A). Positive = B more complex on that metric.",
    "Snippets with helper methods: CC and Cognitive summed across methods; MaxNest is the max across methods.",
    "0-400 per snippet from complexity_score.R logic; pair delta = B_score - A_score.",
    "Pearson r (linear), Spearman rho (rank/monotonic), R-squared, and a linear-fit slope, per metric.",
    "Survey-score points per 1-point change in the static metric (from the linear fit).",
    paste0(nrow(usable), " of ", nrow(deltas), " within-function pairs had both metrics and a survey score."),
    if (nrow(dropped)) paste(sprintf("%s(%svs%s)", dropped$item, dropped$A, dropped$B), collapse=", ") else "none",
    "Ignored, as requested."),
  stringsAsFactors = FALSE)
add_sheet("README", readme)
add_sheet("Correlations", cor_table,
          note = "Headline: how tightly each static metric's delta tracks the survey delta. |r| near 1 = strong.")
add_sheet("Pair deltas", usable[, c("group","problem","item","A","B",
                                    "d_CC","d_Cognitive","d_MaxNest","d_Survey")],
          note = "One row per usable pair. d_* are (B - A). d_Survey is the 0-400 score difference.")
add_sheet("Snippet metrics", snip_metrics,
          note = "Static metrics aggregated to one row per snippet (helpers folded in).")
add_sheet("Survey scores", survey_scores[order(survey_scores$group, survey_scores$version), ],
          note = "Per-snippet 0-400 survey complexity score used for the deltas.")
if (nrow(dropped) > 0) add_sheet("Dropped pairs", dropped,
                                 note = "Pairs excluded because a static metric or survey score was missing for one side.")

xlsx_path <- file.path(config$out_dir, "metrics_vs_survey.xlsx")
saveWorkbook(wb, xlsx_path, overwrite = TRUE)
message("Wrote workbook: ", normalizePath(xlsx_path))
write.csv(usable,   file.path(config$out_dir, "pair_deltas.csv"), row.names = FALSE)
write.csv(cor_table, file.path(config$out_dir, "correlations.csv"), row.names = FALSE)


## ============================================================================
## 9. PLOTS  — "every way possible" to see metric-delta vs survey-delta
## ============================================================================
if (config$make_plots && requireNamespace("ggplot2", quietly = TRUE)) {
  library(ggplot2)
  
  base_theme <- theme_minimal(base_size = 11) +
    theme(plot.title = element_text(face = "bold"),
          plot.subtitle = element_text(colour = "grey35"))
  
  # long form: one row per (pair, static-metric)
  long <- do.call(rbind, lapply(names(static_metrics), function(col) {
    data.frame(pair = usable$pair, group = usable$group, problem = usable$problem,
               metric = static_metrics[[col]], d_metric = usable[[col]],
               d_survey = usable$d_Survey, stringsAsFactors = FALSE)
  }))
  long$metric <- factor(long$metric, levels = unname(static_metrics))
  
  cor_lab <- setNames(sprintf("%s\n(r = %.2f, rho = %.2f)",
                              cor_table$metric, cor_table$pearson_r, cor_table$spearman_rho),
                      cor_table$metric)
  
  # ---- 9a. Faceted scatter: each static metric vs survey, with fit line ----
  p1 <- ggplot(long, aes(d_metric, d_survey)) +
    geom_hline(yintercept = 0, colour = "grey85") +
    geom_vline(xintercept = 0, colour = "grey85") +
    geom_smooth(method = "lm", se = TRUE, colour = "#2166ac",
                fill = "#c6dbef", linewidth = 0.7, formula = y ~ x) +
    geom_point(aes(colour = factor(group)), size = 2.4, alpha = 0.85) +
    facet_wrap(~ metric, scales = "free_x",
               labeller = as_labeller(cor_lab)) +
    labs(title = "Static-metric delta vs. survey complexity delta",
         subtitle = "Each point = one within-function version pair (B - A). Line = linear fit.",
         x = "Difference in static metric (B - A)",
         y = "Difference in survey score (B - A)", colour = "Problem") +
    base_theme
  ggsave(file.path(plot_dir, "01_scatter_by_metric.png"), p1,
         width = 11, height = 4.6, dpi = 150)
  
  # ---- 9b. One clean scatter per metric (bigger, labelled points) ----------
  for (col in names(static_metrics)) {
    nm <- static_metrics[[col]]
    d <- usable
    r <- cor_table$pearson_r[cor_table$delta_col == col]
    rho <- cor_table$spearman_rho[cor_table$delta_col == col]
    p <- ggplot(d, aes(.data[[col]], d_Survey)) +
      geom_hline(yintercept = 0, colour = "grey85") +
      geom_vline(xintercept = 0, colour = "grey85") +
      geom_smooth(method = "lm", se = TRUE, colour = "#2166ac",
                  fill = "#c6dbef", formula = y ~ x) +
      geom_point(aes(colour = factor(group)), size = 3) +
      ggrepel_or_text(d, col) +
      labs(title = sprintf("%s delta vs. survey complexity delta", nm),
           subtitle = sprintf("Pearson r = %.2f   Spearman rho = %.2f   (n = %d pairs)",
                              r, rho, nrow(d)),
           x = sprintf("\u0394 %s (B - A)", nm),
           y = "\u0394 survey score (B - A)", colour = "Problem") +
      base_theme
    ggsave(file.path(plot_dir, sprintf("02_scatter_%s.png", gsub("\\W+","_",nm))),
           p, width = config$plot_width, height = config$plot_height, dpi = 150)
  }
  
  # ---- 9c. Correlation strength bar (Pearson & Spearman side by side) ------
  cor_long <- rbind(
    data.frame(metric = cor_table$metric, type = "Pearson r",  value = cor_table$pearson_r),
    data.frame(metric = cor_table$metric, type = "Spearman rho", value = cor_table$spearman_rho))
  p3 <- ggplot(cor_long, aes(x = metric, y = value, fill = type)) +
    geom_col(position = position_dodge(width = 0.7), width = 0.6) +
    geom_hline(yintercept = 0, colour = "grey60") +
    geom_text(aes(label = sprintf("%.2f", value)),
              position = position_dodge(width = 0.7), vjust = ifelse(cor_long$value >= 0, -0.4, 1.2),
              size = 3) +
    scale_fill_manual(values = c("Pearson r" = "#2166ac", "Spearman rho" = "#b2182b"), name = NULL) +
    scale_y_continuous(limits = c(min(0, min(cor_long$value)) - 0.1, 1)) +
    labs(title = "How well each static metric tracks the survey score",
         subtitle = "Correlation of pair deltas. 1 = perfect; 0 = none.",
         x = NULL, y = "Correlation") +
    base_theme
  ggsave(file.path(plot_dir, "03_correlation_strength.png"), p3,
         width = config$plot_width, height = 5, dpi = 150)
  
  # ---- 9d. Slopegraph-style: paired bars of static delta vs survey delta ---
  # Rescale survey delta onto a shared 0-1 range with each metric so the
  # direction/agreement per pair is visible even at different units.
  norm01 <- function(v) if (diff(range(v)) == 0) rep(0.5, length(v)) else (v - min(v)) / diff(range(v))
  agr <- long
  agr$d_metric_n <- ave(agr$d_metric, agr$metric, FUN = norm01)
  agr$d_survey_n <- norm01(agr$d_survey)
  p4 <- ggplot(agr, aes(y = reorder(pair, d_survey))) +
    geom_segment(aes(x = d_metric_n, xend = d_survey_n, yend = pair),
                 colour = "grey75") +
    geom_point(aes(x = d_metric_n, colour = "Static metric"), size = 2) +
    geom_point(aes(x = d_survey_n, colour = "Survey"), size = 2) +
    facet_wrap(~ metric) +
    scale_colour_manual(values = c("Static metric" = "#2166ac", "Survey" = "#b2182b"), name = NULL) +
    labs(title = "Do metric and survey agree on which version is more complex?",
         subtitle = "Each row = a pair, values min-max scaled within each panel. Close dots = agreement.",
         x = "Normalised delta (0-1)", y = NULL) +
    base_theme + theme(axis.text.y = element_text(size = 6))
  ggsave(file.path(plot_dir, "04_agreement_slopegraph.png"), p4,
         width = 11, height = max(6, 0.22 * nrow(usable)), dpi = 150, limitsize = FALSE)
  
  # ---- 9e. Correlation heatmap among ALL deltas (incl. survey) -------------
  cm <- cor(usable[, c("d_CC","d_Cognitive","d_MaxNest","d_Survey")],
            use = "pairwise.complete.obs")
  cm_df <- expand.grid(x = colnames(cm), y = rownames(cm))
  cm_df$r <- as.vector(cm)
  nice <- c(d_CC = "Cyclomatic", d_Cognitive = "Cognitive",
            d_MaxNest = "Max nest", d_Survey = "Survey")
  cm_df$x <- factor(nice[as.character(cm_df$x)], levels = unname(nice))
  cm_df$y <- factor(nice[as.character(cm_df$y)], levels = rev(unname(nice)))
  p5 <- ggplot(cm_df, aes(x, y, fill = r)) +
    geom_tile(colour = "white") +
    geom_text(aes(label = sprintf("%.2f", r)), size = 3.5) +
    scale_fill_gradient2(low = "#b2182b", mid = "white", high = "#2166ac",
                         midpoint = 0, limits = c(-1, 1), name = "r") +
    labs(title = "Correlation matrix of all deltas",
         subtitle = "Pearson r between every pair of metric deltas, survey included.",
         x = NULL, y = NULL) +
    base_theme + coord_equal()
  ggsave(file.path(plot_dir, "05_delta_correlation_heatmap.png"), p5,
         width = 6.5, height = 6, dpi = 150)
  
  message("Wrote plots to: ", normalizePath(plot_dir))
}


## ============================================================================
## 10. CONSOLE REPORT
## ============================================================================
cat("\n", strrep("=", 66), "\n  STATIC METRICS vs SURVEY COMPLEXITY (pair deltas)\n",
    strrep("=", 66), "\n\n", sep = "")
cat(sprintf("Usable within-function pairs: %d of %d\n\n", nrow(usable), nrow(deltas)))
print(cor_table[, c("metric","n_pairs","pearson_r","pearson_p",
                    "spearman_rho","r_squared","slope")], row.names = FALSE)
cat("\nInterpretation: slope = survey-score points per 1-point change in the metric.\n")
cat("Files in '", config$out_dir, "/':\n", sep = "")
cat("  metrics_vs_survey.xlsx   README, Correlations, Pair deltas, Snippet metrics, Survey scores\n")
cat("  pair_deltas.csv / correlations.csv\n")
if (config$make_plots) cat("  plots/  scatter per metric, correlation bars, agreement slopegraph, heatmap\n")
cat("\nDone.\n")