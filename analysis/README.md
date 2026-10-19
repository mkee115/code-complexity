# analysis/

| Folder | What it is |
|---|---|
| `report/` | The R pipeline that produces every figure, table and number in the report. **This is the one to run and cite.** |
| `survey_stats/` | Earlier R survey analysis (one script per analysis: chi-squared, change classification, factor effects, complexity scores, metrics vs survey) with its Excel/CSV output |
| `survey_graphs/` | Python survey graphs and isolation analyses (35 charts) |
| `exploratory/` | First look at the corpus (`cc_analysis.R`, `repos_analysis.R`) and its graphs and tables, from the June harvest |
| `poster/` | `poster_graphs.R` and the poster figures |

The scripts in `survey_stats/`, `exploratory/` and `poster/` are standalone: each has its own config block at the top, and the survey ones expect `700_survey.csv` (the raw Qualtrics export, kept out of git because it holds IP addresses) next to them.

# Report pipeline (`report/`)

R pipeline for the final report. It analyses the October 2026 corpus and the survey and produces every figure, table and number the report uses. The data are described in `data/README.md` at the repo root; the metric definitions are in `tool/docs/metric_definitions.md`.

## Running it

From the R project (`report.Rproj`, so the working directory is `analysis/report/`):

```r
source("scripts/run_all.R")
```

or from a terminal in `analysis/report/` (or the repo root, `Rscript analysis/report/scripts/run_all.R`): `Rscript scripts/run_all.R`. It takes about 3 minutes and **empties `output/` first, then regenerates everything**. Randomness is fixed (`SEED = 2026`).

Needs R 4.x with `readr`, `dplyr`, `tidyr`, `ggplot2`, `data.table`, `patchwork`, `ggrepel`, `lme4`, `DescTools`, `irr`, `purrr`, `scales`. The exact versions used are written to `output/sessionInfo.txt`.

**The corpus must be complete before the corpus results are final.** `01_load_data.R` reads `data/corpus/run_log.txt` (repo root); if the harvest has not finished (no `EXIT 0`), the corpus results are marked PROVISIONAL in the figures, the validation log and `report_numbers.csv`. Re-run after the harvest finishes.

## Scripts

| Script | What it does |
|---|---|
| `run_all.R` | Runs the four numbered scripts in order (empties `output/` first) |
| `00_setup.R` | Loads the shared helpers in `lib/`: `config.R` (paths, seed, metric order and colours, report sections), `plot_output.R` (theme, figure/table writers), `checks_numbers.R` (validation log, report-number register), `stats.R` (bootstrap, Wilson CI, concordance, pair sampling) |
| `01_load_data.R` | Survey: reads the Qualtrics export, drops identifying columns, applies the inclusion rule, joins pairs and measurements, validates. Corpus: loads only the columns needed, validates, applies and counts the filters, describes it |
| `02_analysis.R` | RQ1 on the corpus (Spearman, partial correlation, PCA, pairwise concordance, resolution) and on the survey snippets; RQ2 (agreement, kappa, decomposition, metric comparisons, tie status and side, gap vs strength, pair-level, all-tie pairs, position diagnostics, the six 3x3 metric-comparison grids); RQ3 (win rates, original vs refactor, reduction vs preference, kinds of change, exceptions); sensitivity (screening, decisive-only, tie-free, experience, corpus filter) |
| `03_figures.R` | Every figure, one section per report section, then the extra RQ2 robustness analyses with their figures: leave-one-task-out and three-stage cluster bootstrap; who agrees when only one of two metrics does, and commit rate / direction accuracy for the 13 measures; cumulative-link mixed model and ordinal Bradley-Terry (needs the `ordinal` package); forest plot and tie-rate bars; PCA biplot with the survey snippets and the all-tie forest plot |
| `04_tables_and_export.R` | Report-ready tables as PNG, then `report_numbers.csv`, validation log, figure index, `sessionInfo.txt` and the privacy scan |
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
- **Generated code, as applied to the current corpus:** (1) the harvest-time `is_generated` flag (a `*generated*` folder, a generator marker in the first 4 KB of the file, or `@Generated`), then (2) the R filter rules in `02_load_corpus.R`: `DFA<n>` classes and `specialStateTransition` methods, `jj_` methods, `src-gen/` and `generated-sources/` paths, and every method in a file holding a `DFA` / `specialStateTransition` / `jj_` method (file-level propagation). Per-rule counts are in `corpus_generated_rules_effect.csv`. Test code under `/tests/` is not excluded; it is a sensitivity variant only. The full rules and their limits are in `metric_definitions.md` ("Generated code").
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

# Survey graphs (`survey_graphs/`)

Run `python survey_analysis.py` from `analysis/survey_graphs/` (needs pandas, numpy, matplotlib, scipy). Regenerates everything in `output/` (35 charts) and
`tables/` (long-format data + summary CSVs) from the two source files below.

## Source files

- `qualtrics_raw.csv` — the Qualtrics export, trimmed to finished responses +
  the 2 preview runs (abandoned/incomplete responses dropped; they carry no
  comparison data anyway).
- `png_metrics_match_verified.csv` — structural metrics per code screenshot.
  This is a **corrected** version of the `png_metrics_match.csv` you supplied:
  a background verification pass re-checked every one of the 34 screenshots
  against `snippets/survey_code.java` and fixed two mismapped rows (`01-V2.png` and
  `02-V3.png` had the wrong metrics ID attached — see that file's Notes column
  for what changed). The script prefers the verified file automatically and
  falls back to the original if it's absent.

