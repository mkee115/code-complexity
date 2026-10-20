#!/usr/bin/env Rscript
# ============================================================================
# survey_analysis.R
# Pairwise complexity survey (COMPSCI 701) - analysis pipeline
#
# Runs on base R alone (no external packages required). If run in RStudio with
# openxlsx installed, it will additionally emit an .xlsx workbook per policy.
#
# The whole analysis runs TWICE under two inclusion policies:
#   "inclusive"  all real submissions with >=20% progress (previews dropped)
#   "strict"     finished submissions whose respondent answered every Java
#                screening question correctly (java_score == 3)
#
# For each policy it writes, under OUT_DIR/<policy>/ :
#   data/survey_long.csv         one row per respondent x comparison item
#   data/per_item_summary.csv    net preference, %A/B/none, agreement, sign test
#   data/respondents.csv         cleaned respondent-level table
#   data/expert_vs_novice.csv    item means split by Java screening score
#   data/human_orderings.csv     human difficulty ordering per question
#   data/orderings_all.csv       HUMAN + every metric ordering, per question,
#                                stacked (the single side-by-side comparison table)
#   data/orderings_wide.csv      per (question,variant): human_rank + each metric value
#   data/metric_agreement_per_question.csv  spearman/kendall/pair_concordance/
#                                top_match for each (question,metric)
#   data/metric_agreement_overall.csv       each stat averaged per metric, ranked
#   data/per_question_winner.csv the best-agreeing metric for each question
#   data/pair_map_used.csv       the letter -> (variant pair) map applied
#   figures/fig6_metric_agreement.png       overall ranking of metrics
#   figures/fig7_per_question_agreement.png question x metric concordance heatmap
#   run_summary.txt              headline counts
#   survey_analysis.xlsx         (only if openxlsx available)
#
# ---- WHAT YOU MUST SUPPLY -------------------------------------------------
# The Qualtrics export does NOT record which two variants each lettered
# comparison (Q1A, Q1B, ...) showed, nor which snippet was "Method A".
# Two small maps encode that; sensible DEFAULTS are built in and can be
# overridden by dropping CSVs next to the script:
#
#   pair_map.csv   columns: question,letter,variant_A,variant_B
#                  Default = canonical all-pairs ORIG,V1,V2,... in (i<j) order.
#
#   variant_metrics.csv  columns: question,variant, then one metric per column
#                  (CC,Cognitive,LOC,MaxNest,FanOut,HalVol,HalEff,AvgIdW).
#                  Needed for the metric-vs-human agreement. A starter file is
#                  written to OUT_DIR/variant_metrics_template.csv on first run.
# ============================================================================

SRC     <- "./700_survey.csv"
OUT_DIR <- "./survey_output"
PAIR_MAP_FILE         <- "./pair_map.csv"          # optional override
VARIANT_METRICS_FILE  <- "./variant_metrics.csv"   # optional; enables metric agreement

dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)

# Self-contained xlsx writer (no packages) used for the per-question ordering
# grid workbook. Expected alongside this script as xlsx_writer.R.
if (file.exists("xlsx_writer.R")) {
  source("xlsx_writer.R")
} else {
  warning("xlsx_writer.R not found next to survey_analysis.R; ordering_grids.xlsx ",
          "will be skipped (the CSV grid is still written).")
  write_xlsx_grids <- function(...) invisible(NULL)
}

# ============================================================================
# LOAD RAW (once)
# ============================================================================
raw <- read.csv(SRC, header = FALSE, stringsAsFactors = FALSE,
                colClasses = "character", check.names = FALSE)
H   <- as.character(raw[1, ])
dat_all <- raw[-(1:3), , drop = FALSE]
colnames(dat_all) <- H
rownames(dat_all) <- NULL

is_choice    <- grepl("^Q[0-9]+[A-J]i_1$", H)
choice_names <- H[is_choice]
item_of      <- sub("i_1$", "", choice_names)
choice_idx   <- which(is_choice)
# Q126_1 is Q7's 6th comparison (V2 vs V3); Qualtrics stored it under a loose
# name rather than Q7Fi_1. Fold it into the Q7 block as letter F so Q7 is a
# complete 4-variant, 6-comparison all-pairs set like Q1/Q2.
sp_idx <- match("Q126_1", H)
if (!is.na(sp_idx)) { choice_idx <- c(choice_idx, sp_idx); item_of <- c(item_of, "Q7F") }

parse_signed <- function(x) {
  x <- trimws(x); out <- rep(NA_real_, length(x))
  out[x == "Method A is much less complex"]     <-  2
  out[x == "Method A is slightly less complex"] <-  1
  out[x == "No difference"]                      <-  0
  out[x == "Method B is slightly less complex"] <- -1
  out[x == "Method B is much less complex"]     <- -2
  out
}
chosen_side <- function(x) {
  x <- trimws(x); s <- rep(NA_character_, length(x))
  s[grepl("Method A", x)] <- "A"; s[grepl("Method B", x)] <- "B"
  s[x == "No difference"] <- "none"; s
}
java_key <- list(`Java Q1` = "C", `Java Q2` = "2", `Java Q3` = "24")

