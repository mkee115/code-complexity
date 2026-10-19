# data/

Raw corpus data from the GitHub harvest. Nothing here has been processed. How every metric is calculated: [../tool/docs/METRIC_DEFINITIONS.md](../tool/docs/METRIC_DEFINITIONS.md). The analysis that uses it: [../analysis/report/README.md](../analysis/report/README.md).

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

**Selection criteria** (the same as the June harvest): Java, at least 10 stars, at least 10 forks, pushed to on or after 2026-01-01, created on or before 2026-01-01, `pom.xml` at the repo root (Maven). Test folders (`src/test`, `src/it`) were excluded. Both methods and constructors are recorded (see `kind`). Metric definitions: `METRIC_DEFINITIONS.md`.

The June 2026 harvest (1,894 repositories, 7,295,624 methods, measured with the earlier calculator) is no longer kept here; the original is in `analysis/data_tables/`.

For the report analysis: `ANALYSIS_README.md` (scripts, outputs, the main-corpus filter and the counts at each step).

The June 2026 harvest (1,894 repositories, 7,295,624 methods, measured with the earlier calculator) was superseded by the October harvest and is not kept in this repository.
