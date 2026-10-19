# Report analysis pipeline

R pipeline for the final report. It analyses the October 2026 corpus and the survey and produces every figure, table and number the report uses. The data are described in `data/README.md` (corpus) and `data/survey/README.md` (survey) and `snippets/README.md` (snippets) at the repo root; the metric definitions are in `tool/docs/METRIC_DEFINITIONS.md`.

## Running it

From the R project (`report_analysis.Rproj`, so the working directory is `analysis/report/`):

```r
source("scripts/run_all.R")
```

or from a terminal in `analysis/report/` (or the repo root, `Rscript analysis/report/scripts/run_all.R`): `Rscript scripts/run_all.R`. It takes about 3 minutes and **empties `output/` first, then regenerates everything**. Randomness is fixed (`SEED = 2026`).

Needs R 4.x with `readr`, `dplyr`, `tidyr`, `ggplot2`, `data.table`, `patchwork`, `ggrepel`, `lme4`, `DescTools`, `irr`, `purrr`, `scales`. The exact versions used are written to `output/sessionInfo.txt`.

**The corpus must be complete before the corpus results are final.** `02_load_corpus.R` reads `data/corpus/run_log.txt` (repo root); if the harvest has not finished (no `EXIT 0`), the corpus results are marked PROVISIONAL in the figures, the validation log and `report_numbers.csv`. Re-run after the harvest finishes.

## Scripts

| Script | What it does |
|---|---|
| `run_all.R` | Runs everything below in order (empties `output/` first) |
| `00_setup.R` | Loads the shared helpers in `lib/`: `config.R` (paths, seed, metric order and colours, report sections), `plot_output.R` (theme, figure/table writers), `checks_numbers.R` (validation log, report-number register), `stats.R` (bootstrap, Wilson CI, concordance, pair sampling) |
| `01_load_survey.R` | Reads the Qualtrics export, drops identifying columns, applies the inclusion rule, joins pairs and measurements, validates |
| `02_load_corpus.R` | Loads the corpus (only the columns needed), validates, applies and counts the filters, describes it |
| `03_rq1_corpus.R` | RQ1 on the corpus: Spearman, partial correlation, PCA, pairwise concordance, resolution |
| `04_rq1_survey.R` | RQ1 on the survey snippets: concordance over the 44 pairs, resolution, PCA, correlations |
| `05_rq2_agreement.R` | RQ2: agreement, kappa, decomposition, metric comparisons, tie status and side, gap vs strength, pair-level, all-tie pairs, position diagnostics |
| `06_rq2_grids.R` | The six 3x3 metric-comparison grids and the tests where metrics disagree |
| `07_rq3_refactoring.R` | RQ3: win rates, original vs refactor, reduction vs preference, kinds of change, exceptions |
| `08_sensitivity.R` | Screening, decisive-only, tie-free, experience, corpus filter sensitivity |
| `09_figures_data.R`, `10_figures_rq1.R`, `11_figures_rq2.R`, `12_figures_rq3.R` | Figures, one script per report section |
| `12a_task_robustness.R` | RQ2: leave-one-task-out agreement and the three-stage (task / pair / participant) cluster bootstrap of the six pairwise differences |
| `12b_commit_rate_and_measures.R` | RQ2: who agrees when only one of two metrics does (split by whether CC ties); commit rate, direction accuracy, tie rate and agreement for the 13 measures |
| `12c_ordinal_models.R` | RQ2: cumulative-link mixed model of the 1-5 ratings on the four metrics (needs the `ordinal` package, called as `ordinal::`), and the within-task ordinal Bradley-Terry model of snippet scores |
| `12d_forest_and_tie_bars.R` | RQ2: `fig08_a` forest plot (pairs where CC ties) and `fig10` tie rate by the participant's answer (these replace the CC-vs-CogC grid and the gap-vs-strength box plots) |
| `12e_biplot_and_all_tie.R` | RQ1 PCA biplot with the survey snippets; RQ2 forest plot of the seven all-tie pairs |
| `13_tables.R` | Report-ready tables as PNG |
| `14_export.R` | `report_numbers.csv`, validation log, figure index, `sessionInfo.txt`, privacy scan |
| `figure_takeaways.csv` | The suggested one-sentence takeaway for each figure (written by hand after reading the results; re-read after a re-run) |

Every figure is also written without its title and subtitle to `output/figures_no_titles/<section>/`. The appendix figures from `12a`-`12e` have no title in either version.

## Outputs