# ---------------------------------------------------------------------------
# PAIR MAP (default = canonical all-pairs of ORIG,V1,V2,... in i<j order)
# ---------------------------------------------------------------------------
base_items <- item_of[grepl("^Q[0-9]+[A-J]$", item_of)]
q_of_item  <- sub("^(Q[0-9]+).*", "\\1", base_items)
letters_per_q <- tapply(base_items, q_of_item,
                        function(v) sort(sub("^Q[0-9]+", "", v)))

# Pairs are always presented in the fixed order:
#   ORIG-V1, ORIG-V2, ..., V1-V2, V1-V3, ..., V2-V3, ...  (i<j, i outer loop).
# A question with a partial set (e.g. Q7 has 5 = the first 5 of the 6 pairs
# among 4 variants) is handled by choosing the SMALLEST k whose all-pairs count
# is >= ncmp, then taking the first ncmp pairs in that fixed order.
build_default_pair_map <- function() {
  rows <- list()
  for (q in names(letters_per_q)) {
    lets <- letters_per_q[[q]]; ncmp <- length(lets)
    k <- min((2:9)[sapply(2:9, function(kk) kk*(kk-1)/2) >= ncmp])
    variants <- c("ORIG", paste0("V", seq_len(k - 1)))
    prs <- t(combn(seq_len(k), 2))          # already in i<j (fixed) order
    for (r in seq_len(ncmp)) {
      rows[[length(rows) + 1]] <- data.frame(
        question = q, letter = lets[r],
        variant_A = variants[prs[r, 1]], variant_B = variants[prs[r, 2]],
        stringsAsFactors = FALSE)
    }
  }
  do.call(rbind, rows)
}
pair_map <- if (file.exists(PAIR_MAP_FILE)) read.csv(PAIR_MAP_FILE, stringsAsFactors = FALSE) else build_default_pair_map()
pair_map$item <- paste0(pair_map$question, pair_map$letter)

