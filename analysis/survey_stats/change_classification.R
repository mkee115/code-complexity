################################################################################
#  Change classification + survey-score sensitivity per metric
#  ---------------------------------------------------------------------------
#  Two deliverables:
#
#  PART A - Classify every variant's MAIN CHANGE
#    The source file declares each variant's intent in its "Isolating:" line
#    (nesting, branch count, volume, extraction, naming, comment quality, ...).
#    We use that as the main-change CATEGORY, then mark, for each structural
#    metric (Cyclomatic, Cognitive, Max nesting), whether the variant IMPROVED
#    (metric went down vs ORIG), WORSENED (went up), or left it UNCHANGED.
#
#  PART B - "What happens to the survey score per 1-point change in a metric?"
#    For each snippet PAIR, slope = (survey delta) / (metric delta), i.e. how
#    many survey-score points move per single point of Cyclomatic / Cognitive /
#    Max-nesting difference. Pairs whose metric delta is 0 are dropped for that
#    metric (division by zero / undefined slope). Shown as box-and-whisker
#    across pairs, per metric, plus supporting views.
#
#    Produced TWO ways, as requested:
#      - all-combo : every within-function pair (matches the survey design)
#      - orig-only : each variant compared only against its ORIG
#    and for BOTH survey scores: normal (0-400) and decisive (0-300).
#
#  Reads the same Qualtrics CSV. Static metrics are embedded.
#  HOW TO RUN:  Rscript change_classification.R   (or Source in RStudio)
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
  out_dir  = "change_classification_output",
  require_finished = TRUE,
  make_plots = TRUE,
  plot_width = 9, plot_height = 6
)
resolve_path <- function(p) if (grepl("^(/|[A-Za-z]:|\\\\\\\\)", p)) p else file.path(script_dir, p)
config$csv_file <- resolve_path(config$csv_file)
config$out_dir  <- resolve_path(config$out_dir)


