# Survey analysis: perceived vs. measured code complexity

Run `python survey_analysis.py` (needs pandas/numpy/matplotlib — already installed
into the repo's `.venv`). Regenerates everything in `output/` (35 charts) and
`tables/` (long-format data + summary CSVs) from the two source files below.

## Source files

- `qualtrics_raw.csv` — the Qualtrics export, trimmed to finished responses +
  the 2 preview runs (abandoned/incomplete responses dropped; they carry no
  comparison data anyway).
- `png_metrics_match_verified.csv` — structural metrics per code screenshot.
  This is a **corrected** version of the `png_metrics_match.csv` you supplied:
  a background verification pass re-checked every one of the 34 screenshots
  against `survey_code.java` and fixed two mismapped rows (`01-V2.png` and
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
   `survey_methods/combinedImages/` file-naming order and the actual
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
