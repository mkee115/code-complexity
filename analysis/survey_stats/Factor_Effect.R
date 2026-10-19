################################################################################
#  Survey-score change per ISOLATED FACTOR (orientation-corrected)
#  ---------------------------------------------------------------------------
#  Goal: "When each isolated factor is IMPROVED, what happens to the perceived-
#  complexity (survey) score on average?"
#
#  Method (as specified):
#   1. Each variant is compared to its OWN ORIG -> one survey delta
#         d_survey = survey(variant) - survey(ORIG)
#      Negative d_survey = the variant was rated SIMPLER than ORIG.
#   2. Each variant isolates one factor (from the source file's "Isolating:"
#      line). We decide whether the variant IMPROVED or WORSENED that factor:
#        - structural factors (nesting, branch count, volume, cognitive,
#          control-flow, library) -> improved if the relevant metric went DOWN.
#        - non-structural factors (comment quality, extraction, naming, layout,
#          recursion) -> use the source file's declared direction.
#   3. ORIENT the delta to "factor improved": if the variant WORSENED its
#      factor, flip the sign of d_survey. So every oriented delta answers the
#      same question: "improving this factor changed the survey score by ...".
#   4. Average the oriented deltas per factor.
#
#  Sign convention (as requested): results are read as
#      "survey score DECREASED by X on average when improving this factor"
#  so a NEGATIVE mean oriented delta = improvement made code feel SIMPLER
#  (the desired outcome); a POSITIVE mean = improving the factor ironically
#  made it feel MORE complex.
#
#  Variants whose isolated factor shows NO measurable change on our metrics
#  (e.g. an enhanced-for-loop that only moves Halstead volume) can't be
#  oriented, so they are reported separately and excluded from the averages.
#
#  Runs for BOTH survey scores: normal (0-400) and decisive (0-300).
#  HOW TO RUN:  Rscript factor_effect.R   (or Source in RStudio)
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
  out_dir  = "factor_effect_output",
  require_finished = TRUE,
  make_plots = TRUE, plot_width = 9, plot_height = 6
)
resolve_path <- function(p) if (grepl("^(/|[A-Za-z]:|\\\\\\\\)", p)) p else file.path(script_dir, p)
config$csv_file <- resolve_path(config$csv_file)
config$out_dir  <- resolve_path(config$out_dir)


