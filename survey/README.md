# survey/

Everything about the Qualtrics survey: the instrument, the code snippets and images shown to participants, how the variants were selected, and the responses.

| Folder | Contents |
|---|---|
| `instrument/` | `700_survey.qsf` (Qualtrics definition) and `example_question/` (the practice question) |
| `responses/` | `survey_responses_raw.csv` (Qualtrics export) and `comparison_pairs.csv` (which pair each question showed) |
| `snippets/` | `survey_code.java`, `snippet_catalogue.csv`, `snippet_metrics.csv` |
| `images/screenshots/`, `images/pair_images/` | The 34 snippet images and 44 side-by-side pair images, named by survey ID |
| `variant_selection/` | The larger candidate pool before the final variants were chosen, and the ranking spreadsheet |
| `image_drafts/` | Earlier image sets kept for the record (see note below) |

**Note on `image_drafts/`:** these are the image sets that were on the repo's `main` branch while the survey was designed (top-level `*.png`, `screenshots/`, `combinedImages/`). Some files differ from the final ones in `images/` (for example 01-V2, 01-V3, 01-V4, 04-V2, 10-V3), and `combinedImages/` has pairs that were not used. The final survey used `images/`. The live survey loaded its pair images from GitHub `main` at `survey_methods/combinedImages/` (now moved to `survey/image_drafts/combinedImages/`).

## Survey design and responses

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
- **Images were loaded live from GitHub `main`** (`survey_methods/combinedImages/<file-ID pair>.png?raw=true`), so participants saw the 17 Aug versions of those files. Q10A points at the misnamed `10-ORIG-10_V1.png`, which is that file's real name, so it loaded correctly. **Don't rename or delete those files on `main`.** If the survey is ever reopened, it would show broken or changed images.
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
- `pair_image`: the file in `images/pair_images/`.

Pairs are every combination of a task's versions in order, with the earlier version as Method A. **Q10 used only ORIG, V1 and V2**, so Q10C is V1 vs V2.

---

## snippets/

| File / folder | Description |
|---|---|
| `snippet_metrics.csv` | **Snippet metrics**: one row per shown snippet (34 rows), measured by the corrected calculator, which is the same code as the corpus (`run_survey.ps1` → `SurveyAnalyser`). Main method only; helper methods are excluded. Re-measured 15 Oct 2026. |
| `survey_code.java` | Source code of the 34 snippets, labelled with survey IDs, with a banner per snippet giving its task, its measurements and the single factor it changes. The summary table at the top lists every method measured, helpers included. Matches the pair images participants saw (checked 15 Oct). |
| `snippet_catalogue.csv` | One row per snippet: `id`, `group`, `task`, `variant`, `main_method`, `function`, `isolating` (the factor the variant changes), and `original_file_id` (its ID in the repo-root `survey_code.java`, which uses older numbering). |
| `screenshots/` | Each snippet's image as participants saw it, named by survey ID: the 17 Aug versions the pair images were built from. |
| `pair_images/` | The side-by-side A \| B image for each of the 44 comparisons, named `<A>_<B>.png` by survey ID. |
| `example_question/` | The practice question shown before the real comparisons. |

**snippet_metrics.csv columns:** `group`, `variant`, `id` (survey ID), `method`, `cc`, `cognitive`, `loc`, `max_nesting`, `avg_nesting`, `fan_out`, `params`, `hal_vol`, `hal_eff`, `avg_id_words`, `comment_count` (in-body comments plus the method's header comment), `has_javadoc`, `recursive`.

**Changes from the 8 Oct values (calculator corrections):**
- **MaxNest:** 01-V1 4→1, 09-V1 3→2, 10-V1 4→3, 10-V2 4→3. An else-if chain is no longer counted as nesting.
- **CogC:** 01-V2 4→10 (chained ternary now penalised for nesting); 03-ORIG and 03-V2 4→3 (recursion counted once per method); 04-V1 2→1 (`Math.max` no longer mistaken for recursion).
- **comment_count:** the Javadoc variants now count their header comment.
- **CC and LOC:** unchanged.

Snippet metrics are regenerated with `scripts/run_survey.ps1` from `snippets/survey_code.java`.