## ============================================================================
## 1. STATIC METRICS + declared "Isolating" category per variant
## ============================================================================
metrics_raw <- read.csv(text = "
ID,method,CC,Cognitive,MaxNest,LOC
01-ORIG,grade,5,14,4,21
01-V1,grade,5,4,1,15
01-V2,grade,5,5,4,15
01-V3,grade,5,4,0,3
01-V4,grade,5,14,4,21
01-V5,grade,5,14,4,21
02-ORIG,check,6,2,1,8
02-V1,check,6,5,1,18
02-V2,check,4,1,0,3
02-V2,hasMinLength,1,0,0,3
02-V2,hasLowerAndUpper,2,1,0,3
02-V2,hasDigit,1,0,0,3
02-V3,check,6,2,1,7
03-ORIG,sd,3,4,1,9
03-V1,sd,2,1,1,9
03-V2,sd,3,4,1,6
04-ORIG,max,4,6,3,11
04-V1,max,4,6,3,11
04-V2,max,2,2,1,7
04-V2,rowMax,3,3,2,9
04-V3,max,4,6,3,11
05-ORIG,dedupe,5,8,3,15
05-V1,dedupe,3,3,2,9
05-V2,dedupe,1,0,0,3
05-V3,removeDuplicates,5,8,3,15
06-ORIG,tally,3,4,2,12
06-V1,tally,2,1,1,7
06-V2,countByValue,3,4,2,12
07-ORIG,merge,6,7,2,27
07-V1,merge,4,5,2,16
07-V2,merge,1,0,0,7
07-V3,merge,6,7,2,27
08-ORIG,roman,4,8,3,16
08-ORIG,value,8,1,1,12
08-V1,roman,4,5,2,12
08-V1,value,8,1,1,12
08-V2,roman,3,4,2,14
08-V2,value,8,1,1,12
09-ORIG,bs,4,8,3,17
09-V1,bs,4,5,2,15
09-V2,bs,2,1,0,4
10-ORIG,balanced,15,28,4,26
10-V1,balanced,6,10,3,17
10-V2,balanced,6,8,3,14
10-V2,matches,1,0,0,3
10-V3,balanced,15,28,4,26
", stringsAsFactors = FALSE, strip.white = TRUE)

# Declared main-change category per variant (from the 'Isolating:' lines).
isolating <- read.csv(text = "
ID,category
01-V1,nesting
01-V2,multiple exits
01-V3,volume
01-V4,comment quality
01-V5,comment quality
02-V1,cognitive
02-V2,extraction
02-V3,layout
03-V1,recursion
03-V2,volume
04-V1,volume
04-V2,extraction
04-V3,comment quality
05-V1,branch+nesting
05-V2,library knowledge
05-V3,naming
06-V1,branch count
06-V2,naming
07-V1,branch count
07-V2,control-flow removal
07-V3,comment quality
08-V1,nesting
08-V2,branch count
09-V1,nesting
09-V2,control-flow removal
10-V1,branch count
10-V2,extraction
10-V3,comment quality
", stringsAsFactors = FALSE, strip.white = TRUE)

# Which structural metric each category is *primarily* aimed at (for the
# headline improve/worsen call). All three are reported regardless.
primary_metric <- c(
  "nesting" = "MaxNest", "branch+nesting" = "MaxNest", "multiple exits" = "MaxNest",
  "extraction" = "MaxNest", "branch count" = "CC", "control-flow removal" = "CC",
  "recursion" = "CC", "library knowledge" = "CC", "cognitive" = "Cognitive",
  "volume" = "LOC", "naming" = "LOC", "layout" = "LOC", "comment quality" = "LOC")


## ============================================================================
## 2. PAIR MAP (43 within-function pairs) + setup + loaders
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

ensure_pkg <- function(p) if (!requireNamespace(p, quietly = TRUE)) {
  message("Installing: ", p); install.packages(p, repos = "https://cloud.r-project.org") }
ensure_pkg("openxlsx"); if (config$make_plots) ensure_pkg("ggplot2")
library(openxlsx)
dir.create(config$out_dir, showWarnings = FALSE, recursive = TRUE)
plot_dir <- file.path(config$out_dir, "plots")
if (config$make_plots) dir.create(plot_dir, showWarnings = FALSE, recursive = TRUE)

read_qualtrics <- function(path) {
  d <- utils::read.csv(path, header = TRUE, check.names = FALSE, stringsAsFactors = FALSE,
                       colClasses = "character", quote = "\"", fill = TRUE, na.strings = c("", "NA"))
  names(d)[1] <- sub("^\ufeff", "", names(d)[1])
  if (nrow(d) > 2) d[-(1:2), , drop = FALSE] else d[0, , drop = FALSE]
}
parse_finished <- function(x) { x <- trimws(tolower(as.character(x)))
ifelse(x %in% c("1","true","t","yes","finished"), 1, ifelse(x %in% c("0","false","f","no",""), 0, NA)) }
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


## ============================================================================
## 3. AGGREGATE METRICS PER SNIPPET  (CC/Cognitive summed, MaxNest/LOC: max/sum)
## ============================================================================
metrics_raw$group   <- as.integer(sub("-.*$", "", metrics_raw$ID))
metrics_raw$version <- sub("^[^-]*-", "", metrics_raw$ID)
snip <- do.call(rbind, lapply(split(metrics_raw, metrics_raw$ID), function(d)
  data.frame(group = d$group[1], version = d$version[1],
             CC = sum(d$CC), Cognitive = sum(d$Cognitive),
             MaxNest = max(d$MaxNest), LOC = sum(d$LOC), stringsAsFactors = FALSE)))
rownames(snip) <- NULL


## ============================================================================
## 4. PART A - CLASSIFY EACH VARIANT vs ITS ORIG
## ============================================================================
orig <- snip[snip$version == "ORIG", ]
rownames(orig) <- orig$group
dir_word <- function(delta) ifelse(delta < 0, "improves",
                                   ifelse(delta > 0, "worsens", "unchanged"))

classify <- do.call(rbind, lapply(seq_len(nrow(isolating)), function(i) {
  id <- isolating$ID[i]; cat <- isolating$category[i]
  g  <- as.integer(sub("-.*$", "", id)); v <- sub("^[^-]*-", "", id)
  sv <- snip[snip$group == g & snip$version == v, ]
  ov <- orig[as.character(g), ]
  if (nrow(sv) == 0) return(NULL)
  dCC <- sv$CC - ov$CC; dCog <- sv$Cognitive - ov$Cognitive
  dNest <- sv$MaxNest - ov$MaxNest; dLOC <- sv$LOC - ov$LOC
  pm <- primary_metric[[cat]]; if (is.null(pm)) pm <- "CC"
  dprim <- switch(pm, CC = dCC, Cognitive = dCog, MaxNest = dNest, LOC = dLOC)
  data.frame(
    ID = id, group = g, version = v, category = cat,
    primary_metric = pm, primary_effect = dir_word(dprim),
    dCC = dCC, dCognitive = dCog, dMaxNest = dNest, dLOC = dLOC,
    CC_effect = dir_word(dCC), Cognitive_effect = dir_word(dCog),
    MaxNest_effect = dir_word(dNest), LOC_effect = dir_word(dLOC),
    stringsAsFactors = FALSE)
}))
rownames(classify) <- NULL


## ============================================================================
## 5. SURVEY SCORES  (normal 0-400 and decisive 0-300), per snippet
## ============================================================================
if (!file.exists(config$csv_file)) stop("CSV not found: ", config$csv_file)
resp <- read_qualtrics(config$csv_file)
if (config$require_finished) { fin <- parse_finished(resp[["Finished"]])
if (sum(fin == 1, na.rm = TRUE) > 0) resp <- resp[!is.na(fin) & fin == 1, , drop = FALSE] }
message(sprintf("Respondents used: %d", nrow(resp)))

# per-comparison A/B scores, then per-snippet means (normal) / weighted (decisive)
cn <- list(); cd <- list()
for (i in seq_len(nrow(pair_map))) {
  col <- paste0(pair_map$item[i], "i_1"); if (!col %in% names(resp)) next
  r <- parse_rating(resp[[col]]); r <- r[!is.na(r)]; n <- length(r); if (n == 0) next
  cnt <- sapply(1:5, function(k) sum(r == k)); prop <- cnt / n
  a <- sum(prop * (( (1:5) - 1) * 100)); b <- sum(prop * ((5 - (1:5)) * 100))
  cn[[length(cn)+1]] <- data.frame(group = pair_map$group[i], version = pair_map$snippet_a[i], score = a)
  cn[[length(cn)+1]] <- data.frame(group = pair_map$group[i], version = pair_map$snippet_b[i], score = b)
  ndec <- n - cnt[3]
  if (ndec > 0) {
    dp <- c(cnt[1], cnt[2], cnt[4], cnt[5]) / ndec
    ad <- sum(dp * c(0,100,200,300)); bd <- sum(dp * c(300,200,100,0))
    cd[[length(cd)+1]] <- data.frame(group = pair_map$group[i], version = pair_map$snippet_a[i], score = ad, w = ndec)
    cd[[length(cd)+1]] <- data.frame(group = pair_map$group[i], version = pair_map$snippet_b[i], score = bd, w = ndec)
  }
}
CN <- do.call(rbind, cn); CD <- do.call(rbind, cd)
surv_normal <- aggregate(score ~ group + version, CN, mean)
names(surv_normal)[3] <- "survey_normal"
surv_dec <- do.call(rbind, lapply(split(CD, list(CD$group, CD$version), drop = TRUE), function(d)
  data.frame(group = d$group[1], version = d$version[1],
             survey_decisive = sum(d$score * d$w) / sum(d$w))))
survey <- merge(surv_normal, surv_dec, by = c("group","version"), all = TRUE)


## ============================================================================
## 6. PART B - PER-PAIR SLOPES: survey delta per 1-point metric delta
## ============================================================================
sget <- function(df, g, v, col) { r <- df[df$group == g & df$version == v, ]; if (nrow(r)) r[[col]][1] else NA }

build_slopes <- function(pairs, survey_col, tag_scope, tag_score) {
  do.call(rbind, lapply(seq_len(nrow(pairs)), function(i) {
    g <- pairs$group[i]; a <- pairs$snippet_a[i]; b <- pairs$snippet_b[i]
    dSurv <- sget(survey, g, b, survey_col) - sget(survey, g, a, survey_col)
    dCC   <- sget(snip, g, b, "CC")        - sget(snip, g, a, "CC")
    dCog  <- sget(snip, g, b, "Cognitive") - sget(snip, g, a, "Cognitive")
    dNest <- sget(snip, g, b, "MaxNest")   - sget(snip, g, a, "MaxNest")
    if (is.na(dSurv)) return(NULL)
    mk <- function(metric, dm) if (is.na(dm) || dm == 0) NULL else
      data.frame(scope = tag_scope, score = tag_score, group = g,
                 problem = pairs$problem[i], pair = sprintf("%s->%s", a, b),
                 metric = metric, d_metric = dm, d_survey = dSurv,
                 slope = dSurv / dm, stringsAsFactors = FALSE)
    rbind(mk("Cyclomatic", dCC), mk("Cognitive", dCog), mk("Max nesting", dNest))
  }))
}

orig_pairs <- pair_map[pair_map$snippet_a == "ORIG", ]
slopes <- rbind(
  build_slopes(pair_map,   "survey_normal",   "all-combo", "normal"),
  build_slopes(orig_pairs, "survey_normal",   "orig-only", "normal"),
  build_slopes(pair_map,   "survey_decisive", "all-combo", "decisive"),
  build_slopes(orig_pairs, "survey_decisive", "orig-only", "decisive"))
slopes$metric <- factor(slopes$metric, levels = c("Cyclomatic","Cognitive","Max nesting"))

# summary of slopes per metric x scope x score
slope_summary <- do.call(rbind, lapply(
  split(slopes, list(slopes$metric, slopes$scope, slopes$score), drop = TRUE),
  function(d) data.frame(
    metric = d$metric[1], scope = d$scope[1], score = d$score[1],
    n_pairs = nrow(d),
    median_slope = round(median(d$slope), 1),
    mean_slope   = round(mean(d$slope), 1),
    q1 = round(quantile(d$slope, .25), 1), q3 = round(quantile(d$slope, .75), 1),
    min = round(min(d$slope), 1), max = round(max(d$slope), 1),
    stringsAsFactors = FALSE)))
rownames(slope_summary) <- NULL


## ============================================================================
## 7. WORKBOOK
## ============================================================================
wb <- createWorkbook()
hdr <- createStyle(textDecoration = "bold", fgFill = "#1F3864", fontColour = "#FFFFFF",
                   halign = "center", border = "TopBottomLeftRight", borderColour = "#BFBFBF", wrapText = TRUE)
bod <- createStyle(border = "TopBottomLeftRight", borderColour = "#E6E6E6", valign = "top")
add_sheet <- function(name, df, note = NULL) {
  addWorksheet(wb, name); start <- 1
  if (!is.null(note)) { writeData(wb, name, note, startRow = 1)
    addStyle(wb, name, createStyle(textDecoration = "italic", fontColour = "#555555"), rows = 1, cols = 1); start <- 3 }
  writeData(wb, name, df, startRow = start, headerStyle = hdr, withFilter = TRUE)
  addStyle(wb, name, bod, rows = (start+1):(start+nrow(df)), cols = 1:ncol(df), gridExpand = TRUE, stack = TRUE)
  setColWidths(wb, name, cols = 1:ncol(df), widths = "auto"); freezePane(wb, name, firstActiveRow = start + 1)
}
readme <- data.frame(Field = c(
  "Part A - classification", "Category source", "improves / worsens",
  "Primary vs all metrics", "Part B - slope", "Metric delta = 0",
  "Scopes", "Scores", "Box plot"),
  Explanation = c(
    "Each variant's declared main change, and whether it improved/worsened each metric vs its ORIG.",
    "The 'Isolating:' line in the source file (researcher-declared intent).",
    "improves = metric went DOWN vs ORIG; worsens = went UP; unchanged = no difference.",
    "primary_metric is the metric the category targets; CC/Cognitive/MaxNest/LOC effects are all reported too.",
    "survey-score change per 1-point metric change = (survey delta) / (metric delta) for a pair.",
    "Pairs with no change in a metric are dropped for THAT metric (slope undefined).",
    "all-combo = every within-function pair; orig-only = each variant vs its ORIG.",
    "normal = 0-400 survey score; decisive = 0-300 (neutral votes excluded).",
    "Box-and-whisker of per-pair slopes, one box per metric; a tall box = survey reacts inconsistently to that metric."),
  stringsAsFactors = FALSE)
add_sheet("README", readme)
add_sheet("A_classification", classify,
          note = "Per variant: declared category + improve/worsen on each metric vs ORIG.")
add_sheet("B_slopes", slopes[, c("scope","score","group","problem","pair","metric","d_metric","d_survey","slope")],
          note = "Per pair per metric: survey delta, metric delta, and slope (survey pts per metric pt).")
add_sheet("B_slope_summary", slope_summary,
          note = "Distribution of slopes per metric x scope x score (median, mean, quartiles, range).")
add_sheet("Snippet metrics", snip)
add_sheet("Survey scores", survey)
saveWorkbook(wb, file.path(config$out_dir, "change_classification.xlsx"), overwrite = TRUE)
write.csv(classify,      file.path(config$out_dir, "classification.csv"), row.names = FALSE)
write.csv(slopes,        file.path(config$out_dir, "slopes.csv"), row.names = FALSE)
write.csv(slope_summary, file.path(config$out_dir, "slope_summary.csv"), row.names = FALSE)
message("Wrote workbook + CSVs to: ", normalizePath(config$out_dir))


## ============================================================================
## 8. PLOTS
## ============================================================================
if (config$make_plots && requireNamespace("ggplot2", quietly = TRUE)) {
  library(ggplot2)
  base_theme <- theme_minimal(base_size = 11) +
    theme(plot.title = element_text(face = "bold"), legend.position = "bottom")
  mcol <- c("Cyclomatic" = "#d6604d", "Cognitive" = "#f4a582", "Max nesting" = "#762a83")
  
  # ---- 8a. BOX-AND-WHISKER of slopes per metric (faceted scope x score) ----
  p1 <- ggplot(slopes, aes(x = metric, y = slope, fill = metric)) +
    geom_hline(yintercept = 0, colour = "grey70") +
    geom_boxplot(outlier.shape = NA, alpha = 0.6, width = 0.6) +
    geom_jitter(width = 0.15, size = 1.4, alpha = 0.6) +
    facet_grid(score ~ scope) +
    scale_fill_manual(values = mcol, guide = "none") +
    labs(title = "Survey-score change per 1-point metric change",
         subtitle = "Each point = one pair's slope (survey delta / metric delta). Box = spread across pairs.",
         x = NULL, y = "Survey points per 1 metric point") +
    base_theme
  ggsave(file.path(plot_dir, "01_slope_boxplot.png"), p1,
         width = 10, height = 7.5, dpi = 150)
  
  # ---- 8b. Focused box plot: all-combo, normal score only (clean headline) --
  d2 <- slopes[slopes$scope == "all-combo" & slopes$score == "normal", ]
  p2 <- ggplot(d2, aes(metric, slope, fill = metric)) +
    geom_hline(yintercept = 0, colour = "grey70") +
    geom_boxplot(outlier.shape = NA, alpha = 0.6, width = 0.6) +
    geom_jitter(width = 0.15, size = 2, alpha = 0.7) +
    scale_fill_manual(values = mcol, guide = "none") +
    labs(title = "Survey sensitivity to each metric (all pairs, normal score)",
         subtitle = "Higher & tighter box = the survey moves more, and more predictably, with that metric.",
         x = NULL, y = "Survey points per 1 metric point") +
    base_theme
  ggsave(file.path(plot_dir, "02_slope_boxplot_headline.png"), p2,
         width = config$plot_width, height = config$plot_height, dpi = 150)
  
  # ---- 8c. Raw scatter: metric delta vs survey delta (the slope's basis) ----
  d3 <- slopes[slopes$scope == "all-combo" & slopes$score == "normal", ]
  p3 <- ggplot(d3, aes(d_metric, d_survey, colour = metric)) +
    geom_hline(yintercept = 0, colour = "grey85") + geom_vline(xintercept = 0, colour = "grey85") +
    geom_abline(slope = 0, intercept = 0, colour = NA) +
    geom_smooth(method = "lm", se = FALSE, formula = y ~ x, linewidth = 0.7) +
    geom_point(size = 2, alpha = 0.8) +
    facet_wrap(~ metric, scales = "free_x") +
    scale_colour_manual(values = mcol, guide = "none") +
    labs(title = "Metric delta vs survey delta (per pair)",
         subtitle = "The slope box plot summarises the spread of point-by-point ratios shown here.",
         x = "Metric delta (B - A)", y = "Survey delta (B - A)") +
    base_theme
  ggsave(file.path(plot_dir, "03_delta_scatter.png"), p3, width = 11, height = 4.6, dpi = 150)
  
  # ---- 8d. PART A: count of improve/worsen/unchanged per category ----------
  eff_long <- do.call(rbind, lapply(c("CC","Cognitive","MaxNest"), function(mm) {
    data.frame(category = classify$category, metric = mm,
               effect = classify[[paste0(mm, "_effect")]], stringsAsFactors = FALSE)
  }))
  eff_long$effect <- factor(eff_long$effect, levels = c("improves","unchanged","worsens"))
  p4 <- ggplot(eff_long, aes(x = category, fill = effect)) +
    geom_bar() +
    facet_wrap(~ metric) +
    scale_fill_manual(values = c("improves" = "#1b7837", "unchanged" = "#bdbdbd",
                                 "worsens" = "#b2182b"), name = NULL) +
    labs(title = "Effect of each change category on each metric (vs ORIG)",
         subtitle = "How the declared changes moved cyclomatic, cognitive, and nesting complexity.",
         x = NULL, y = "Number of variants") +
    base_theme +
    theme(axis.text.x = element_text(angle = 40, hjust = 1, size = 8))
  ggsave(file.path(plot_dir, "04_classification_effects.png"), p4, width = 12, height = 5.5, dpi = 150)
  
  message("Wrote plots to: ", normalizePath(plot_dir))
}


## ============================================================================
## 9. CONSOLE REPORT
## ============================================================================
cat("\n", strrep("=", 66), "\n  CHANGE CLASSIFICATION + SURVEY SENSITIVITY\n", strrep("=", 66), "\n\n", sep = "")
cat("PART A - classification (declared category, effect on primary metric):\n")
print(classify[, c("ID","category","primary_metric","primary_effect",
                   "dCC","dCognitive","dMaxNest")], row.names = FALSE)
cat("\nPART B - slope distribution (survey points per 1 metric point):\n")
print(slope_summary, row.names = FALSE)
cat("\nFiles in '", config$out_dir, "/':\n", sep = "")
cat("  change_classification.xlsx, classification.csv, slopes.csv, slope_summary.csv\n")
if (config$make_plots) cat("  plots/ (01 slope box all facets, 02 headline box, 03 delta scatter, 04 category effects)\n")
cat("\nDone.\n")