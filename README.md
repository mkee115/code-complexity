# code-complexity

Part 4 Project — **Measuring code complexity**.

This repository contains a toolchain that mines Java repositories from GitHub,
computes a suite of per-method complexity and readability metrics with
[JavaParser](https://javaparser.org/), and analyses the resulting dataset in R.

## Repository layout

```
Cyclomatic Complexity Calculator/
├── javaparser-complexity-calculator/   # Maven project — the metric extractor
│   └── src/main/java/com/complexity/
│       ├── ComplexityCalculator.java        # entry point / orchestration + config
│       ├── GitHubRepositorySearcher.java    # GitHub search + chunked harvesting
│       ├── CyclomaticComplexityVisitor.java # cyclomatic complexity (CC)
│       ├── CognitiveComplexityVisitor.java  # cognitive complexity
│       ├── MethodLocCalculator.java         # NBNC + physical lines of code
│       ├── MethodNestingCalculator.java     # average / max nesting depth
│       └── IdentifierMetricsCalculator.java # naming + comment metrics
├── analysis/                            # R analysis of the generated CSVs
│   ├── cc_analysis.R                         # per-method metric analysis
│   └── repos_analysis.R                      # repository-level analysis
└── cc_calculator.py                     # legacy regex prototype (superseded)
```

## Requirements

- **JDK 17+** and **Maven** (the metric extractor)
- **R 4.x** with `tidyverse`, `scales`, `moments`, `GGally`, `ggridges`, `broom`
- A **GitHub personal access token** (only for `GITHUB_SEARCH` / `GITHUB_REPO`
  modes), stored in a plain-text file named `.token` in the working directory.

## Running the extractor

Configuration lives in [`config.properties`](Cyclomatic%20Complexity%20Calculator/javaparser-complexity-calculator/config.properties)
(no recompilation needed). Set `run.mode` to one of:

| Mode            | What it does                                                        | Relevant keys                       |
|-----------------|--------------------------------------------------------------------|-------------------------------------|
| `LOCAL_PATH`    | Scan a local `.java` file or directory tree                        | `local.input`                       |
| `GITHUB_REPO`   | Clone and analyse a single repo                                    | `single.repo.url`                   |
| `GITHUB_SEARCH` | Search GitHub by filters, clone matches, and analyse them in bulk  | `search.*`, `threads`, `token.file` |

Then build and run from `javaparser-complexity-calculator/`:

```bash
mvn compile
mvn exec:java                                   # uses ./config.properties
mvn exec:java -Dexec.args="path/to/other.properties"   # alternate config
```

`GITHUB_SEARCH` runs are **parallelised** (`threads`) and **resumable**: with
`output.append=true`, repos already present in `repos.csv` are skipped, so an
interrupted harvest can be restarted without redoing work.

### Output

Results are written to `../analysis/data_tables/` (next to the R scripts) as CSV:

- **`cc_data.csv`** — one row per method:
  `project, class_name, method_name, cc, cognitive_complexity, loc, loc_physical,
  avg_nesting, max_nesting, avg_id_words, abbreviated_ratio, single_letter_ids,
  longest_id, total_words, comment_count, comment_words, halstead_volume,
  halstead_difficulty, halstead_effort, maintainability_index, mi_normalized,
  param_count, return_count, fan_out, max_line_length, avg_line_length`
- **`repos.csv`** — one row per harvested repository (stars, forks, size, commit
  count, Java file count, timestamps)
- **`skipped.csv`** — methods/files/repos that could not be processed, with reasons

## Running the analysis

From `analysis/` (with the CSVs present):

```r
source("cc_analysis.R")     # per-method metrics
source("repos_analysis.R")  # repo-level metrics
```

Generated **plots** go to `analysis/graphs/` (grouped into numbered sub-folders)
and generated **CSV tables** (plus the raw program output read back in) go to
`analysis/data_tables/`. Both are ignored by git.

## Metrics

| Metric                  | Source class                  | Notes                                                    |
|-------------------------|-------------------------------|----------------------------------------------------------|
| Cyclomatic complexity   | `CyclomaticComplexityVisitor` | +1 per branch / loop / case label / `&&` / `\|\|` / `?:`  |
| Cognitive complexity    | `CognitiveComplexityVisitor`  | nesting-weighted, SonarSource-style                      |
| LOC (NBNC) + physical   | `MethodLocCalculator`         | non-blank-non-comment line count vs raw line span        |
| Nesting depth           | `MethodNestingCalculator`     | average and maximum structural nesting                   |
| Identifier / comments   | `IdentifierMetricsCalculator` | word counts, abbreviation ratio, single-letter ids, etc. |
| Halstead measures       | `HalsteadCalculator`          | volume, difficulty, effort from operator/operand counts  |
| Maintainability Index   | `MaintainabilityIndexCalculator` | raw + 0-100 normalised composite of volume, CC, LOC   |
| Structure               | `MethodStructureCalculator`   | parameter count, return-statement count, fan-out         |
| Line length             | `LineLengthCalculator`        | maximum and average source line width                    |

## Metric definitions

### First-degree metrics (measured directly by the Java extractor)

These are read straight off each method's source/AST — no other metric feeds into them.

| Column | Meaning |
|--------|---------|
| `cc` | **Cyclomatic complexity** — number of linearly independent paths through the method. Starts at 1 and adds 1 for every branch point (`if`, `for`, `while`, `case`, `catch`, `&&`, `\|\|`, ternary). |
| `cognitive_complexity` | **Cognitive complexity** (SonarSource style) — like CC but weighted by how hard the control flow is to *follow*: each level of nesting adds an increasing penalty, and linear sequences are not penalised. |
| `loc` | **Lines of code (NBNC)** — non-blank, non-comment source lines in the method body. |
| `loc_physical` | **Physical LOC** — total line span of the method including blanks and comments. |
| `avg_nesting` | Average structural nesting depth across the method's statements. |
| `max_nesting` | Deepest level of nested blocks (loops/conditionals) reached. |
| `avg_id_words` | Average number of words per identifier (split on camelCase / `snake_case`). |
| `abbreviated_ratio` | Fraction of identifiers that look abbreviated (no clear word boundaries / very short). |
| `single_letter_ids` | Count of single-letter identifiers (`i`, `x`, …). |
| `longest_id` | Character length of the longest identifier. |
| `total_words` | Total identifier words in the method. |
| `comment_count` | Number of comment blocks attached to the method. |
| `comment_words` | Total words contained in those comments. |
| `halstead_volume` | **Halstead volume** = program length × log₂(vocabulary), from distinct/total operator and operand token counts — a size measure weighted by vocabulary. |
| `halstead_difficulty` | **Halstead difficulty** = (n₁/2) × (N₂/n₂) — how error-prone the method is to write/read. |
| `halstead_effort` | **Halstead effort** = difficulty × volume — estimated mental effort to (re)create the method. |
| `param_count` | Number of declared parameters. |
| `return_count` | Number of `return` statements. |
| `fan_out` | Number of *distinct* methods called from this method (outgoing coupling). |
| `max_line_length` | Longest source line (characters) within the method. |
| `avg_line_length` | Average source line length within the method. |

> Halstead volume/difficulty/effort are themselves derived from the underlying
> operator/operand counts, but those counts are computed in the same pass from
> the token stream, so the three Halstead measures are treated as first-degree
> outputs here.

### Derived (higher-degree) metrics — computed *from* the first-degree metrics

| Column / name | Where | Formula & meaning |
|---------------|-------|-------------------|
| `maintainability_index` | Java (`MaintainabilityIndexCalculator`) | `171 − 5.2·ln(halstead_volume) − 0.23·cc − 16.2·ln(loc)` — the classic composite maintainability score (higher = more maintainable). |
| `mi_normalized` | Java | `maintainability_index` rescaled to a 0–100 range. |
| `cc_per_loc` | R analysis | `cc / loc` — branching density per line. |
| `cog_ratio` | R analysis | `cognitive_complexity / cc` — how much the cognitive metric penalises beyond raw branching. |
| `cog_excess` | R analysis | `cognitive_complexity − cc` — absolute extra penalty. |
| `naming_score` | R analysis | `avg_id_words × (1 − abbreviated_ratio)` — proxy for descriptive naming quality. |
| `comment_density` | R analysis | `comment_words / loc` — documentation per line. |
| `word_density` | R analysis | `total_words / loc` — identifier words per line. |
| `blank_ratio` | R analysis | `(loc_physical − loc) / loc_physical` — share of blank/comment lines. |

## Tests

```bash
cd "Cyclomatic Complexity Calculator/javaparser-complexity-calculator"
mvn test
```

> **Note:** `cc_calculator.py` is an early regex-based prototype kept for
> reference only. The JavaParser-based extractor supersedes it and is the
> supported tool.