## ============================================================================
## 1. VARIANT TABLE: isolated factor, the metric that defines "improved",
##    and (for non-structural factors) the declared improvement direction.
## ============================================================================
## metric = NA means "not captured by a structural metric" -> use declared_improved.
## declared_improved = TRUE/FALSE for those; NA for structural (decided by metric).
variants <- read.csv(text = '
ID,factor,metric,declared_improved
01-V1,nesting,MaxNest,NA
01-V2,multiple exits,Cognitive,NA
01-V3,volume,LOC,NA
01-V4,comment quality,NA,TRUE
01-V5,comment quality,NA,FALSE
02-V1,cognitive,Cognitive,NA
02-V2,extraction,NA,TRUE
02-V3,layout,NA,FALSE
03-V1,recursion,NA,TRUE
03-V2,volume,LOC,NA
04-V1,volume,LOC,NA
04-V2,extraction,NA,TRUE
04-V3,comment quality,NA,TRUE
05-V1,branch+nesting,MaxNest,NA
05-V2,library knowledge,CC,NA
05-V3,naming,NA,TRUE
06-V1,branch count,CC,NA
06-V2,naming,NA,TRUE
07-V1,branch count,CC,NA
07-V2,control-flow removal,CC,NA
07-V3,comment quality,NA,TRUE
08-V1,nesting,MaxNest,NA
08-V2,branch count,CC,NA
09-V1,nesting,Cognitive,NA
09-V2,control-flow removal,CC,NA
10-V1,branch count,CC,NA
10-V2,extraction,NA,TRUE
10-V3,comment quality,NA,TRUE
', stringsAsFactors = FALSE, strip.white = TRUE)
# NOTE on two edge cases, chosen deliberately:
#  - 01-V2 (multiple exits) and 09-V1 (nesting) leave MaxNest unchanged; their
#    real structural movement is in Cognitive, so metric is set to Cognitive so
#    they can still be oriented. Change to MaxNest if you prefer them excluded.


## ============================================================================
## 2. STATIC METRICS (embedded) + PAIR MAP
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
## 3. SETUP + LOAD
## ============================================================================
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

# aggregate metrics per snippet
metrics_raw$group <- as.integer(sub("-.*$", "", metrics_raw$ID))
metrics_raw$version <- sub("^[^-]*-", "", metrics_raw$ID)
snip <- do.call(rbind, lapply(split(metrics_raw, metrics_raw$ID), function(d)
  data.frame(group = d$group[1], version = d$version[1],
             CC = sum(d$CC), Cognitive = sum(d$Cognitive),
             MaxNest = max(d$MaxNest), LOC = sum(d$LOC), stringsAsFactors = FALSE)))


## ============================================================================
## 4. SURVEY SCORES per snippet (normal 0-400 and decisive 0-300)
## ============================================================================
if (!file.exists(config$csv_file)) stop("CSV not found: ", config$csv_file)
resp <- read_qualtrics(config$csv_file)
if (config$require_finished) { fin <- parse_finished(resp[["Finished"]])
if (sum(fin == 1, na.rm = TRUE) > 0) resp <- resp[!is.na(fin) & fin == 1, , drop = FALSE] }
message(sprintf("Respondents used: %d", nrow(resp)))

cn <- list(); cd <- list()
for (i in seq_len(nrow(pair_map))) {
  col <- paste0(pair_map$item[i], "i_1"); if (!col %in% names(resp)) next
  r <- parse_rating(resp[[col]]); r <- r[!is.na(r)]; n <- length(r); if (n == 0) next
  cnt <- sapply(1:5, function(k) sum(r == k)); prop <- cnt / n
  a <- sum(prop * (((1:5) - 1) * 100)); b <- sum(prop * ((5 - (1:5)) * 100))
  cn[[length(cn)+1]] <- data.frame(group = pair_map$group[i], version = pair_map$snippet_a[i], score = a)
  cn[[length(cn)+1]] <- data.frame(group = pair_map$group[i], version = pair_map$snippet_b[i], score = b)
  ndec <- n - cnt[3]
  if (ndec > 0) {
    dp <- c(cnt[1], cnt[2], cnt[4], cnt[5]) / ndec
    cd[[length(cd)+1]] <- data.frame(group = pair_map$group[i], version = pair_map$snippet_a[i], score = sum(dp*c(0,100,200,300)), w = ndec)
    cd[[length(cd)+1]] <- data.frame(group = pair_map$group[i], version = pair_map$snippet_b[i], score = sum(dp*c(300,200,100,0)), w = ndec)
  }
}
sn <- aggregate(score ~ group + version, do.call(rbind, cn), mean); names(sn)[3] <- "survey_normal"
CD <- do.call(rbind, cd)
sd_ <- do.call(rbind, lapply(split(CD, list(CD$group, CD$version), drop = TRUE), function(d)
  data.frame(group = d$group[1], version = d$version[1], survey_decisive = sum(d$score*d$w)/sum(d$w))))
survey <- merge(sn, sd_, by = c("group","version"), all = TRUE)


## ============================================================================
## 5. BUILD ORIENTED DELTAS  (variant vs its ORIG, flipped if factor worsened)
## ============================================================================
sget <- function(df, g, v, col) { r <- df[df$group == g & df$version == v, ]; if (nrow(r)) r[[col]][1] else NA }

oriented <- do.call(rbind, lapply(seq_len(nrow(variants)), function(i) {
  id <- variants$ID[i]; factor <- variants$factor[i]
  g <- as.integer(sub("-.*$", "", id)); v <- sub("^[^-]*-", "", id)
  met <- variants$metric[i]
  # direction the factor moved
  if (!is.na(met) && nzchar(met)) {
    dmet <- sget(snip, g, v, met) - sget(snip, g, "ORIG", met)
    improved <- if (is.na(dmet)) NA else if (dmet < 0) TRUE else if (dmet > 0) FALSE else NA
    basis <- sprintf("%s %+d", met, ifelse(is.na(dmet), 0L, as.integer(dmet)))
  } else {
    di <- variants$declared_improved[i]
    improved <- if (isTRUE(di)) TRUE else if (isFALSE(di)) FALSE else NA
    basis <- "declared"
  }
  mk <- function(score_col) {
    dS <- sget(survey, g, v, score_col) - sget(survey, g, "ORIG", score_col)
    if (is.na(dS) || is.na(improved))
      return(c(raw = dS, oriented = NA_real_))
    # orient to "factor improved": flip sign when the variant WORSENED the factor
    c(raw = dS, oriented = if (improved) dS else -dS)
  }
  n_ <- mk("survey_normal"); d_ <- mk("survey_decisive")
  data.frame(
    ID = id, group = g, version = v, factor = factor,
    direction = if (is.na(improved)) "no-metric-change" else if (improved) "improved" else "worsened",
    basis = basis,
    raw_delta_normal = round(unname(n_["raw"]), 1),
    oriented_delta_normal = round(unname(n_["oriented"]), 1),
    raw_delta_decisive = round(unname(d_["raw"]), 1),
    oriented_delta_decisive = round(unname(d_["oriented"]), 1),
    stringsAsFactors = FALSE)
}))
rownames(oriented) <- NULL

# usable = has an oriented delta (factor direction known AND survey score exists)
usable <- oriented[!is.na(oriented$oriented_delta_normal), ]
excluded <- oriented[is.na(oriented$oriented_delta_normal), ]
# label WHY each was excluded
excluded$reason <- ifelse(
  is.na(excluded$raw_delta_normal), "not in survey (no score for this variant)",
  "factor direction not measurable")
excluded <- excluded[, c("ID","factor","direction","basis","reason")]


## ============================================================================
## 6. AVERAGE PER FACTOR  (the headline: effect of IMPROVING each factor)
## ============================================================================
factor_summary <- do.call(rbind, lapply(split(usable, usable$factor), function(d) {
  data.frame(
    factor = d$factor[1],
    n_variants = nrow(d),
    n_improved = sum(d$direction == "improved"),
    n_worsened = sum(d$direction == "worsened"),
    mean_oriented_normal   = round(mean(d$oriented_delta_normal), 1),
    sd_oriented_normal     = round(sd(d$oriented_delta_normal), 1),
    mean_oriented_decisive = round(mean(d$oriented_delta_decisive), 1),
    stringsAsFactors = FALSE)
}))
# order by the normal-score effect (most simplifying first)
factor_summary <- factor_summary[order(factor_summary$mean_oriented_normal), ]
rownames(factor_summary) <- NULL


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
  "Question", "Delta", "Orientation", "Sign convention", "Averaging",
  "no-metric-change", "Scores"),
  Explanation = c(
    "When each isolated factor is IMPROVED, what is the average change in the survey complexity score?",
    "d_survey = survey(variant) - survey(ORIG). Negative = variant rated simpler.",
    "If the variant WORSENED its factor, d_survey is sign-flipped so every value means 'factor improved'.",
    "Negative mean = improving the factor made code feel SIMPLER (good). Positive = it felt more complex.",
    "Mean of oriented deltas across the variants that isolate each factor.",
    "Variants whose factor didn't move on our metrics (can't be oriented) are excluded and listed separately.",
    "normal = 0-400 survey score; decisive = 0-300 (neutral votes excluded)."),
  stringsAsFactors = FALSE)
