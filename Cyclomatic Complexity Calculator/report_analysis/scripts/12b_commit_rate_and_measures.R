# =============================================================================
# 12b_commit_rate_and_measures.R  (RQ2: where does the agreement gap come from?)
#
# a. Responses where only one of two metrics agrees (CogC / LOC / MaxNest vs CC), split by whether CC
#    ties on the pair and whether the participant chose a side
# b. Commit rate (share of decisive responses where the metric separates the pair) and direction accuracy
#    (share of those it gets the right way round), for the four key metrics: scatter plot
# c. The same quantities, the tie rate over all 750 responses and the agreement, for the 13 measures
#    in fig06b: table and a scatter of agreement against tie rate
# Participant cluster-bootstrap 95% CIs throughout (same resamples as the other survey scripts).
# =============================================================================

source("scripts/00_setup.R")
suppressPackageStartupMessages(library(ggrepel))
participants <- readRDS(file.path(PATHS$work, "participants.rds"))
scored <- readRDS(file.path(PATHS$work, "scored_rq2.rds"))
responses <- readRDS(file.path(PATHS$work, "responses.rds"))
rq2 <- readRDS(file.path(PATHS$work, "rq2_results.rds"))
pids <- participants$pid
bh <- boot_helpers(pids)
W <- bh$W; psum <- bh$psum

# est = sum(num & den) / sum(den), with a participant cluster-bootstrap interval
ratio_ci <- function(pid, num, den) {
  ci <- boot_ratio_ci(W, psum(num & den, pid), psum(den, pid))
  tibble::tibble(est = sum(num & den) / sum(den), low = ci[["low"]], high = ci[["high"]], n_num = sum(num & den), n_den = sum(den))
}

# ---- a. Who agrees when only one of two metrics does --------------------------------------------------------
wide <- scored |> select(pid, item, human, metric, predicted) |> pivot_wider(names_from = metric, values_from = predicted)
validate("decomposition input has 750 responses", nrow(wide) == 750)
decomp_only <- purrr::map_dfr(c("cognitive", "loc", "max_nesting"), function(m) {
  pm <- wide[[m]]; pc <- wide$cc; h <- wide$human
  one <- function(flag, direction) wide[flag, ] |>
    transmute(item, comparison = paste(METRIC_LABELS[m], "vs CC"), direction,
              cc = ifelse(pc[flag] == 0, "CC ties", "CC separates"),
              participant = ifelse(h[flag] == 0, "participant: no difference", "participant chose a side"),
              other_metric = ifelse(pm[flag] == 0, paste(METRIC_LABELS[m], "ties"), paste(METRIC_LABELS[m], "separates")))
  bind_rows(one(pm == h & pc != h, paste("Only", METRIC_LABELS[m], "agrees")), one(pc == h & pm != h, "Only CC agrees"))
})
decomp_tbl <- decomp_only |> count(comparison, direction, cc, participant, other_metric, name = "responses") |>
  left_join(decomp_only |> distinct(comparison, direction, cc, participant, other_metric, item) |>
              count(comparison, direction, cc, participant, other_metric, name = "pairs"),
            by = c("comparison", "direction", "cc", "participant", "other_metric"))
save_table(decomp_tbl, "rq2_only_one_agrees_decomposition")
tot <- decomp_only |> count(comparison, direction, name = "total")
validate("only-one-agrees counts: CogC-only minus CC-only equals the agreement gap (428 - 320 = 108)",
         with(tot, total[comparison == "CogC vs CC" & direction == "Only CogC agrees"] - total[comparison == "CogC vs CC" & direction == "Only CC agrees"]) == 108)
for (i in seq_len(nrow(tot))) {
  r <- tot[i, ]
  d <- decomp_only |> filter(comparison == r$comparison, direction == r$direction)
  record(paste0(r$comparison, ": ", r$direction, ", responses"), r$total, section = "RQ2: only-one-agrees")
  record(paste0(r$comparison, ": ", r$direction, ", on pairs where CC ties"), sum(d$cc == "CC ties"), denominator = r$total,
         section = "RQ2: only-one-agrees", note = sprintf("%d distinct pairs", n_distinct(d$item[d$cc == "CC ties"])))
  record(paste0(r$comparison, ": ", r$direction, ", participant chose a side"), sum(d$participant == "participant chose a side"),
         denominator = r$total, section = "RQ2: only-one-agrees")
  record(paste0(r$comparison, ": ", r$direction, ", CC separates and participant said no difference"),
         sum(d$cc == "CC separates" & d$participant == "participant: no difference"), denominator = r$total, section = "RQ2: only-one-agrees")
  record(paste0(r$comparison, ": ", r$direction, ", CC separates and participant chose a side"),
         sum(d$cc == "CC separates" & d$participant == "participant chose a side"), denominator = r$total, section = "RQ2: only-one-agrees")
}

