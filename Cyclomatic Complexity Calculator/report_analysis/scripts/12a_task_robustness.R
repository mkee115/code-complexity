# =============================================================================
# 12a_task_robustness.R  (RQ2: does the agreement ranking depend on particular tasks or pairs?)
#
# a. Leave-one-task-out: agreement of the four metrics with each of the 10 tasks dropped in turn
# b. Task-level cluster bootstrap for the six pairwise differences in agreement: resample the 10
#    tasks, then the pairs within each drawn task, then the responses within each drawn pair
#    (each participant answered a pair at most once, so that is a resample of the participants who
#    saw the pair). Also the participant-only bootstrap, for comparison.
# Outputs: appendix dot plot (no title), a table of the six differences, numbers in report_numbers.csv.
# =============================================================================

source("scripts/00_setup.R")
participants <- readRDS(file.path(PATHS$work, "participants.rds"))
scored <- readRDS(file.path(PATHS$work, "scored_rq2.rds"))
pids <- participants$pid
bh <- boot_helpers(pids)

KEY <- unname(METRIC_LABELS)                                   # CC, CogC, LOC, MaxNest
agr <- scored |> select(pid, item, group, metric_label, agree) |>
  pivot_wider(names_from = metric_label, values_from = agree) |> arrange(item, pid)
validate("task robustness: 750 responses, 10 tasks, 44 pairs", nrow(agr) == 750 && n_distinct(agr$group) == 10 && n_distinct(agr$item) == 44)
A_all <- as.matrix(agr[, KEY]) * 1
tasks <- sort(unique(agr$group))
full <- tibble::tibble(metric = KEY, agreement = colMeans(A_all))

# ---- a. Leave-one-task-out ------------------------------------------------------------------------
loto <- purrr::map_dfr(tasks, function(t) {
  keep <- agr$group != t
  tibble::tibble(dropped_task = t, metric = KEY, agreement = colMeans(A_all[keep, , drop = FALSE]), n = sum(keep))
})
wide_loto <- loto |> pivot_wider(names_from = metric, values_from = agreement) |>
  mutate(highest = KEY[max.col(as.matrix(across(all_of(KEY))), ties.method = "first")],
         order = apply(as.matrix(across(all_of(KEY))), 1, function(v) paste(KEY[order(-v)], collapse = " > ")),
         cogc_minus_cc = CogC - CC, cogc_minus_loc = CogC - LOC)
save_table(wide_loto, "rq2_leave_one_task_out")
rq2 <- readRDS(file.path(PATHS$work, "rq2_results.rds"))
main_agree <- rq2$agreement$agree_all[match(METRICS, rq2$agreement$metric)]
validate("leave-one-task-out: the full-data agreement matches the main analysis", isTRUE(all.equal(unname(full$agreement), unname(main_agree))))
MAIN_ORDER <- paste(full$metric[order(-full$agreement)], collapse = " > ")
for (m in KEY) {
  v <- wide_loto[[m]]
  record(paste0(m, ": agreement leaving one task out, lowest"), min(v), n = 10, section = "RQ2: task robustness",
         note = paste("task", wide_loto$dropped_task[which.min(v)], "dropped"))
  record(paste0(m, ": agreement leaving one task out, highest"), max(v), n = 10, section = "RQ2: task robustness",
         note = paste("task", wide_loto$dropped_task[which.max(v)], "dropped"))
}
record("leave-one-task-out: tasks whose removal keeps CogC the highest", sum(wide_loto$highest == "CogC"), denominator = 10, section = "RQ2: task robustness")
record("leave-one-task-out: tasks whose removal keeps the full ranking", sum(wide_loto$order == MAIN_ORDER), denominator = 10,
       section = "RQ2: task robustness", note = paste("full-data ranking:", MAIN_ORDER))
record("leave-one-task-out: CogC minus LOC, smallest across the 10 drops", min(wide_loto$cogc_minus_loc), n = 10, section = "RQ2: task robustness",
       note = paste("task", wide_loto$dropped_task[which.min(wide_loto$cogc_minus_loc)], "dropped"))
record("leave-one-task-out: CogC minus LOC, largest across the 10 drops", max(wide_loto$cogc_minus_loc), n = 10, section = "RQ2: task robustness")
record("leave-one-task-out: CogC minus CC, smallest across the 10 drops", min(wide_loto$cogc_minus_cc), n = 10, section = "RQ2: task robustness",
       note = paste("task", wide_loto$dropped_task[which.min(wide_loto$cogc_minus_cc)], "dropped"))
record("leave-one-task-out: CogC minus CC, largest across the 10 drops", max(wide_loto$cogc_minus_cc), n = 10, section = "RQ2: task robustness")

ord_metrics <- full$metric[order(-full$agreement)]                 # highest agreement first
dd <- loto |> mutate(metric = factor(metric, levels = rev(ord_metrics)), y = as.numeric(metric) + (dropped_task - 5.5) * 0.07)
fd <- full |> mutate(metric = factor(metric, levels = rev(ord_metrics)), y = as.numeric(metric))
p_loto <- ggplot(dd, aes(agreement, y, colour = metric)) +
  geom_point(size = 1.9) +
  geom_text(aes(label = dropped_task), nudge_x = 0.0045, size = 2.1, family = FONT_FAMILY, show.legend = FALSE) +
  geom_point(data = fd, shape = 18, size = 4.2, colour = "black") +
  scale_colour_manual(values = METRIC_COLOURS, guide = "none") +
  scale_y_continuous(breaks = seq_along(levels(dd$metric)), labels = levels(dd$metric), expand = expansion(add = 0.5)) +
  scale_x_continuous(labels = scales::label_percent(), expand = expansion(mult = c(0.02, 0.05))) +
  labs(x = "Agreement with participants (all 750 responses minus one task)", y = NULL) +
  theme_report() + theme(panel.grid.major.y = element_blank())