# ============================================================================
# CORE ANALYSIS FUNCTION - one inclusion policy
# ============================================================================
run_policy <- function(policy) {
  odir <- file.path(OUT_DIR, policy)
  fdir <- file.path(odir, "figures"); ddir <- file.path(odir, "data")
  dir.create(fdir, recursive = TRUE, showWarnings = FALSE)
  dir.create(ddir, recursive = TRUE, showWarnings = FALSE)
  
  d <- dat_all[dat_all[["Status"]] == "IP Address", , drop = FALSE]
  n_real <- nrow(d)
  jscore_all <- rowSums(sapply(names(java_key), function(q) trimws(d[[q]]) == java_key[[q]]))
  prog <- suppressWarnings(as.numeric(d[["Progress"]]))
  if (policy == "inclusive") keep <- !is.na(prog) & prog >= 20
  else                       keep <- d[["Finished"]] == "True" & jscore_all == 3
  d <- d[keep, , drop = FALSE]; jscore <- jscore_all[keep]; n_analysed <- nrow(d)
  
  long_list <- list()
  for (k in seq_along(choice_idx)) {
    ci <- choice_idx[k]; item <- item_of[k]; vals <- d[[ci]]
    kp <- trimws(vals) != ""; if (!any(kp)) next
    qnum <- as.integer(sub("^Q([0-9]+).*", "\\1", item))
    expl   <- if (ci + 1 <= ncol(d)) d[[ci + 1]] else rep("", nrow(d))
    reason <- if (ci + 2 <= ncol(d)) d[[ci + 2]] else rep("", nrow(d))
    long_list[[length(long_list) + 1]] <- data.frame(
      response_id = d[["ResponseId"]][kp], item = item, qnum = qnum,
      chosen_side = chosen_side(vals)[kp], signed = parse_signed(vals)[kp],
      magnitude = abs(parse_signed(vals)[kp]), java_score = jscore[kp],
      experience = d[["Demographic Q2"]][kp], degree = d[["Demographic Q1"]][kp],
      explanation = trimws(expl[kp]), reasoning = trimws(reason[kp]),
      stringsAsFactors = FALSE)
  }
  long <- do.call(rbind, long_list)
  write.csv(long, file.path(ddir, "survey_long.csv"), row.names = FALSE)
  
  boot_ci <- function(x, B = 5000, seed = 1) {
    x <- x[!is.na(x)]; if (length(x) < 2) return(c(NA, NA))
    set.seed(seed); m <- replicate(B, mean(sample(x, length(x), replace = TRUE)))
    unname(quantile(m, c(.025, .975)))
  }
  ord_key <- function(s) {
    m <- regmatches(s, regexec("^Q([0-9]+)([A-Z]?)", s))[[1]]
    qn <- suppressWarnings(as.integer(m[2])); if (is.na(qn)) qn <- 99
    sprintf("%02d%s", qn, ifelse(length(m) >= 3 && m[3] != "", m[3], "Z"))
  }
  items <- unique(long$item); items <- items[order(sapply(items, ord_key))]
  
  per_item <- do.call(rbind, lapply(items, function(it) {
    g <- long[long$item == it, ]; n <- nrow(g)
    nA <- sum(g$chosen_side == "A"); nB <- sum(g$chosen_side == "B")
    nN <- sum(g$chosen_side == "none"); dec <- nA + nB; ci <- boot_ci(g$signed)
    p <- if (dec > 0) binom.test(nA, dec, 0.5)$p.value else NA_real_
    data.frame(item = it, n = n, n_A = nA, n_B = nB, n_none = nN,
               pct_A = round(100*nA/n,1), pct_B = round(100*nB/n,1), pct_none = round(100*nN/n,1),
               mean_signed = round(mean(g$signed),3), ci_lo = round(ci[1],3), ci_hi = round(ci[2],3),
               pref_strength = round(mean(g$magnitude[g$chosen_side != "none"]),3),
               agreement = if (dec>0) round(max(nA,nB)/dec,3) else NA,
               sign_test_p = round(p,4), stringsAsFactors = FALSE)
  }))
  write.csv(per_item, file.path(ddir, "per_item_summary.csv"), row.names = FALSE)
  
  resp <- data.frame(response_id = d[["ResponseId"]], degree = d[["Demographic Q1"]],
                     experience = d[["Demographic Q2"]], java_score = jscore, finished = d[["Finished"]],
                     progress = prog[keep],
                     duration_s = suppressWarnings(as.integer(d[["Duration (in seconds)"]])),
                     stringsAsFactors = FALSE)
  write.csv(resp, file.path(ddir, "respondents.csv"), row.names = FALSE)
  
  hi <- long[long$java_score >= 2, ]; lo <- long[long$java_score < 2, ]
  mh <- tapply(hi$signed, hi$item, mean); ml <- tapply(lo$signed, lo$item, mean)
  common <- intersect(names(mh), names(ml))
  ev <- data.frame(item = common, hi_java_mean = round(as.numeric(mh[common]),3),
                   lo_java_mean = round(as.numeric(ml[common]),3), stringsAsFactors = FALSE)
  write.csv(ev, file.path(ddir, "expert_vs_novice.csv"), row.names = FALSE)
  rho_en <- if (nrow(ev) >= 3) suppressWarnings(cor(ev$hi_java_mean, ev$lo_java_mean, method = "spearman")) else NA
  
  # ==========================================================================
  # HUMAN DIFFICULTY ORDERING per question, derived from the pairwise votes.
  #
  # Humans don't give a number, they give pairwise votes, so we still need a
  # rule to turn votes into a per-variant difficulty rank. We use the net
  # "judged harder" score (sum of signed preferences, oriented so higher =
  # harder). This score is ONLY the vehicle for producing the human RANK; it
  # is not itself compared against the metrics. Downstream, only the human
  # RANK (and the raw pairwise votes) are used.
  # ==========================================================================
  pm <- pair_map[pair_map$item %in% long$item, ]
  msign <- setNames(per_item$mean_signed, per_item$item)
  
  human_rank <- list()          # question -> named vector (variant -> rank, 1=hardest)
  human_pairs <- list()         # question -> data.frame(a,b,harder) decided pairs
  order_rows <- list()
  for (q in sort(unique(pm$question))) {
    pmq <- pm[pm$question == q, ]
    variants <- unique(c(pmq$variant_A, pmq$variant_B))
    if (length(variants) < 2) next
    diff_score <- setNames(numeric(length(variants)), variants)
    prs <- list()
    for (i in seq_len(nrow(pmq))) {
      it <- pmq$item[i]; if (!(it %in% names(msign))) next
      A <- pmq$variant_A[i]; B <- pmq$variant_B[i]; s <- msign[it]
      if (is.na(s)) next
      diff_score[A] <- diff_score[A] - s     # s>0 => A easier => A less hard
      diff_score[B] <- diff_score[B] + s
      harder <- if (s > 0) B else if (s < 0) A else NA  # which variant humans found harder
      prs[[length(prs)+1]] <- data.frame(a = A, b = B, harder = harder,
                                         margin = abs(s), stringsAsFactors = FALSE)
    }
    rk <- rank(-diff_score, ties.method = "min")   # 1 = hardest
    human_rank[[q]] <- rk
    human_pairs[[q]] <- if (length(prs)) do.call(rbind, prs) else
      data.frame(a=character(), b=character(), harder=character(), margin=numeric())
    dv <- round(diff_score, 2)[order(-diff_score)]; lab <- names(dv); os <- lab[1]
    if (length(lab) > 1) for (t in 2:length(lab))
      os <- paste0(os, if (dv[t] == dv[t-1]) " = " else " > ", lab[t])
    order_rows[[length(order_rows)+1]] <- data.frame(
      question = q, human_ordering_hardest_first = os, stringsAsFactors = FALSE)
  }
  human_orderings <- do.call(rbind, order_rows)
  write.csv(human_orderings, file.path(ddir, "human_orderings.csv"), row.names = FALSE)
  write.csv(pair_map, file.path(ddir, "pair_map_used.csv"), row.names = FALSE)
  
  # ==========================================================================
  # METRIC vs HUMAN comparison. For every question, rank variants by each
  # metric (higher metric value = predicted harder = rank 1) and compare that
  # ranking to the human ranking with several agreement statistics:
  #
  #   spearman        rank correlation of metric rank vs human rank
  #   kendall         Kendall tau (robust with few variants / ties)
  #   pair_concordance fraction of human-DECIDED pairs the metric orders the
  #                   same way (the most direct measure; metric ties = half)
  #   top_match       1 if the metric's hardest variant == humans' hardest
  #
  # Everything goes into ONE wide table plus tidy agreement tables, so a single
  # spreadsheet holds human + every metric ordering side by side per question.
  # ==========================================================================
  metric_agreement <- NULL
  if (file.exists(VARIANT_METRICS_FILE)) {
    vm <- read.csv(VARIANT_METRICS_FILE, stringsAsFactors = FALSE, check.names = FALSE)
    metric_names <- setdiff(names(vm), c("question", "variant"))
    
    wide_rows <- list(); agree_rows <- list(); mo_rows <- list()
    for (q in names(human_rank)) {
      hr <- human_rank[[q]]; variants <- names(hr)
      vmq <- vm[vm$question == q, , drop = FALSE]; if (!nrow(vmq)) next
      rownames(vmq) <- vmq$variant
      hp <- human_pairs[[q]]
      
      for (v in variants) {
        row <- data.frame(question = q, variant = v, human_rank = hr[[v]],
                          stringsAsFactors = FALSE)
        for (m in metric_names)
          row[[paste0(m, "_val")]] <- if (v %in% rownames(vmq)) vmq[v, m] else NA
        wide_rows[[length(wide_rows)+1]] <- row
      }
      
      for (m in metric_names) {
        vals <- setNames(vmq[variants, m], variants)
        if (all(is.na(vals))) next
        mrank <- rank(-vals, ties.method = "min")
        sp <- suppressWarnings(cor(hr[variants], mrank[variants], method = "spearman"))
        kt <- suppressWarnings(cor(hr[variants], mrank[variants], method = "kendall"))
        conc <- NA
        if (nrow(hp)) {
          agree <- 0; ntot <- 0
          for (i in seq_len(nrow(hp))) {
            hh <- hp$harder[i]; if (is.na(hh)) next
            a <- hp$a[i]; b <- hp$b[i]; va <- vals[a]; vb <- vals[b]
            if (is.na(va) || is.na(vb)) next
            ntot <- ntot + 1
            mh2 <- if (va > vb) a else if (vb > va) b else NA
            if (is.na(mh2)) agree <- agree + 0.5 else if (mh2 == hh) agree <- agree + 1
          }
          conc <- if (ntot > 0) agree / ntot else NA
        }
        top_match <- as.integer(names(which.min(hr)) == names(which.min(mrank)))
        agree_rows[[length(agree_rows)+1]] <- data.frame(
          question = q, metric = m, n_variants = length(variants),
          spearman = round(sp,3), kendall = round(kt,3),
          pair_concordance = round(conc,3), top_match = top_match,
          n_decided_pairs = if (nrow(hp)) sum(!is.na(hp$harder)) else 0,
          stringsAsFactors = FALSE)
        dvm <- round(vals,2)[order(-vals)]; lab <- names(dvm); osm <- lab[1]
        if (length(lab) > 1) for (t in 2:length(lab))
          osm <- paste0(osm, if (dvm[t]==dvm[t-1]) " = " else " > ", lab[t])
        mo_rows[[length(mo_rows)+1]] <- data.frame(
          question = q, metric = m, ordering_hardest_first = osm, stringsAsFactors = FALSE)
      }
    }
    orderings_wide   <- do.call(rbind, wide_rows)
    per_qm           <- do.call(rbind, agree_rows)
    metric_orderings <- do.call(rbind, mo_rows)
    
    mo_all <- rbind(
      data.frame(question = human_orderings$question, metric = "HUMAN",
                 ordering_hardest_first = human_orderings$human_ordering_hardest_first,
                 stringsAsFactors = FALSE),
      metric_orderings)
    mo_all <- mo_all[order(mo_all$question, mo_all$metric != "HUMAN", mo_all$metric), ]
    
    overall <- aggregate(cbind(spearman, kendall, pair_concordance, top_match) ~ metric,
                         per_qm, function(z) round(mean(z, na.rm = TRUE), 3))
    overall <- overall[order(-overall$pair_concordance, -overall$spearman), ]
    
    win_rows <- list()
    for (q in unique(per_qm$question)) {
      sub <- per_qm[per_qm$question == q, ]; best <- sub$pair_concordance
      if (all(is.na(best))) next
      mx <- max(best, na.rm = TRUE)
      winners <- sub$metric[which(!is.na(best) & best == mx)]
      win_rows[[length(win_rows)+1]] <- data.frame(question = q,
                                                   best_concordance = round(mx,3), winning_metric = paste(winners, collapse = " / "),
                                                   stringsAsFactors = FALSE)
    }
    per_question_winner <- do.call(rbind, win_rows)
    
    # ------------------------------------------------------------------------
    # PER-QUESTION ORDERING GRIDS
    # One grid per question: rows = methods (HUMAN first, then each metric),
    # columns = ordered positions from EASIEST (pos 1) to HARDEST (pos k).
    # Each cell holds the variant(s) placed at that position; ties share a cell
    # joined with "/". Written as one sheet per question in ordering_grids.xlsx.
    # ------------------------------------------------------------------------
    ordering_grids <- list()   # question -> data.frame
    for (q in names(human_rank)) {
      hr <- human_rank[[q]]; variants <- names(hr)   # rank 1 = hardest
      vmq <- vm[vm$question == q, , drop = FALSE]; rownames(vmq) <- vmq$variant
      kpos <- length(variants)
      # neutral position headers, easiest on the left. With ties there may be
      # fewer filled groups than kpos; extra columns stay blank.
      col_labels <- paste0("Pos", seq_len(kpos))
      col_labels[1] <- "Easiest"; col_labels[kpos] <- "Hardest"
      
      # helper: lay out variants by DISTINCT rank groups, easiest->hardest,
      # ties joined by "/", padded to kpos columns.
      layout_row <- function(rk) {
        grp <- sort(unique(rk[!is.na(rk)]), decreasing = TRUE)  # easiest first (highest rank #)
        cells <- sapply(grp, function(g) paste(names(rk)[!is.na(rk) & rk == g], collapse = "/"))
        length(cells) <- kpos                                   # pad with NA
        cells
      }
      
      methods_order <- c("HUMAN", metric_names)
      grid <- matrix("", nrow = length(methods_order), ncol = kpos,
                     dimnames = list(methods_order, col_labels))
      # HUMAN
      grid["HUMAN", ] <- ifelse(is.na(layout_row(hr)), "", layout_row(hr))
      # metrics
      for (m in metric_names) {
        vals <- setNames(vmq[variants, m], variants)
        if (all(is.na(vals))) { grid[m, ] <- c("(constant)", rep("", kpos-1)); next }
        mrank <- rank(-vals, ties.method = "min")
        grid[m, ] <- ifelse(is.na(layout_row(mrank)), "", layout_row(mrank))
      }
      df <- data.frame(Method = methods_order, grid, check.names = FALSE,
                       stringsAsFactors = FALSE)
      ordering_grids[[q]] <- df
    }
    # persist grids as a long CSV too (so they're available without openxlsx).
    # Questions differ in variant count, so pad every grid to the max width.
    maxk <- max(sapply(ordering_grids, function(d) ncol(d) - 1))
    pad_names <- c("Easiest", if (maxk > 2) paste0("Pos", 2:(maxk-1)) else character(0), "Hardest")
    grid_long <- do.call(rbind, lapply(names(ordering_grids), function(q) {
      d <- ordering_grids[[q]]
      body <- d[, -1, drop = FALSE]
      if (ncol(body) < maxk) {
        extra <- as.data.frame(matrix("", nrow(body), maxk - ncol(body)),
                               stringsAsFactors = FALSE)
        body <- cbind(body, extra)
      }
      names(body) <- pad_names
      cbind(question = q, Method = d$Method, body)
    }))
    write.csv(grid_long, file.path(ddir, "ordering_grids.csv"), row.names = FALSE)
    
    write.csv(orderings_wide,      file.path(ddir, "orderings_wide.csv"), row.names = FALSE)
    write.csv(mo_all,              file.path(ddir, "orderings_all.csv"), row.names = FALSE)
    write.csv(per_qm,              file.path(ddir, "metric_agreement_per_question.csv"), row.names = FALSE)
    write.csv(overall,             file.path(ddir, "metric_agreement_overall.csv"), row.names = FALSE)
    write.csv(per_question_winner, file.path(ddir, "per_question_winner.csv"), row.names = FALSE)
    metric_agreement <- overall
    
    png(file.path(fdir, "fig6_metric_agreement.png"), width = 2000, height = 1300, res = 300)
    par(family = "serif", mar = c(4, 8, 3, 1))
    o <- overall[order(overall$pair_concordance), ]
    bp <- barplot(o$pair_concordance, names.arg = o$metric, horiz = TRUE, las = 1,
                  col = "#2c7fb8", xlim = c(0, 1),
                  xlab = "Mean pairwise concordance with human votes",
                  main = sprintf("Which metric follows the humans? (%s)", policy))
    points(o$spearman/2 + .5, bp, pch = 18, col = "#d95f0e")
    abline(v = .5, col = "grey60", lty = 2)
    legend("bottomright", legend = c("pairwise concordance", "Spearman (rescaled)"),
           pch = c(15,18), col = c("#2c7fb8","#d95f0e"), bty = "n", cex = .7)
    dev.off()
    
    png(file.path(fdir, "fig7_per_question_agreement.png"), width = 2200, height = 1500, res = 300)
    par(family = "serif", mar = c(4, 5, 3, 8))
    mets <- unique(per_qm$metric); qs <- sort(unique(per_qm$question))
    M <- matrix(NA, length(qs), length(mets), dimnames = list(qs, mets))
    for (i in seq_len(nrow(per_qm)))
      M[per_qm$question[i], per_qm$metric[i]] <- per_qm$pair_concordance[i]
    image(seq_along(mets), seq_along(qs), t(M), col = hcl.colors(20, "Blues", rev = TRUE),
          axes = FALSE, xlab = "", ylab = "", zlim = c(0,1),
          main = sprintf("Pairwise concordance by question x metric (%s)", policy))
    axis(1, at = seq_along(mets), labels = mets, las = 2, cex.axis = .7)
    axis(2, at = seq_along(qs), labels = qs, las = 1, cex.axis = .7)
    box(); dev.off()
    
    # ---- fig8: per-question ordering grid (HUMAN + every metric) -------------
    # One panel per question. Rows = methods (HUMAN on top, then metrics);
    # x-axis = rank slot, hardest on the left. Each variant label sits at its
    # rank under each method, so a metric row that reads left-to-right the same
    # as the HUMAN row is a match. Tied variants share a slot.
    rank_from_vals <- function(vals) rank(-vals, ties.method = "min")
    qs_all <- names(human_rank)
    nq <- length(qs_all)
    ncols <- 2; nrows <- ceiling(nq / ncols)
    png(file.path(fdir, "fig8_orderings_grid.png"),
        width = 2400, height = 360 * nrows + 200, res = 300)
    par(family = "serif", mfrow = c(nrows, ncols), mar = c(2.2, 7.5, 2.2, 1),
        oma = c(2, 0, 2, 0))
    methods_order <- c("HUMAN", metric_names)
    for (q in qs_all) {
      hr <- human_rank[[q]]; variants <- names(hr)
      vmq <- vm[vm$question == q, , drop = FALSE]; rownames(vmq) <- vmq$variant
      # build rank vector per method
      ranks_by_method <- list(HUMAN = hr)
      for (m in metric_names) {
        vals <- setNames(vmq[variants, m], variants)
        ranks_by_method[[m]] <- if (all(is.na(vals)))
          setNames(rep(NA, length(variants)), variants) else rank_from_vals(vals)
      }
      maxslot <- max(unlist(lapply(ranks_by_method, function(r) r[!is.na(r)])), 1)
      ny <- length(methods_order)
      plot(NA, xlim = c(0.5, maxslot + .5), ylim = c(0.5, ny + .5),
           xaxt = "n", yaxt = "n", xlab = "", ylab = "",
           main = q, cex.main = 1)
      axis(2, at = ny:1, labels = methods_order, las = 1, cex.axis = .68, tick = FALSE)
      # shade the HUMAN row
      rect(0.5, ny - .5, maxslot + .5, ny + .5, col = "#eef4fb", border = NA)
      axis(1, at = 1:maxslot, labels = c("hardest", rep("", max(maxslot-2,0)), "easiest")[1:maxslot],
           cex.axis = .6, tick = FALSE)
      for (mi in seq_along(methods_order)) {
        yy <- ny - mi + 1
        r <- ranks_by_method[[methods_order[mi]]]
        if (all(is.na(r))) { text(mean(c(1,maxslot)), yy, "(constant)", col = "grey60", cex = .58); next }
        is_human <- methods_order[mi] == "HUMAN"
        col <- if (is_human) "#1f4e79" else "#333333"
        # group variants by their rank slot; tied variants share a slot and are
        # printed together as "V1/V2" so nothing overprints.
        slots <- sort(unique(r[!is.na(r)]))
        for (s in slots) {
          vs <- names(r)[!is.na(r) & r == s]
          lab <- paste(vs, collapse = "/")
          text(s, yy, lab, cex = .6, col = col, font = if (is_human) 2 else 1)
        }
      }
    }
    mtext(sprintf("Variant ordering per question: HUMAN vs each metric (hardest left -> easiest right)  [%s]", policy),
          outer = TRUE, cex = .72, line = 0.3)
    dev.off()
  }
  
  # ---- figures 1-5 ----------------------------------------------------------
  par_serif <- function() par(family = "serif")
  png(file.path(fdir, "fig1_net_preference.png"), width = 2000, height = 2600, res = 300)
  par_serif(); par(mar = c(4,5,3,1))
  pio <- per_item[nrow(per_item):1, ]; y <- seq_len(nrow(pio))
  cols <- ifelse(pio$mean_signed >= 0, "#2c7fb8", "#d95f0e")
  plot(NA, xlim = range(c(pio$ci_lo, pio$ci_hi), na.rm = TRUE), ylim = c(.5, max(y)+.5),
       yaxt = "n", xlab = "Net preference  (<- toward B    toward A ->)", ylab = "",
       main = sprintf("Per-item net preference, 95%% CI (%s)", policy))
  abline(v = 0, lwd = 1); segments(pio$ci_lo, y, pio$ci_hi, y, col = "#555555")
  rect(pmin(0, pio$mean_signed), y-.35, pmax(0, pio$mean_signed), y+.35, col = cols, border = NA)
  axis(2, at = y, labels = pio$item, las = 1, cex.axis = .6); dev.off()
  
  png(file.path(fdir, "fig2_distribution.png"), width = 2200, height = 2600, res = 300)
  par_serif(); par(mar = c(4,5,4,1))
  lv <- c("A much","A slight","None","B slight","B much")
  pal <- c("#08519c","#6baed6","#bdbdbd","#fdae6b","#e6550d")
  mat <- sapply(per_item$item, function(it) { g <- long[long$item == it, ]; n <- nrow(g)
  c(sum(g$signed==2), sum(g$signed==1), sum(g$signed==0), sum(g$signed==-1), sum(g$signed==-2))/n*100 })
  mat <- mat[, ncol(mat):1]
  barplot(mat, horiz = TRUE, col = pal, border = NA, xlim = c(0,100),
          names.arg = rev(per_item$item), las = 1, cex.names = .6,
          xlab = "Percent of responses", main = sprintf("Response distribution per item (%s)", policy))
  legend("top", legend = lv, fill = pal, horiz = TRUE, bty = "n", cex = .7, inset = -.045, xpd = TRUE); dev.off()
  
  png(file.path(fdir, "fig3_demographics.png"), width = 3200, height = 1100, res = 300)
  par_serif(); par(mfrow = c(1,3), mar = c(7,4,3,1))
  barplot(sort(table(resp$degree)), col = "#3182bd", las = 2, cex.names = .55,
          main = "Degree programme", ylab = "n")
  exp_ord <- c("None","Written tiny programs (Up to 100 lines)",
               "Written small programs (100-500 lines)","Written medium programs (500-2000 lines)",
               "Written large programs (2000+ lines)")
  ec <- table(factor(resp$experience, levels = exp_ord)); names(ec) <- c("None","tiny","small","medium","large")
  barplot(ec, col = "#31a354", las = 2, cex.names = .7, main = "Java experience", ylab = "n")
  barplot(table(factor(resp$java_score, levels = 0:3)), col = "#756bb1",
          main = "Java screening (/3)", xlab = "correct", ylab = "n"); dev.off()
  
  if (nrow(ev) >= 3) {
    png(file.path(fdir, "fig4_expert_vs_novice.png"), width = 1600, height = 1600, res = 300)
    par_serif(); par(mar = c(4,4,3,1))
    lim <- range(c(ev$hi_java_mean, ev$lo_java_mean)) + c(-.2,.2)
    plot(ev$lo_java_mean, ev$hi_java_mean, pch = 19, col = "#2c7fb8", xlim = lim, ylim = lim,
         xlab = "Mean preference - lower Java score (<2)",
         ylab = "Mean preference - higher Java score (>=2)",
         main = sprintf("Expert vs novice (rho = %.2f, %s)", rho_en, policy))
    abline(0,1,lty = 2, col = "#555555"); abline(h = 0, v = 0, col = "grey80"); dev.off()
  }
  
  png(file.path(fdir, "fig5_engagement.png"), width = 2400, height = 1000, res = 300)
  par_serif(); par(mfrow = c(1,2), mar = c(4,4,3,1))
  hist(as.integer(table(long$response_id)), breaks = 15, col = "#3182bd",
       main = "Items per respondent", xlab = "items")
  dmin <- resp$duration_s[!is.na(resp$duration_s) & resp$duration_s > 0 & resp$duration_s < 3600]/60
  hist(dmin, breaks = 20, col = "#e6550d", main = "Completion time", xlab = "minutes"); dev.off()
  
  if (requireNamespace("openxlsx", quietly = TRUE)) {
    library(openxlsx)
    wb <- createWorkbook()
    hs <- createStyle(fgFill = "#1F4E79", fontColour = "white", textDecoration = "bold",
                      halign = "center", border = "TopBottomLeftRight")
    add <- function(nm, df) { addWorksheet(wb, nm); writeData(wb, nm, df, headerStyle = hs)
      setColWidths(wb, nm, cols = seq_along(df), widths = "auto"); freezePane(wb, nm, firstRow = TRUE) }
    add("Respondents", resp); add("PerItem", per_item); add("LongData", long)
    add("ExpertVsNovice", ev); add("HumanOrderings", human_orderings)
    if (!is.null(metric_agreement)) {
      # Orderings: HUMAN + every metric, side by side per question (the sheet you asked for)
      add("Orderings_All", read.csv(file.path(ddir, "orderings_all.csv"), check.names = FALSE))
      add("Orderings_Wide", read.csv(file.path(ddir, "orderings_wide.csv"), check.names = FALSE))
      add("Agreement_PerQuestion", read.csv(file.path(ddir, "metric_agreement_per_question.csv")))
      add("Agreement_Overall", metric_agreement)
      add("PerQuestion_Winner", read.csv(file.path(ddir, "per_question_winner.csv")))
    }
    add("PairMapUsed", pair_map)
    saveWorkbook(wb, file.path(odir, "survey_analysis.xlsx"), overwrite = TRUE)
  }
  
  # ---- per-question ordering grid workbook: one sheet per question ----------
  # Built with a self-contained base-R writer (no packages needed), so this
  # ALWAYS runs when metrics were supplied, regardless of openxlsx.
  if (exists("ordering_grids") && length(ordering_grids)) {
    qorder <- names(ordering_grids)[order(as.integer(sub("Q", "", names(ordering_grids))))]
    write_xlsx_grids(ordering_grids[qorder],
                     file.path(odir, "ordering_grids.xlsx"),
                     highlight_first_body_row = TRUE)   # HUMAN is the first body row
  }
  
  summ <- c(
    sprintf("policy: %s", policy),
    sprintf("real_submissions (non-preview): %d", n_real),
    sprintf("analysed_respondents: %d", n_analysed),
    sprintf("finished: %d", sum(d[["Finished"]] == "True")),
    sprintf("total_observations: %d", nrow(long)),
    sprintf("items: %d", length(items)),
    sprintf("median_items_per_respondent: %d", as.integer(median(table(long$response_id)))),
    sprintf("java_screen_perfect: %d", sum(resp$java_score == 3)),
    sprintf("expert_novice_spearman: %s", ifelse(is.na(rho_en), "NA", sprintf("%.3f", rho_en))))
  if (!is.null(metric_agreement)) {
    best <- metric_agreement[1, ]
    summ <- c(summ, sprintf("best_metric: %s (mean rho = %.3f)", best$metric, best$mean_spearman))
  }
  writeLines(summ, file.path(odir, "run_summary.txt"))
  cat(paste(summ, collapse = "\n"), "\n\n")
  invisible(NULL)
}

# ============================================================================
# variant_metrics template (first run only)
# ============================================================================
if (!file.exists(VARIANT_METRICS_FILE) &&
    !file.exists(file.path(OUT_DIR, "variant_metrics_template.csv"))) {
  rows <- list()
  for (q in unique(pair_map$question)) {
    vs <- unique(c(pair_map$variant_A[pair_map$question == q],
                   pair_map$variant_B[pair_map$question == q]))
    for (v in vs) rows[[length(rows)+1]] <- data.frame(question = q, variant = v,
                                                       CC = NA, Cognitive = NA, LOC = NA, MaxNest = NA, FanOut = NA,
                                                       HalVol = NA, HalEff = NA, AvgIdW = NA, stringsAsFactors = FALSE)
  }
  write.csv(do.call(rbind, rows), file.path(OUT_DIR, "variant_metrics_template.csv"), row.names = FALSE)
  cat("Wrote variant_metrics_template.csv - fill it and save as variant_metrics.csv",
      "to enable the metric-vs-human agreement analysis.\n\n")
}

# ============================================================================
# RUN BOTH POLICIES
# ============================================================================
run_policy("inclusive")
run_policy("strict")
cat("Done. Outputs under", OUT_DIR, "/{inclusive,strict}/\n")