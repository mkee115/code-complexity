# =============================================================================
# 01_load_survey.R
# Reads the Qualtrics export, removes identifying columns, applies the
# inclusion rule (completed responses only), and builds one row per response
# joined to the pair map and the snippet measurements. Every data check is
# recorded in the validation log; a failed check stops the pipeline.
#
# Outputs (output/work/): participants.rds, responses.rds, scored.rds
#   responses: one row per participant x comparison
#   scored:    responses x 4 key metrics, with the metric's prediction and
#              whether it agrees with the participant
# =============================================================================

source("scripts/00_setup.R")

RATING_LEVELS <- c("Method A is much less complex", "Method A is slightly less complex",
                   "No difference", "Method B is slightly less complex",
                   "Method B is much less complex")
JAVA_CORRECT <- c(`Java Q1` = "C", `Java Q2` = "2", `Java Q3` = "24")

# ---- Read and de-identify -----------------------------------------------------
# Qualtrics writes three header rows: names, question text, ImportId JSON
raw <- read_csv(PATHS$survey_raw, col_types = cols(.default = col_character()),
                show_col_types = FALSE)[-(1:2), ]
identifying <- c("IPAddress", "LocationLatitude", "LocationLongitude",
                 "RecipientLastName", "RecipientFirstName", "RecipientEmail", "ExternalReference")
raw <- raw |> select(-any_of(identifying))
validate("identifying survey columns removed on load", !any(identifying %in% names(raw)))

n_rows_total <- nrow(raw)
n_preview <- sum(raw$Status == "Survey Preview")

# ---- Inclusion rule: completed responses only -------------------------------
kept <- raw |>
  filter(Status != "Survey Preview", Progress == "100", Finished %in% c("True", "1")) |>
  mutate(pid = sprintf("P%02d", row_number()))

participants <- kept |>
  transmute(
    pid,
    degree = `Demographic Q1`,
    experience = factor(`Demographic Q2`, levels = c(
      "None", "Written tiny programs (Up to 100 lines)", "Written small programs (100-500 lines)",
      "Written medium programs (500-2000 lines)", "Written large programs (2000+ lines)")),
    java_q1_correct = `Java Q1` == JAVA_CORRECT[["Java Q1"]],   # chained ternary
    java_q2_correct = `Java Q2` == JAVA_CORRECT[["Java Q2"]],   # modulo
    java_q3_correct = `Java Q3` == JAVA_CORRECT[["Java Q3"]],   # recursion
    java_correct = java_q1_correct + java_q2_correct + java_q3_correct,
    duration_min = as.numeric(`Duration (in seconds)`) / 60
  )

# ---- One row per response ----------------------------------------------------
pairs <- read_csv(PATHS$pairs, show_col_types = FALSE)
snip <- read_csv(PATHS$snippets, show_col_types = FALSE)

validate("every pair's rating column exists in the export", all(pairs$rating_column %in% names(kept)),
         paste(setdiff(pairs$rating_column, names(kept)), collapse = ", "))

responses <- kept |>
  select(pid, all_of(pairs$rating_column)) |>
  pivot_longer(-pid, names_to = "rating_column", values_to = "rating_text") |>
  filter(!is.na(rating_text)) |>
  inner_join(pairs, by = "rating_column") |>
  mutate(
    rating = match(rating_text, RATING_LEVELS),
    human = sign(rating - 3),                  # -1 = A judged less complex, +1 = B judged less complex
    strength = factor(c("No difference", "Slightly", "Much")[abs(rating - 3) + 1],
                      levels = c("No difference", "Slightly", "Much")),
    vv_pair = method_a != "ORIG"               # neither side is the original
  ) |>
  select(pid, item, group, task, method_a, method_b, method_a_id, method_b_id,
         rating, human, strength, vv_pair)
validate("every rating text matches the 5-point scale", !any(is.na(responses$rating)))

# ---- Join measurements: one row per response x metric -----------------------
long_metrics <- snip |>
  select(id, all_of(METRICS)) |>
  pivot_longer(-id, names_to = "metric", values_to = "value")

scored <- responses |>
  tidyr::crossing(metric = METRICS) |>
  left_join(long_metrics, by = c("method_a_id" = "id", "metric")) |>
  rename(value_a = value) |>
  left_join(long_metrics, by = c("method_b_id" = "id", "metric")) |>
  rename(value_b = value) |>
  mutate(
    predicted = sign(value_a - value_b),   # +1: A has the higher measurement, so B is predicted less complex
    agree = predicted == human,            # a metric tie agrees only with "No difference"
    gap = abs(value_a - value_b),
    metric_label = metric_factor(metric)
  )