save_fig(p_loto, "diag_rq2_leave_one_task_out", height_cm = 7, rq = "RQ2",
         purpose = "Leave-one-task-out agreement for the four metrics; each dot is labelled with the task that was dropped, the diamond is the full-data value")

# ---- b. Three-stage cluster bootstrap --------------------------------------------------------------
A_item <- lapply(split(seq_len(nrow(agr)), agr$item), function(ix) A_all[ix, , drop = FALSE])
items_by_task <- lapply(tasks, function(t) unique(agr$item[agr$group == t]))
one_replicate <- function() {
  tot <- numeric(4); n <- 0
  for (t in sample.int(length(tasks), length(tasks), replace = TRUE)) {
    its <- items_by_task[[t]]
    for (i in its[sample.int(length(its), length(its), replace = TRUE)]) {
      Ai <- A_item[[i]]; ni <- nrow(Ai)
      tot <- tot + colSums(Ai[sample.int(ni, ni, replace = TRUE), , drop = FALSE]); n <- n + ni
    }
  }
  tot / n
}
set.seed(SEED)
boot_agree <- t(vapply(seq_len(N_BOOT), function(b) one_replicate(), numeric(4)))
colnames(boot_agree) <- KEY
DIFFS <- list(c("CogC", "CC"), c("CogC", "LOC"), c("CogC", "MaxNest"), c("LOC", "CC"), c("LOC", "MaxNest"), c("MaxNest", "CC"))
diff_tbl <- purrr::map_dfr(DIFFS, function(d) {
  b <- boot_agree[, d[1]] - boot_agree[, d[2]]
  ci_t <- quantile(b, c(0.025, 0.975))
  ci_p <- boot_ratio_ci(bh$W, bh$psum(agr[[d[1]]] - agr[[d[2]]], agr$pid), bh$psum(rep(1, nrow(agr)), agr$pid))
  est <- mean(agr[[d[1]]]) - mean(agr[[d[2]]])
  tibble::tibble(comparison = paste(d[1], "minus", d[2]), estimate = est, task_low = ci_t[[1]], task_high = ci_t[[2]],
                 participant_low = ci_p[["low"]], participant_high = ci_p[["high"]],
                 excludes_zero_task_level = ci_t[[1]] > 0 | ci_t[[2]] < 0, prop_resamples_positive = mean(b > 0))
})
save_table(diff_tbl, "rq2_task_bootstrap_differences")
validate("task bootstrap: the resampled agreement is centred on the observed agreement",
         max(abs(colMeans(boot_agree) - full$agreement)) < 0.01, sprintf("largest gap %.4f", max(abs(colMeans(boot_agree) - full$agreement))))
for (i in seq_len(nrow(diff_tbl))) {
  r <- diff_tbl[i, ]
  record(paste0("agreement difference, task-level bootstrap: ", r$comparison), r$estimate, r$task_low, r$task_high, n = 750,
         test = "three-stage cluster bootstrap (tasks, pairs within tasks, participants within pairs), 10,000 resamples",
         section = "RQ2: task robustness",
         note = sprintf("participant-only 95%% CI %+.3f to %+.3f", r$participant_low, r$participant_high))
}
cogc_top <- mean(apply(boot_agree, 1, function(v) KEY[which.max(v)] == "CogC"))
same_order <- mean(apply(boot_agree, 1, function(v) paste(KEY[order(-v)], collapse = " > ") == MAIN_ORDER))
record("task-level bootstrap: share of resamples in which CogC has the highest agreement", cogc_top, n = N_BOOT, section = "RQ2: task robustness")
record("task-level bootstrap: share of resamples with the full ranking", same_order, n = N_BOOT, section = "RQ2: task robustness",
       note = paste("ranking:", MAIN_ORDER))

fmt_pp <- function(x) sprintf("%+.1f", 100 * x)
table_png(diff_tbl |> transmute(Difference = comparison, `Estimate (pp)` = fmt_pp(estimate),
                                `95% CI, tasks / pairs / participants` = sprintf("%s to %s", fmt_pp(task_low), fmt_pp(task_high)),
                                `95% CI, participants only` = sprintf("%s to %s", fmt_pp(participant_low), fmt_pp(participant_high)),
                                `Excludes 0 (task level)` = ifelse(excludes_zero_task_level, "yes", "no")),
          "rq2_task_bootstrap_differences", title = "Pairwise differences in agreement, with task-level uncertainty",
          subtitle = "Percentage points; 10,000 resamples", wrap_note = "Task level: resample the 10 tasks, then the pairs within each task, then the participants who saw each pair.")

saveRDS(list(loto = wide_loto, diffs = diff_tbl, cogc_top = cogc_top, same_order = same_order), file.path(PATHS$work, "task_robustness.rds"))
save_figure_registry("12a_task_robustness")
save_numbers("12a_task_robustness")
save_validation("12a_task_robustness")
cat("Task robustness done\n")