add_sheet("README", readme)
add_sheet("Factor summary", factor_summary,
          note = "HEADLINE: mean oriented survey delta per factor. Negative = improving it reduced perceived complexity.")
add_sheet("Per variant", oriented,
          note = "Each variant vs its ORIG: raw and orientation-corrected survey deltas, and factor direction.")
if (nrow(excluded) > 0) add_sheet("Excluded", excluded,
                                  note = "Factor direction couldn't be determined from our metrics; excluded from averages.")
add_sheet("Survey scores", survey)
saveWorkbook(wb, file.path(config$out_dir, "factor_effect.xlsx"), overwrite = TRUE)
write.csv(factor_summary, file.path(config$out_dir, "factor_summary.csv"), row.names = FALSE)
write.csv(oriented,       file.path(config$out_dir, "per_variant.csv"), row.names = FALSE)
message("Wrote workbook + CSVs to: ", normalizePath(config$out_dir))


## ============================================================================
## 8. PLOTS
## ============================================================================
if (config$make_plots && requireNamespace("ggplot2", quietly = TRUE)) {
  library(ggplot2)
  base_theme <- theme_minimal(base_size = 11) +
    theme(plot.title = element_text(face = "bold"), legend.position = "bottom")
  
  # ---- 8a. HEADLINE bar: mean oriented delta per factor (normal) ----------
  fs <- factor_summary
  fs$factor <- factor(fs$factor, levels = fs$factor[order(fs$mean_oriented_normal)])
  p1 <- ggplot(fs, aes(x = mean_oriented_normal, y = factor,
                       fill = mean_oriented_normal < 0)) +
    geom_col(width = 0.7) +
    geom_vline(xintercept = 0, colour = "grey40") +
    geom_text(aes(label = sprintf("%+.0f", mean_oriented_normal)),
              hjust = ifelse(fs$mean_oriented_normal < 0, 1.1, -0.1), size = 3.2) +
    scale_fill_manual(values = c("TRUE" = "#1b7837", "FALSE" = "#b2182b"),
                      labels = c("TRUE" = "felt simpler", "FALSE" = "felt more complex"),
                      name = NULL) +
    labs(title = "Average survey-score change when each factor is IMPROVED",
         subtitle = "Negative (green) = improving the factor made code feel simpler. Normal 0-400 score.",
         x = "Mean oriented survey delta (survey points)", y = NULL) +
    base_theme
  ggsave(file.path(plot_dir, "01_factor_mean_effect.png"), p1,
         width = config$plot_width, height = config$plot_height, dpi = 150)
  
  # ---- 8b. Per-variant oriented deltas, grouped by factor (spread) --------
  uv <- usable
  uv$factor <- factor(uv$factor, levels = fs$factor)
  p2 <- ggplot(uv, aes(x = oriented_delta_normal, y = factor)) +
    geom_vline(xintercept = 0, colour = "grey60") +
    geom_point(aes(colour = direction), size = 3, alpha = 0.85) +
    stat_summary(fun = mean, geom = "point", shape = 124, size = 8, colour = "black") +
    scale_colour_manual(values = c("improved" = "#1b7837", "worsened" = "#d6604d"), name = NULL) +
    labs(title = "Oriented survey delta per variant (grouped by isolated factor)",
         subtitle = "Each dot = one variant (sign-flipped if it worsened its factor). Black bar = factor mean.",
         x = "Oriented survey delta", y = NULL) +
    base_theme
  ggsave(file.path(plot_dir, "02_per_variant_oriented.png"), p2,
         width = config$plot_width, height = max(config$plot_height, 0.45 * nrow(fs) + 3), dpi = 150)
  
  # ---- 8c. Normal vs decisive side by side --------------------------------
  cmp <- rbind(
    data.frame(factor = factor_summary$factor, score = "normal (0-400)",
               mean = factor_summary$mean_oriented_normal),
    data.frame(factor = factor_summary$factor, score = "decisive (0-300)",
               mean = factor_summary$mean_oriented_decisive))
  cmp$factor <- factor(cmp$factor, levels = fs$factor)
  p3 <- ggplot(cmp, aes(x = mean, y = factor, fill = score)) +
    geom_col(position = position_dodge(width = 0.7), width = 0.6) +
    geom_vline(xintercept = 0, colour = "grey40") +
    scale_fill_manual(values = c("normal (0-400)" = "#2166ac", "decisive (0-300)" = "#f4a582"), name = NULL) +
    labs(title = "Factor effect: normal vs decisive survey score",
         subtitle = "Negative = improving the factor reduced perceived complexity.",
         x = "Mean oriented survey delta", y = NULL) +
    base_theme
  ggsave(file.path(plot_dir, "03_normal_vs_decisive.png"), p3,
         width = config$plot_width, height = config$plot_height, dpi = 150)
  
  message("Wrote plots to: ", normalizePath(plot_dir))
}


## ============================================================================
## 9. CONSOLE REPORT
## ============================================================================
cat("\n", strrep("=", 66), "\n  EFFECT OF IMPROVING EACH ISOLATED FACTOR\n", strrep("=", 66), "\n\n", sep = "")
cat("Read as: survey score changed by this much on average when the factor was improved.\n")
cat("(negative = code felt SIMPLER; positive = felt MORE complex)\n\n")
print(factor_summary[, c("factor","n_variants","n_improved","n_worsened",
                         "mean_oriented_normal","mean_oriented_decisive")], row.names = FALSE)
if (nrow(excluded) > 0) {
  cat("\nExcluded (factor direction not measurable on our metrics):\n")
  print(excluded, row.names = FALSE)
}
cat("\nFiles in '", config$out_dir, "/':\n", sep = "")
cat("  factor_effect.xlsx, factor_summary.csv, per_variant.csv\n")
if (config$make_plots) cat("  plots/ (01 mean effect, 02 per-variant spread, 03 normal vs decisive)\n")
cat("\nDone.\n")