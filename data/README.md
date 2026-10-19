# data/

Raw corpus data from the GitHub harvest. Nothing here has been processed. How every metric is calculated: [../tool/docs/metric_definitions.md](../tool/docs/metric_definitions.md). The analysis that uses it: [../analysis/report/README.md](../analysis/report/README.md).

**`corpus/cc_data.csv` (2 GB) is not in git** (it is listed in `.gitignore`); it is supplied in the compendium zip. Regenerate it with the `tool/` harvester (see the root README).

## data/corpus/ (GitHub mining, harvested 15 Oct 2026)

| File | Rows | Description |
|---|---|---|
| `cc_data.csv` | 6,961,274 | One row per Java method or constructor (2.0 GB). Load with `data.table::fread(select = ...)`. |
| `repos.csv` | 1,843 | One row per harvested repository. 1,832 of them contributed at least one method. |
| `skipped.csv` | 7,391 | Files and repos that could not be fully processed. `type` is `file_partial` (parsed with errors; its recoverable methods **are** in cc_data.csv), `file` (could not be parsed), `method`, `repo` (clone or API failure) or `chunk` (a search chunk that failed). |
| `run_log.txt` | | The harvest log. The last line is `EXIT 0` when the run finished. |

**cc_data.csv columns:**
- **Identification:** `project` (owner/repo, joins to `repos.full_name`), `class_name`, `method_name`.
- **Key metrics:** `cc`, `cognitive_complexity`, `loc` (non-blank non-comment), `max_nesting`.
- **Other size and structure:** `loc_physical`, `avg_nesting`, `param_count`, `return_count`, `fan_out`.
- **Halstead:** `halstead_volume`, `halstead_difficulty`, `halstead_effort`.
- **Naming:** `avg_id_words`, `abbreviated_ratio`, `single_letter_ids`, `longest_id`, `total_words`.
- **Comments:** `comment_count`, `comment_words`, `has_javadoc`.
- **Line length:** `max_line_length`, `avg_line_length`.
- **Excluded from the report:** `maintainability_index` and `mi_normalized`.
- **Flags and traceability:**
  - `kind` (`method` or `constructor`)
  - `has_body` (0 for abstract and interface methods)
  - `nested_in_method` (method of a local or anonymous class inside another method)
  - `is_generated`
  - `recursive`
  - `body_hash` (fingerprint, for finding duplicates)
  - `file_path`, `start_line`

**repos.csv columns:** `full_name`, `url`, `scraped_at`, `language`, `stars`, `forks`, `size_kb`, `commit_count`, `java_file_count`, `created_at`, `pushed_at`, `contributors`, `default_branch`, `head_sha` (the exact commit measured), `open_issues`, `license`, `archived`, `is_fork`, `topics`.

**Selection criteria** (the same as the June harvest): Java, at least 10 stars, at least 10 forks, pushed to on or after 2026-01-01, created on or before 2026-01-01, `pom.xml` at the repo root (Maven). Test folders (`src/test`, `src/it`) were excluded. Both methods and constructors are recorded (see `kind`). Metric definitions: `metric_definitions.md`.

The June 2026 harvest (1,894 repositories, 7,295,624 methods, measured with the earlier calculator) is no longer kept here; the original is in `analysis/data_tables/`.

For the report analysis, see [analysis/README.md](../analysis/README.md) (scripts, outputs, the main-corpus filter and the counts at each step).

The June 2026 harvest (1,894 repositories, 7,295,624 methods, measured with the earlier calculator) was superseded by the October harvest and is not kept in this repository.

## Survey (`data/survey/`)

The Qualtrics survey: its definition and the responses.

| File | Contents |
|---|---|
| `700_survey.qsf` | Qualtrics survey definition (questions, blocks, randomizers, image URLs) |
| `survey_responses_raw.csv` | Qualtrics export |
| `comparison_pairs.csv` | Which pair of snippets each comparison question showed |

The code snippets and images participants saw are in [`snippets/`](../snippets/).

| File | Description |
|---|---|
| `survey_responses_raw.csv` | Qualtrics export, unmodified (copy of `analysis/survey_stats/700_survey.csv`). |
| `comparison_pairs.csv` | Which two snippets each comparison question showed (44 rows). Checked against `700_survey.qsf` on 15 Oct: every item, image and A/B side matches. |
| `700_survey.qsf` | Qualtrics survey definition (JSON): questions, blocks, randomizers, image URLs. |
| `700_survey.docx` | Qualtrics Word export of the same survey, with images. |

**Survey design (confirmed from the .qsf):**
- **Order:** intro → demographics (degree; Java experience) → 3 Java screening questions → practice example → **10 task randomizers, Q1 to Q10 in fixed order**, each showing **1 pair chosen at random with even presentation** → a final optional comment (`Qend`). So every completer saw exactly 10 comparisons, one per task. Q4 had only one pair, so every participant saw Q4A.
- **No going back:** the back button was disabled.
- **Required answers:** the rating and "explain what the code does" were required. The "what made it easier/harder" reason was optional, and so was the degree question.
- **Fixed sides:** Method A was always the earlier version (ORIG, then V1, …); sides were not counterbalanced.
- **Wording:** the question asks "Which of these is easier to understand?", but the answer options say "… less complex".
- **Screening answers** (worked out from the code shown): Java Q1 = `C`, Q2 = `2`, Q3 = `24`.
- **Images were loaded live from GitHub `main`** at `survey_methods/combinedImages/<file-ID pair>.png?raw=true`, so participants saw the 17 Aug versions of those files. That folder no longer exists on `main`; the same images are in `snippets/images/pair_images/`. The live survey would show broken images if reopened.
- **Intro text shown to participants:** "You will be shown pairs of Java methods and asked to judge which is easier to understand, and by how much. There are no right or wrong answers. We are interested in your genuine first impression. You will not be able to go back to a previous question."

