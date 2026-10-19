# snippets/

The code shown to survey participants and everything about how it was chosen.

| Path | Contents |
|---|---|
| `survey_code.java` | Source of the 34 snippets, labelled by survey ID |
| `snippet_catalogue.csv`, `snippet_metrics.csv` | What each snippet is and its measured metrics |
| `images/screenshots/`, `images/pair_images/` | The 34 snippet images and 44 side-by-side pair images, named by survey ID |
| `images/example_question/` | The practice question shown before the real comparisons |
| `variant_selection/` | The larger candidate pool before the final variants were chosen, and the ranking spreadsheet |

Survey definition and responses: [`../data/survey/`](../data/survey/README.md). Snippet metrics are regenerated with `tool/scripts/run_survey.ps1`.

| File / folder | Description |
|---|---|
| `snippet_metrics.csv` | **Snippet metrics**: one row per shown snippet (34 rows), measured by the corrected calculator, which is the same code as the corpus (`run_survey.ps1` → `SurveyAnalyser`). Main method only; helper methods are excluded. Re-measured 15 Oct 2026. |
| `survey_code.java` | Source code of the 34 snippets, labelled with survey IDs, with a banner per snippet giving its task, its measurements and the single factor it changes. The summary table at the top lists every method measured, helpers included. Matches the pair images participants saw (checked 15 Oct). |
| `snippet_catalogue.csv` | One row per snippet: `id`, `group`, `task`, `variant`, `main_method`, `function`, `isolating` (the factor the variant changes), and `original_file_id` (its ID in the repo-root `survey_code.java`, which uses older numbering). |
| `images/screenshots/` | Each snippet's image as participants saw it, named by survey ID: the 17 Aug versions the pair images were built from. |
| `images/pair_images/` | The side-by-side A \| B image for each of the 44 comparisons, named `<A>_<B>.png` by survey ID. |
| `images/example_question/` | The practice question shown before the real comparisons. |

**snippet_metrics.csv columns:** `group`, `variant`, `id` (survey ID), `method`, `cc`, `cognitive`, `loc`, `max_nesting`, `avg_nesting`, `fan_out`, `params`, `hal_vol`, `hal_eff`, `avg_id_words`, `comment_count` (in-body comments plus the method's header comment), `has_javadoc`, `recursive`.

**Changes from the 8 Oct values (calculator corrections):**
- **MaxNest:** 01-V1 4→1, 09-V1 3→2, 10-V1 4→3, 10-V2 4→3. An else-if chain is no longer counted as nesting.
- **CogC:** 01-V2 4→10 (chained ternary now penalised for nesting); 03-ORIG and 03-V2 4→3 (recursion counted once per method); 04-V1 2→1 (`Math.max` no longer mistaken for recursion).
- **comment_count:** the Javadoc variants now count their header comment.
- **CC and LOC:** unchanged.

Snippet metrics are regenerated with `scripts/run_survey.ps1` from `snippets/survey_code.java`.
