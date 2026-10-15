# Report analysis pipeline

R pipeline for the final report. It analyses the October 2026 corpus and the survey and produces every figure, table and number the report uses. The data files and metric definitions are described in `README.md` and `METRIC_DEFINITIONS.md`; the specification is `data/REPORT_ANALYSIS_BRIEF.md`.

## Running it

From the R project (`report_analysis.Rproj`, so the working directory is `report_analysis/`):

```r
source("scripts/run_all.R")
```

or from a terminal in `report_analysis/`: `Rscript scripts/run_all.R`. It takes about 3 minutes and **empties `output/` first, then regenerates everything**. Randomness is fixed (`SEED = 2026`).

Needs R 4.x with `readr`, `dplyr`, `tidyr`, `ggplot2`, `data.table`, `patchwork`, `ggrepel`, `lme4`, `DescTools`, `irr`, `purrr`, `scales`. The exact versions used are written to `output/sessionInfo.txt`.

**The corpus must be complete before the corpus results are final.** `02_corpus.R` reads `data/corpus/run_log.txt`; if the harvest has not finished (no `EXIT 0`), the corpus results are marked PROVISIONAL in the figures, the validation log and `report_numbers.csv`. Re-run after the harvest finishes.

## Scripts

| Script | What it does |
|---|---|
| `00_setup.R` | Packages, paths, seed, metric order and colours, figure/table helpers, validation log, bootstrap helpers |
| `01_load_survey.R` | Reads the Qualtrics export, drops identifying columns, applies the inclusion rule, joins pairs and measurements, validates |
| `02_corpus.R` | Loads the corpus (only the columns needed), validates, applies and counts the filters, describes it, log-log figure |
| `03_rq1_corpus.R` | RQ1 on the corpus: Spearman, partial correlation, PCA, pairwise concordance, resolution |
| `03_rq1_survey.R` | RQ1 on the survey snippets: concordance over the 44 pairs, resolution, PCA, correlations |
| `04_rq2.R` | RQ2: agreement, kappa, decomposition, metric comparisons, tie status and side, gap vs strength, pair-level, all-tie pairs, position diagnostics |
| `04b_rq2_grids.R` | The six 3x3 metric-comparison grids and the tests where metrics disagree |
| `05_rq3.R` | RQ3: win rates, original vs refactor, reduction vs preference, kinds of change, exceptions |
| `06_sensitivity.R` | Screening, decisive-only, tie-free, experience, corpus filter sensitivity |
| `07_figures.R`, `07_tables.R` | All figures and PNG tables |
| `08_export.R` | `report_numbers.csv`, validation log, figure index, `sessionInfo.txt`, privacy scan |
| `figure_takeaways.csv` | The suggested one-sentence takeaway for each figure (written by hand after reading the results; re-read after a re-run) |

## Outputs

| Path | Contents |
|---|---|
| `output/figures/` | Report-candidate figures (PNG, 300 dpi, A4 text width). `fig01`-`fig17`; the six grids are `fig08_a`-`fig08_f` |
| `output/diagnostics/` | Diagnostic and exploratory figures (`diag_*`), the validation log, and unused table PNGs |
| `output/tables/` | `tbl_*.png`: report-ready tables. CSV files: full results behind every figure and table |
| `output/report_numbers.csv` | Every quoted number: name, value, 95% CI, n, denominator, test, p, section, subset, note |
| `output/figure_index.csv` | Each figure, its folder, research question, purpose, suggested report use and takeaway |
| `output/diagnostics/validation_log.csv` | Every data check and whether it passed |
| `output/sessionInfo.txt` | R and package versions |
| `output/work/` | Intermediate files passed between scripts (safe to delete) |

## Definitions used throughout

- **Metric / measurement:** a metric is the rule (CC); a measurement is its value for one method.
- **Inclusion:** completed responses only (Progress = 100, Finished = True, previews removed): 75 participants, 750 comparisons, 44 pairs, exactly 10 responses each.
- **Coding:** participant = sign(rating − 3), negative = A judged less complex. Metric prediction = sign(value_A − value_B), negative = A has the lower measurement. A response **agrees** when the two signs match; **a metric tie agrees only with "No difference"**. Ties are kept in.
- **Main corpus:** methods only (constructors excluded), with a body, not nested in another method, not generated code. Counts at each step are in `output/tables/corpus_filter_counts.csv`. Sensitivity to each choice (and to removing duplicates) is in `sensitivity_corpus_filters*`.
- **Uncertainty:** survey results use a participant-level cluster bootstrap (10,000 resamples). Exact binomial and McNemar tests treat responses as independent, and are labelled so. Holm correction over each family of tests. Corpus correlations are effect sizes: p-values are not used at this n.
- **Corpus concordance** is estimated from 1,000,000 random method pairs (and 1,000,000 pairs of non-trivial methods, LOC >= 10 or CC >= 3). The intervals reflect pair sampling only, not how representative the corpus is.
- **PCA:** log(1 + x), then standardised (a rank-based check is in `rq1_corpus_pca_key_variance_rank_check.csv`). The survey PCA covers 34 deliberately constructed snippets, not a random sample.

## Known limitations of the data and the analysis

- Method A was always the earlier version and the task order was fixed (not counterbalanced). Position diagnostics are in `diag_position_lean.png` and `fig09`; they look for evidence of an effect and cannot prove there is none.
- The survey pairs were built to make metrics differ, so agreement percentages describe these pairs, not a population of Java methods or developers.
- No pair has CC and CogC pointing in opposite directions, so the strongest test of which is closer to perception cannot be run; only the "CC ties, CogC separates" cells can be tested.
- Many pairs have few responses (6 to 75), so pair-level results are imprecise.
- Recursion is detected syntactically (no receiver or `this`/own class, matching argument count), so indirect recursion is missed.
- Self-reported experience groups at the ends ("none": 5 participants, "large": 3) are too small for inference.