**Reading `survey_responses_raw.csv`:**
- Qualtrics writes **3 header rows**: column names, question text, then an ImportId JSON row. Respondents start on row 4. In R: `read_csv(...)[-(1:2), ]`.
- 109 respondent rows: 2 have `Status == "Survey Preview"` (drop these), leaving 107 real submissions. 75 of those have `Progress == 100` / `Finished == True`, which is the inclusion rule for the report (75 participants, 750 comparisons).
- **It contains IP addresses and latitude/longitude.** Drop `IPAddress`, `LocationLatitude` and `LocationLongitude` before sharing anything derived from it.
- Columns:
  - `Demographic Q1`: degree. `Demographic Q2`: Java experience.
  - `Java Q1` to `Java Q3`: screening questions. The correct answers are `C`, `2` and `24`.
  - `Q<group><letter>i_1`: the rating for that comparison, as text:
    `Method A is much less complex` / `Method A is slightly less complex` / `No difference` / `Method B is slightly less complex` / `Method B is much less complex`.
  - `...ii`: "explain what the code does" (free text). `...iii`: optional "what made it easier or harder" (free text).
  - **Quirk:** comparison Q7F was exported as `Q126_1` / `Q127` / `Q128` instead of `Q7Fi_1` / `Q7Fii` / `Q7Fiii`. `comparison_pairs.csv` already points `Q7F` at `Q126_1`.
  - Each participant saw a random subset of comparisons (about 10), so most rating cells are blank by design.

**comparison_pairs.csv columns:**
- `item`: the question stem.
- `rating_column`: the column in the raw export.
- `group`, `task`.
- `method_a` / `method_b`: the variant shown on the left/right as Method A/B.
- `method_a_id` / `method_b_id`: the same, as survey IDs.
- `pair_image`: the file in `snippets/images/pair_images/`.

Pairs are every combination of a task's versions in order, with the earlier version as Method A. **Q10 used only ORIG, V1 and V2**, so Q10C is V1 vs V2.

---

## Survey snippets (`snippets/`)

The code shown to survey participants and everything about how it was chosen.

| Path | Contents |
|---|---|
| `snippets/survey_code.java` | Source of the 34 snippets, labelled by survey ID |
| `snippets/snippet_catalogue.csv`, `snippet_metrics.csv` | What each snippet is and its measured metrics |
| `snippets/images/screenshots/`, `snippets/images/pair_images/` | The 34 snippet images and 44 side-by-side pair images, named by survey ID |
| `snippets/images/example_question/` | The practice question shown before the real comparisons |
| `snippets/variant_selection/` | The larger candidate pool before the final variants were chosen, and the ranking spreadsheet |

Survey definition and responses: the survey section above. Snippet metrics are regenerated with `tool/scripts/run_survey.ps1`.

| File / folder | Description |
|---|---|
| `snippet_metrics.csv` | **Snippet metrics**: one row per shown snippet (34 rows), measured by the corrected calculator, which is the same code as the corpus (`run_survey.ps1` → `SurveyAnalyser`). Main method only; helper methods are excluded. Re-measured 15 Oct 2026. |
| `snippets/survey_code.java` | Source code of the 34 snippets, labelled with survey IDs, with a banner per snippet giving its task, its measurements and the single factor it changes. The summary table at the top lists every method measured, helpers included. Matches the pair images participants saw (checked 15 Oct). |
| `snippets/snippet_catalogue.csv` | One row per snippet: `id`, `group`, `task`, `variant`, `main_method`, `function`, `isolating` (the factor the variant changes), and `original_file_id` (its ID in the repo-root `survey_code.java`, which uses older numbering). |
| `snippets/images/screenshots/` | Each snippet's image as participants saw it, named by survey ID: the 17 Aug versions the pair images were built from. |
| `snippets/images/pair_images/` | The side-by-side A \| B image for each of the 44 comparisons, named `<A>_<B>.png` by survey ID. |
| `snippets/images/example_question/` | The practice question shown before the real comparisons. |

**snippet_metrics.csv columns:** `group`, `variant`, `id` (survey ID), `method`, `cc`, `cognitive`, `loc`, `max_nesting`, `avg_nesting`, `fan_out`, `params`, `hal_vol`, `hal_eff`, `avg_id_words`, `comment_count` (in-body comments plus the method's header comment), `has_javadoc`, `recursive`.

**Changes from the 8 Oct values (calculator corrections):**
- **MaxNest:** 01-V1 4→1, 09-V1 3→2, 10-V1 4→3, 10-V2 4→3. An else-if chain is no longer counted as nesting.
- **CogC:** 01-V2 4→10 (chained ternary now penalised for nesting); 03-ORIG and 03-V2 4→3 (recursion counted once per method); 04-V1 2→1 (`Math.max` no longer mistaken for recursion).
- **comment_count:** the Javadoc variants now count their header comment.
- **CC and LOC:** unchanged.

Snippet metrics are regenerated with `scripts/run_survey.ps1` from `snippets/survey_code.java`.