# ---- Validation ------------------------------------------------------------------
per_person <- count(responses, pid)
per_pair <- count(responses, item)
validate("participants = 75 (completed, non-preview)", nrow(participants) == 75, nrow(participants))
validate("comparisons = 750", nrow(responses) == 750, nrow(responses))
validate("exactly 10 responses per participant", all(per_person$n == 10),
         paste(range(per_person$n), collapse = "-"))
validate("44 distinct pairs have responses", n_distinct(responses$item) == 44, n_distinct(responses$item))
validate("pair map covers the 44 pairs once", nrow(pairs) == 44 && !anyDuplicated(pairs$item))
validate("34 snippets have measurements", nrow(snip) == 34 && !anyDuplicated(snip$id), nrow(snip))
validate("every pair's two snippets have measurements",
         all(c(pairs$method_a_id, pairs$method_b_id) %in% snip$id))
validate("no missing metric values after the join", !anyNA(scored$value_a) && !anyNA(scored$value_b))
validate("responses per pair: min / max", all(per_pair$n >= 1), paste(range(per_pair$n), collapse = " / "))
validate("each participant saw one pair per task",
         all(count(responses, pid, group)$n == 1))
validate("Q4A seen by every participant", sum(responses$item == "Q4A") == 75)
validate("10-V3 absent from the pair map and snippets",
         !any(grepl("10-V3", c(pairs$method_a_id, pairs$method_b_id, snip$id))))
validate("Q10C is V1 vs V2", with(pairs[pairs$item == "Q10C", ], method_a == "V1" && method_b == "V2"))

# Hand-checks of the agreement coding on constructed cases
code_agree <- function(value_a, value_b, rating) sign(value_a - value_b) == sign(rating - 3)
validate("coding: A lower, participant says A less complex -> agree", code_agree(2, 5, 1))
validate("coding: A lower, participant says B less complex -> disagree", !code_agree(2, 5, 4))
validate("coding: metric tie agrees with No difference", code_agree(3, 3, 3))
validate("coding: metric tie does not agree with a stated preference", !code_agree(3, 3, 5))
validate("coding: metric separates, participant says No difference -> disagree", !code_agree(2, 5, 3))
real <- scored |> filter(item == "Q3A", metric == "cc", rating == 4) |> slice(1)   # 03-ORIG (CC 3) vs 03-V1 (CC 2)
validate("coding on real data: Q3A CC 3 vs 2, 'B slightly less complex' -> agree",
         nrow(real) == 1 && real$agree && real$predicted == 1)

check_tbl <- tibble::tribble(
  ~check, ~result,
  "rows in export", n_rows_total,
  "survey previews removed", n_preview,
  "real submissions", n_rows_total - n_preview,
  "participants (completed)", nrow(participants),
  "comparisons", nrow(responses),
  "responses per pair (min)", min(per_pair$n),
  "responses per pair (max)", max(per_pair$n))
save_table(check_tbl, "survey_counts")

saveRDS(participants, file.path(PATHS$work, "participants.rds"))
saveRDS(responses, file.path(PATHS$work, "responses.rds"))
saveRDS(scored, file.path(PATHS$work, "scored.rds"))

record("participants", nrow(participants), n = nrow(participants), section = "Method: survey",
       note = "completed responses only, previews removed")
record("comparisons", nrow(responses), n = nrow(responses), section = "Method: survey")
record("real submissions (non-preview)", n_rows_total - n_preview, section = "Method: survey")
record("distinct pairs", n_distinct(responses$item), section = "Method: survey")
record("median duration (min)", median(participants$duration_min), section = "Method: survey")
record("responses per pair (min)", min(per_pair$n), section = "Method: survey")
record("responses per pair (max)", max(per_pair$n), section = "Method: survey")
record("all three screening questions correct", sum(participants$java_correct == 3),
       n = nrow(participants), section = "Method: survey")
for (v in c("java_q1_correct", "java_q2_correct", "java_q3_correct"))
  record(paste0("screening question correct: ", v), sum(participants[[v]]), n = nrow(participants),
         section = "Method: survey")
save_numbers("01_load_survey")
save_validation("01_load_survey")
cat("Survey loaded:", nrow(participants), "participants,", nrow(responses), "comparisons\n")