# ---- b/c. Tie rate, commit rate, direction accuracy and agreement for the 13 measures ---------------------
ALL_MEASURES <- c(cc = "CC", cognitive = "CogC", loc = "LOC", max_nesting = "MaxNest",
                  avg_nesting = "Average nesting", hal_vol = "Halstead volume", hal_eff = "Halstead effort",
                  fan_out = "Fan-out", params = "Parameter count", avg_id_words = "Words per identifier",
                  comment_count = "Comment count", has_javadoc = "Has Javadoc")
ALL_MEASURES["recursive"] <- "Recursive"     # not inside c(): `recursive` is an argument name of c()
snip <- read_csv(PATHS$snippets, show_col_types = FALSE)
meas_tbl <- purrr::map_dfr(names(ALL_MEASURES), function(mk) {
  a <- snip[[mk]][match(responses$method_a_id, snip$id)]; b <- snip[[mk]][match(responses$method_b_id, snip$id)]
  pred <- sign(as.numeric(a) - as.numeric(b)); agree <- pred == responses$human
  dec <- responses$human != 0; sep <- pred != 0; all_rows <- rep(TRUE, nrow(responses)); pid <- responses$pid
  t <- ratio_ci(pid, pred == 0, all_rows); a_ <- ratio_ci(pid, agree, all_rows)
  cm <- ratio_ci(pid, sep, dec); dr <- ratio_ci(pid, agree, dec & sep)
  tibble::tibble(metric = mk, measure = ALL_MEASURES[[mk]], key = mk %in% METRICS,
                 tie_rate = t$est, tie_low = t$low, tie_high = t$high,
                 agreement = a_$est, agree_low = a_$low, agree_high = a_$high, n_agree = a_$n_num,
                 commit_rate = cm$est, commit_low = cm$low, commit_high = cm$high, n_decisive = cm$n_den, n_separating = cm$n_num,
                 direction_accuracy = dr$est, dir_low = dr$low, dir_high = dr$high, n_correct = dr$n_num, n_direction = dr$n_den)
})
key_chk <- meas_tbl |> filter(key) |> left_join(rq2$agreement |> select(metric, n_agree_main = n_agree, low_main = all_low, high_main = all_high), by = "metric")
validate("13-measure table: the four key metrics reproduce the main agreement and its interval",
         all(key_chk$n_agree == key_chk$n_agree_main) && all(abs(key_chk$agree_low - key_chk$low_main) < 1e-12) &&
           all(abs(key_chk$agree_high - key_chk$high_main) < 1e-12))
validate("13-measure table: commit rate and tie rate are consistent for the key metrics (separating responses <= decisive)",
         all(meas_tbl$n_separating <= meas_tbl$n_decisive) && all(meas_tbl$n_decisive == 675))
save_table(meas_tbl, "rq2_measures_tie_commit_direction")
for (i in seq_len(nrow(meas_tbl))) {
  r <- meas_tbl[i, ]
  tst <- "participant cluster bootstrap 95% CI"
  record(paste0(r$measure, ": tie rate over all 750 responses"), r$tie_rate, r$tie_low, r$tie_high, n = round(r$tie_rate * 750), denominator = 750,
         test = tst, section = "RQ2: commit rate")
  record(paste0(r$measure, ": commit rate (share of decisive responses where it separates the pair)"), r$commit_rate, r$commit_low, r$commit_high,
         n = r$n_separating, denominator = r$n_decisive, test = tst, section = "RQ2: commit rate")
  record(paste0(r$measure, ": direction accuracy (right way round, when it separates and the participant chose a side)"), r$direction_accuracy,
         r$dir_low, r$dir_high, n = r$n_correct, denominator = r$n_direction, test = tst, section = "RQ2: commit rate")
}

