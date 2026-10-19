# code-complexity

Part 4 Project (SOFTENG 700): **Measuring code complexity**.

This repository mines Java repositories from GitHub, measures per-method complexity and readability metrics with [JavaParser](https://javaparser.org/), runs a survey asking programmers which of two code versions is easier to understand, and analyses both in R (and some Python).

## Repository layout

```
code-complexity/
├── tool/                    Maven project: the metric extractor and GitHub harvester
│   ├── config.properties        run mode, search filters, output location
│   ├── src/main, src/test       calculators (CC, cognitive, LOC, nesting, Halstead, ...) and unit tests
│   ├── scripts/                 run_survey.ps1, check_corpus_progress.ps1
│   └── docs/                    METRIC_DEFINITIONS.md: how every metric is calculated, and why
├── data/
│   ├── corpus/                  GitHub harvest, October 2026: cc_data.csv, repos.csv, skipped.csv, run_log.txt
│   └── survey/                  Qualtrics definition (.qsf), raw responses, which pair each question showed
├── snippets/                the code shown to survey participants
│   ├── survey_code.java         the 34 snippets, with catalogue and measured metrics
│   ├── images/                  screenshots, side-by-side pair images, the practice question
│   └── variant_selection/       candidate pool before the variants were chosen, ranking spreadsheet
└── analysis/
    ├── report/                  the pipeline that produces every figure, table and number in the report
    │   ├── scripts/                 numbered R scripts + run_all.R
    │   └── output/                  generated figures, tables, report_numbers.csv
    ├── survey_stats/            earlier R survey analysis (chi-squared, change classification, ...)
    ├── survey_graphs/           Python survey graphs and isolation analyses
    ├── exploratory/             first corpus analysis (cc_analysis.R, repos_analysis.R) and its output
    └── poster/                  poster script and figures
```

Each of `data/`, `data/survey/`, `snippets/` and `analysis/report/` has its own README with the detail.

## Requirements

- **JDK 17+** and **Maven** (the extractor)
- **R 4.x** (the report pipeline lists its packages in `analysis/report/README.md`; versions used are in `analysis/report/output/sessionInfo.txt`)
- **Python 3** with pandas, numpy, matplotlib, scipy (only for `analysis/survey_graphs/`)
- A **GitHub personal access token** in `tool/.token` (only for the `GITHUB_SEARCH` and `GITHUB_REPO` modes; never commit it)

## Reproducing the work

**1. Harvest the corpus** (hours; resumable). Configure `tool/config.properties`, then from `tool/`:

```bash
mvn compile
mvn exec:java                                          # uses ./config.properties
mvn exec:java -Dexec.args="path/to/other.properties"   # alternate config
```

Output goes to `data/corpus/`. Modes: `LOCAL_PATH` (a file or folder), `GITHUB_REPO` (one repo), `GITHUB_SEARCH` (search by filters, clone and analyse in parallel). With `output.append=true` a restarted harvest skips repos already in `repos.csv`. Check progress with `tool/scripts/check_corpus_progress.ps1`.

`data/corpus/cc_data.csv` is 2 GB and is **not in git**; it is supplied with the compendium.

**2. Measure the survey snippets** (from the repo root):

```powershell
./tool/scripts/run_survey.ps1      # writes snippets/snippet_metrics.csv
```

**3. Run the report analysis** (about 3 minutes; empties and regenerates `analysis/report/output/`):

```bash
Rscript analysis/report/scripts/run_all.R
```

**4. Unit tests:**

```bash
cd tool && mvn test
```

## Metrics

See [tool/docs/METRIC_DEFINITIONS.md](tool/docs/METRIC_DEFINITIONS.md) for the definition of each metric and the reasoning behind it. The columns of `cc_data.csv` are described in [data/README.md](data/README.md).

| Metric                  | Source class                     |
|-------------------------|----------------------------------|
| Cyclomatic complexity   | `CyclomaticComplexityVisitor`    |
| Cognitive complexity    | `CognitiveComplexityVisitor`     |
| LOC (non-blank, non-comment) and physical | `MethodLocCalculator` |
| Nesting depth           | `MethodNestingCalculator`        |
| Identifier / comments   | `IdentifierMetricsCalculator`    |
| Halstead measures       | `HalsteadCalculator`             |
| Maintainability Index   | `MaintainabilityIndexCalculator` |
| Structure (params, returns, fan-out) | `MethodStructureCalculator` |
| Line length             | `LineLengthCalculator`           |

## Notes

- `analysis/survey_stats/`, `analysis/survey_graphs/`, `analysis/exploratory/` and `analysis/poster/` are earlier or supporting analyses. The report numbers come from `analysis/report/`.
- Some of those scripts still need their input files supplied: `survey_graphs/` expects `qualtrics_raw.csv` and `png_metrics_match*.csv` beside it, and the poster script reads `analysis/survey_stats/700_survey.csv` and `variant_metrics.csv`.
- The live survey loaded its pair images from GitHub `main` at `survey_methods/combinedImages/`; those files are now in `snippets/images/pair_images/` (earlier draft image sets are in git history).