## Known data-quality caveats

1. **1 response row is dropped** from `qualtrics_raw.csv` — one respondent's
   free-text answer contains an unescaped delimiter that throws off the CSV
   field count. Rather than risk silently misaligning every column after it,
   that single row is skipped (printed as a NOTE when the script runs).
2. Q10 ("balanced" / bracket-matching) only shows 3 of the 6 possible pairs
   from its 4 screenshotted versions (`10-V3` was skipped entirely in the
   live survey, confirmed by the survey author) — `QUESTION_META[10]` in
   `survey_analysis.py` only lists `["ORIG", "V1", "V2"]` to match.
   Every question's block→pair mapping (Q1–Q10) was cross-checked against
   `snippets/images/pair_images/` file-naming order and the actual
   screenshot content.
3. **The metrics lookup is keyed off the PNG filename, not the (corrected)
   "Metrics ID" label** — this was a real bug caught while building chart 28:
   two screenshots (`02-V3.png`, `05-V4.png`) turned out, on verification, to
   have code identical to another row's baseline, so their "Metrics ID" was
   relabelled to match that baseline (e.g. `03-ORIG (inferred...)`). A lookup
   keyed by that label collided with the real baseline row and silently
   dropped 66 survey comparisons (every Q2 comparison involving "V3" and every
   Q5 comparison involving "V4") to `NaN`. `load_metrics()` now derives a
   separate `screenshot_group`/`png_version` pair straight from the PNG
   filename — which is what the survey actually displayed and never gets
   relabelled — and uses that for the join. Fixed; all 740 comparisons now
   carry real metric deltas (verify with `tables/long_responses.csv`).

## What each chart shows

- **01–02** demographics (degree, self-rated Java experience by program size written)
- **03–05** response patterns: which side people picked, by question and overall;
  completion (everyone who starts finishes all 10 assigned comparisons — the
  survey randomly shows each respondent one pairing per question, 10 total)
- **06–09** the core research question — which complexity metric best predicts
  what participants actually said felt simpler, where that breaks down by
  question, whether bigger metric gaps produce more confident answers, and a
  specific finding that Cyclomatic Complexity often ties (misses control-flow
  differences that read as very different in practice) where Cognitive
  Complexity doesn't, and Cognitive Complexity calls those cases right ~80%+
  of the time
- **10–12** supporting context: spread of each metric across all code shown,
  how correlated the metrics are with each other, and whether participant
  experience level changes agreement with Cyclomatic Complexity
- **13** the strength-vs-gap boxplot (chart 08) extended to all 6 structural
  metrics, not just CC and Cognitive Complexity
- **14–15** raw scatter of each metric's gap against the actual response,
  jittered — the unaggregated data behind charts 06–08
- **16–17** confusion matrices: given what CC / Cognitive Complexity predicted
  (favours A / tie / favours B), what did people actually say across the full
  5-point scale
- **18** every one of the 35 code variants ranked by how often it "won" its
  comparisons (ties split 50/50), colour-coded baseline vs. refactor
- **19** baseline vs. refactor head-to-head, restricted to comparisons that
  included the original (unrefactored) version
- **20–21** Java comprehension check pass rate, and whether passing it changes
  agreement with CC (a data-quality/robustness check)
- **22** agreement with CC, by degree programme
- **23** does a stronger stated preference come with a longer written
  justification
- **24** how long the survey took to complete
- **25** how often individual respondents call it a tie, across their 10 answers
- **26** spread of CC and LOC across all screenshotted code, grouped by question
  (extends chart 10, which pools every question together)
- **27–34** the metrics on their own terms — no survey responses, no A/B, no
  question number:
  - **27** key pairwise scatters between metrics with fitted trend lines (the
    visual, unaggregated version of the correlation matrix)
  - **28** every one of the 35 code variants ranked by a composite z-score
    across CC/Cognitive/LOC/MaxNest/HalVol/HalEff — which single samples are
    the most/least complex overall
  - **29** does refactoring systematically lower each metric (baseline vs.
    refactor box plots, one panel per metric)
  - **30** coefficient of variation per metric — which one actually spreads
    out across this code, relative to its own scale
  - **31** the correlation matrix again, by rank (Spearman) instead of Pearson
    — compare against chart 11 to see how much the `balanced` task's outlier
    values were inflating the linear correlations
  - **32** Halstead Volume vs. Effort in isolation, with a fitted line
  - **33** a from-scratch PCA (no extra dependency) of all 8 metrics across
    all 35 variants, colour-coded by task — do these metrics collapse to one
    "complexity" dimension or several (PC1+PC2 explain ~76% here)
  - **34** Fan-Out vs. Cyclomatic Complexity — whether calling out to more
    helpers/library methods tends to track with more branching or trade off
    against it (weak positive relationship, r≈0.4 — not the trade-off one
    might expect)
  - **35** CC vs. Cognitive Complexity per method — one panel per task
    (grade/check/sd/max/dedupe/tally/merge/roman/bs/balanced), grouped bars
    of both metrics across every refactor variant of that method. Makes the
    chart-09 finding concrete at the method level: e.g. `grade`'s CC barely
    moves (5→5→5→5) while its Cognitive score swings 14→5→4→14, and `check`'s
    V2 actually *raises* CC (4→6) while Cognitive still falls (2→1)