# Scatter 1: commit rate against direction accuracy, four key metrics
key_pts <- meas_tbl |> filter(key) |> mutate(measure = factor(measure, levels = unname(METRIC_LABELS)))
p_commit <- ggplot(key_pts, aes(commit_rate, direction_accuracy, colour = measure)) +
  geom_hline(yintercept = 0.5, linetype = "dashed", colour = "#777777", linewidth = 0.35) +
  geom_errorbar(aes(ymin = dir_low, ymax = dir_high), width = 0, linewidth = 0.5) +
  geom_errorbar(aes(xmin = commit_low, xmax = commit_high), width = 0, linewidth = 0.5, orientation = "y") +
  geom_point(size = 3) +
  geom_text_repel(aes(label = measure), size = 3.2, family = FONT_FAMILY, show.legend = FALSE, box.padding = 0.7, seed = SEED, min.segment.length = 0) +
  scale_colour_manual(values = METRIC_COLOURS, guide = "none") +
  scale_x_continuous(labels = scales::label_percent(), limits = c(0, 1)) +
  scale_y_continuous(labels = scales::label_percent(), limits = c(0.4, 1)) +
  labs(x = "Commit rate: share of decisive responses it separates",
       y = "Direction accuracy (right way round)") +
  theme_report()
save_fig(p_commit, "diag_rq2_commit_vs_direction", height_cm = 8.5, rq = "RQ2",
         purpose = "Commit rate against direction accuracy for CC, CogC, LOC and MaxNest (95% participant-bootstrap intervals; dashed line = 50%)")

# Scatter 2: agreement against tie rate, 13 measures
sc2 <- meas_tbl |> mutate(group = ifelse(key, measure, "Other measurement"))
p_tie <- ggplot(sc2, aes(tie_rate, agreement, colour = group)) +
  geom_errorbar(aes(ymin = agree_low, ymax = agree_high), width = 0, linewidth = 0.4, alpha = 0.7) +
  geom_errorbar(aes(xmin = tie_low, xmax = tie_high), width = 0, linewidth = 0.4, alpha = 0.7, orientation = "y") +
  geom_point(aes(size = key)) +
  geom_text_repel(aes(label = measure, fontface = ifelse(key, "bold", "plain")), size = 2.9, family = FONT_FAMILY, show.legend = FALSE,
                  box.padding = 0.45, max.overlaps = Inf, seed = SEED, min.segment.length = 0.1) +
  scale_colour_manual(values = c(METRIC_COLOURS, `Other measurement` = "#8C8C8C"), guide = "none") +
  scale_size_manual(values = c(`TRUE` = 3.2, `FALSE` = 1.9), guide = "none") +
  scale_x_continuous(labels = scales::label_percent(), limits = c(0, 1)) +
  scale_y_continuous(labels = scales::label_percent(), limits = c(0, 0.75)) +
  labs(x = "Tie rate: share of the 750 responses where the measure gives the two methods the same value",
       y = "Agreement with participants (all 750 responses)") +
  theme_report()
save_fig(p_tie, "diag_rq2_measures_tie_rate_vs_agreement", height_cm = 9.5, rq = "RQ2",
         purpose = "Agreement against tie rate for the 13 measures in fig06b; the four key metrics are coloured")

fmt_ci <- function(e, l, h) ifelse(is.na(e), "–", sprintf("%.0f%% (%.0f–%.0f)", 100 * e, 100 * l, 100 * h))   # "–": the measure never separates a pair
table_png(meas_tbl |> transmute(Measure = measure,
                                `Tie rate` = fmt_ci(tie_rate, tie_low, tie_high),
                                `Commit rate` = fmt_ci(commit_rate, commit_low, commit_high),
                                `Direction accuracy` = fmt_ci(direction_accuracy, dir_low, dir_high),
                                Agreement = fmt_ci(agreement, agree_low, agree_high)),
          "rq2_measures_tie_commit_direction", title = "Tie rate, commit rate, direction accuracy and agreement",
          subtitle = "13 measures; participant-bootstrap 95% intervals",
          wrap_note = "Tie and agreement: all 750 responses. Commit and direction: the 675 responses where the participant chose a side.")

save_figure_registry("12b_commit_rate_and_measures")
save_numbers("12b_commit_rate_and_measures")
save_validation("12b_commit_rate_and_measures")
cat("Commit rate analyses done\n")