| Path | Contents |
|---|---|
| `output/1_data_and_corpus/` | Corpus and survey description: corpus filter counts and summary, snippet measurements, the position check, corpus-filter sensitivity, `fig01` |
| `output/2_rq1_do_metrics_agree/` | RQ1 (do the metrics order methods the same way?): `fig02`-`fig05`, the `diag_rq1_*` figures and every RQ1 table |
| `output/3_rq2_agreement_with_programmers/` | RQ2 (which metric agrees most with participants?): `fig06`-`fig13` (grids are `fig08_a`-`fig08_f`), the `diag_rq2_*` figures, sensitivity analyses and every RQ2 table |
| `output/4_rq3_refactoring/` | RQ3 (does reducing a measurement reduce perceived complexity?): `fig14`-`fig17`, `diag_rq3_*` and every RQ3 table |
| `output/report_numbers.csv` | Every quoted number: name, value, 95% CI, n, denominator, test, p, section, subset, note |
| `output/figure_index.csv` | Each figure, its section folder, research question, purpose, suggested report use and takeaway |
| `output/sessionInfo.txt` | R and package versions |
| `output/_pipeline/` | Working files: intermediate data passed between scripts, and `validation_log.csv` (every data check and whether it passed). Safe to delete; regenerated by `run_all.R` |

Inside each section folder:
- `important/`: the figures and tables the report is built around (the figures marked "main" in `scripts/figure_takeaways.csv`, plus `tbl_corpus_filter_counts`, `tbl_corpus_summary`, `tbl_rq2_agreement_summary` and `tbl_rq3_original_vs_refactor`).
- `optional/`: supporting and appendix figures and tables, to include if they fit or if you decide you want them. `diag_*` marks the supporting and appendix figures.
- `csv/`: the full results behind every figure and table.

To promote or demote an output, change `suggested_use` (figures) in `scripts/figure_takeaways.csv` or `IMPORTANT_TABLES` (tables) in `scripts/lib/plot_output.R`, then re-run.

## Definitions used throughout

- **Metric / measurement:** a metric is the rule (CC); a measurement is its value for one method.
- **Inclusion:** completed responses only (Progress = 100, Finished = True, previews removed): 75 participants, 750 comparisons, 44 pairs, exactly 10 responses each.
- **Coding:** participant = sign(rating − 3), negative = A judged less complex. Metric prediction = sign(value_A − value_B), negative = A has the lower measurement. A response **agrees** when the two signs match; **a metric tie agrees only with "No difference"**. Ties are kept in.
- **Main corpus:** methods only (constructors excluded), with a body, not nested in another method, not generated code: 4,315,785 methods. Counts at each step are in `output/1_data_and_corpus/corpus_filter_counts.csv`. Sensitivity to each choice (and to removing duplicates) is in `sensitivity_corpus_filters*`.
- **Generated code, as applied to the current corpus:** (1) the harvest-time `is_generated` flag (a `*generated*` folder, a generator marker in the first 4 KB of the file, or `@Generated`), then (2) the R filter rules in `02_load_corpus.R`: `DFA<n>` classes and `specialStateTransition` methods, `jj_` methods, `src-gen/` and `generated-sources/` paths, and every method in a file holding a `DFA` / `specialStateTransition` / `jj_` method (file-level propagation). Per-rule counts are in `corpus_generated_rules_effect.csv`. Test code under `/tests/` is not excluded; it is a sensitivity variant only. The full rules and their limits are in `METRIC_DEFINITIONS.md` ("Generated code").
- **Calculator changes for a future harvest only:** ANTLR header markers and `src-gen/` in `ComplexityCalculator.java`. They are not in the October corpus, which has no file text to re-check, so they have no effect on any current number.
- **Uncertainty:** survey results use a participant-level cluster bootstrap (10,000 resamples). Exact binomial and McNemar tests treat responses as independent, and are labelled so. Holm correction over each family of tests. Corpus correlations are effect sizes: p-values are not used at this n.
- **Corpus concordance** is estimated from 1,000,000 random method pairs (and 1,000,000 pairs of non-trivial methods, CC >= 3). The intervals reflect pair sampling only, not how representative the corpus is.
- **PCA:** log(1 + x), then standardised (a rank-based check is in `rq1_corpus_pca_key_variance_rank_check.csv`). The survey PCA covers 34 deliberately constructed snippets, not a random sample.

## Known limitations of the data and the analysis

- Method A was always the earlier version and the task order was fixed (not counterbalanced). Position diagnostics are in `diag_position_lean.png` (section 1) and `fig09` (section 3); they look for evidence of an effect and cannot prove there is none.
- The survey pairs were built to make metrics differ, so agreement percentages describe these pairs, not a population of Java methods or developers.
- No pair has CC and CogC pointing in opposite directions, so the strongest test of which is closer to perception cannot be run; only the "CC ties, CogC separates" cells can be tested.
- Many pairs have few responses (6 to 75), so pair-level results are imprecise.
- Recursion is detected syntactically (no receiver or `this`/own class, matching argument count), so indirect recursion is missed.
- Self-reported experience groups at the ends ("none": 5 participants, "large": 3) are too small for inference.
