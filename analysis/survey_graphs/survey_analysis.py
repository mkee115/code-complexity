"""
Survey analysis: perceived code complexity vs measured complexity metrics.

Reads:
  - qualtrics_raw.csv          raw Qualtrics export (finished responses only)
  - png_metrics_match*.csv     structural metrics for every code screenshot shown

Writes:
  - output/*.png               all charts
  - tables/*.csv                long-format data + summary tables, for further digging

Run:  python survey_analysis.py
"""

import re
import itertools
import warnings
from pathlib import Path

import numpy as np
import pandas as pd
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import matplotlib.ticker as mticker

BASE = Path(__file__).parent
RAW_CSV = BASE / "qualtrics_raw.csv"
METRICS_CSV = (
    BASE / "png_metrics_match_verified.csv"
    if (BASE / "png_metrics_match_verified.csv").exists()
    else BASE / "png_metrics_match.csv"
)
OUT = BASE / "output"
TABLES = BASE / "tables"
OUT.mkdir(exist_ok=True)
TABLES.mkdir(exist_ok=True)

# --------------------------------------------------------------------------------------
# Palette (validated categorical/diverging set from the dataviz skill's reference palette)
# --------------------------------------------------------------------------------------
CAT = ["#2a78d6", "#eb6834", "#1baf7a", "#eda100", "#e87ba4", "#008300", "#4a3aa7", "#e34948"]
INK, INK2, MUTED = "#0b0b0b", "#52514e", "#898781"
GRID, BASELINE, SURFACE = "#e1e0d9", "#c3c2b7", "#fcfcfb"

# 5-step diverging scale for the "Method A <-> Method B" response axis
RESPONSE_SCALE = {
    "Method A is much less complex": -2,
    "Method A is slightly less complex": -1,
    "No difference": 0,
    "Method B is slightly less complex": 1,
    "Method B is much less complex": 2,
}
RESPONSE_ORDER = [
    "Method A is much less complex",
    "Method A is slightly less complex",
    "No difference",
    "Method B is slightly less complex",
    "Method B is much less complex",
]
RESPONSE_LABELS = ["A much less\ncomplex", "A slightly less\ncomplex", "No difference",
                    "B slightly less\ncomplex", "B much less\ncomplex"]
RESPONSE_COLORS = ["#184f95", "#86b6ef", "#c3c2b7", "#f0a58f", "#d03b3b"]

plt.rcParams.update({
    "figure.facecolor": SURFACE, "axes.facecolor": SURFACE, "savefig.facecolor": SURFACE,
    "text.color": INK, "axes.edgecolor": GRID, "axes.labelcolor": INK,
    "xtick.color": INK2, "ytick.color": INK2,
    "axes.grid": True, "grid.color": GRID, "grid.linewidth": 0.8, "axes.axisbelow": True,
    "font.size": 11, "font.family": "sans-serif",
    "axes.spines.top": False, "axes.spines.right": False,
})

METRIC_COLS = ["CC", "Cognitive", "LOC", "MaxNest", "FanOut", "HalVol", "HalEff", "AvgIdW"]
METRIC_LABELS = {
    "CC": "Cyclomatic Complexity", "Cognitive": "Cognitive Complexity", "LOC": "Lines of Code",
    "MaxNest": "Max Nesting Depth", "FanOut": "Fan-Out", "HalVol": "Halstead Volume",
    "HalEff": "Halstead Effort", "AvgIdW": "Avg Identifier Words",
}

# --------------------------------------------------------------------------------------
# Question -> screenshot group -> code group -> ordered version list.
#
# Block letters (Q1A, Q1B, ...) map onto itertools.combinations(versions, 2) in order;
# this was verified against survey_methods/combinedImages/ file names (e.g. the pair
# "01-ORIG_01-V2.png" is combinations(['ORIG','V2','V3','V4'],2)[0]) and against the
# actual screenshot content for group 01. The first element of each pair is "Method A",
# the second is "Method B", matching how the combined comparison images are laid out.
#
# Q7's 6th pairing block was exported by Qualtrics under raw QIDs (Q126_1/Q127/Q128)
# instead of the "Q7Fi_1" naming pattern; it's renamed below before block-discovery.
#
# Q10 (screenshot group 10 / "balanced") only has 3 blocks in the live survey even
# though 4 versions were screenshotted (C(4,2)=6 possible pairs). Confirmed with the
# survey author: 10-V3 was skipped entirely in the live survey, so the 3 blocks are
# ORIG-V1, ORIG-V2, V1-V2 -- exactly what dropping V3 from the version list below
# produces via itertools.combinations.
# --------------------------------------------------------------------------------------
QUESTION_META = {
    1: {"code_group": "02", "name": "grade", "versions": ["ORIG", "V2", "V3", "V4"]},
    2: {"code_group": "03", "name": "check", "versions": ["ORIG", "V1", "V2", "V3"]},
    3: {"code_group": "05", "name": "sd", "versions": ["ORIG", "V1", "V2"]},
    4: {"code_group": "06", "name": "max", "versions": ["ORIG", "V2"]},
    5: {"code_group": "08", "name": "dedupe", "versions": ["ORIG", "V1", "V2", "V3", "V4"]},
    6: {"code_group": "15", "name": "tally", "versions": ["ORIG", "V1", "V2"]},
    7: {"code_group": "16", "name": "merge", "versions": ["ORIG", "V1", "V2", "V3"]},
    8: {"code_group": "18", "name": "roman", "versions": ["ORIG", "V1", "V2"]},
    9: {"code_group": "19", "name": "bs", "versions": ["ORIG", "V1", "V2"]},
    10: {"code_group": "20", "name": "balanced", "versions": ["ORIG", "V1", "V2"]},
}
QNAME = {q: m["name"] for q, m in QUESTION_META.items()}


def load_metrics():
    mdf = pd.read_csv(METRICS_CSV)

    def parse_primary(val):
        if pd.isna(val):
            return np.nan
        s = str(val).split("/")[0]
        s = re.sub(r"\(.*?\)", "", s).strip()
        try:
            return float(s)
        except ValueError:
            return np.nan

    for c in METRIC_COLS:
        mdf[c] = mdf[c].apply(parse_primary)

    # "code_group"/"version" describe which survey_code.java entry the screenshot's
    # code structurally matches (informational -- see the Notes column for the two
    # rows where this required a correction).
    mdf["code_group"] = mdf["Metrics ID"].str.extract(r"^(\d+)-")
    mdf["version"] = mdf["Metrics ID"].str.extract(r"^\d+-(\S+)")

    # "screenshot_group"/"png_version" are what actually determines which pairing a
    # respondent saw -- derived from the PNG filename itself, never relabelled. This
    # is the correct join key for load_long_responses(): two of the verified rows
    # above were corrected to share a "code_group"/"version" with another row (their
    # code turned out to be identical to that baseline), which would otherwise
    # silently collide in a dict keyed by (code_group, version) and drop that
    # screenshot's metrics entirely.
    mdf["screenshot_group"] = mdf["PNG File"].str.extract(r"^(\d+)-")
    mdf["png_version"] = mdf["PNG File"].str.replace(".png", "", regex=False).str.extract(r"^\d+-(\S+)$")

    lookup = {}
    for _, r in mdf.iterrows():
        lookup[(r["screenshot_group"], r["png_version"])] = {c: r[c] for c in METRIC_COLS}
    return mdf, lookup


def read_raw_csv_robust(path):
    """Qualtrics export; a small number of free-text answers contain an
    unescaped delimiter that throws the field count off for that one row.
    Rather than risk silently misaligning every column after the bad field,
    drop just the offending rows and report how many were dropped."""
    import csv
    with open(path, encoding="utf-8") as f:
        r = csv.reader(f)
        header = next(r)
        good, bad = [], 0
        for row in r:
            if len(row) == len(header):
                good.append(row)
            else:
                bad += 1
    if bad:
        print(f"NOTE: dropped {bad} response row(s) with a malformed field count "
              f"(likely an unescaped delimiter in free text) rather than risk "
              f"misaligned columns.")
    return pd.DataFrame(good, columns=header)


def load_long_responses(metrics_lookup):
    df = read_raw_csv_robust(RAW_CSV)
    df = df[df["Status"] != "Survey Preview"].copy()
    df = df.rename(columns={"Q126_1": "Q7Fi_1", "Q127": "Q7Fii", "Q128": "Q7Fiii"})

    block_cols = {}
    pat = re.compile(r"^Q(\d{1,2})([A-Z])i_1$")
    for c in df.columns:
        m = pat.match(c)
        if m:
            qn, blk = int(m.group(1)), m.group(2)
            block_cols.setdefault(qn, []).append(blk)
    for qn in block_cols:
        block_cols[qn] = sorted(set(block_cols[qn]))

    records = []
    for qn, blocks in block_cols.items():
        if qn not in QUESTION_META:
            continue
        meta = QUESTION_META[qn]
        pairs = list(itertools.combinations(meta["versions"], 2))
        for i, blk in enumerate(blocks):
            if i >= len(pairs):
                warnings.warn(f"Q{qn} block {blk} has no version pair (more blocks than "
                               f"expected combinations) -- skipped")
                continue
            va, vb = pairs[i]
            choice_col, explain_col, why_col = f"Q{qn}{blk}i_1", f"Q{qn}{blk}ii", f"Q{qn}{blk}iii"
            if choice_col not in df.columns:
                continue
            screenshot_group = f"{qn:02d}"
            mA = metrics_lookup.get((screenshot_group, va), {})
            mB = metrics_lookup.get((screenshot_group, vb), {})
            for _, row in df.iterrows():
                choice = row.get(choice_col)
                if pd.isna(choice) or choice not in RESPONSE_SCALE:
                    continue
                rec = {
                    "ResponseId": row["ResponseId"], "Q": qn, "QuestionName": meta["name"],
                    "Block": blk, "VersionA": va, "VersionB": vb,
                    "Choice": choice, "Score": RESPONSE_SCALE[choice],
                    "Explain": row.get(explain_col), "Why": row.get(why_col),
                    "Experience": row.get("Demographic Q2"), "Degree": row.get("Demographic Q1"),
                    "UnverifiedPairing": meta.get("unverified_pairing", False),
                }
                for m in METRIC_COLS:
                    rec[f"{m}_A"] = mA.get(m, np.nan)
                    rec[f"{m}_B"] = mB.get(m, np.nan)
                    rec[f"{m}_delta"] = mB.get(m, np.nan) - mA.get(m, np.nan) if m in mA and m in mB else np.nan
                records.append(rec)

    long_df = pd.DataFrame(records)
    long_df["ActualDir"] = np.sign(long_df["Score"])
    return df, long_df


def savefig(fig, name):
    fig.tight_layout()
    fig.savefig(OUT / name, dpi=150, bbox_inches="tight")
    plt.close(fig)


def group_to_task_name():
    """Maps the PNG screenshot-group number (e.g. "05") to its task name (e.g.
    "dedupe") -- this is just the zero-padded question number, since the
    screenshot directories are named 01..10 matching Q1..Q10."""
    return {f"{q:02d}": m["name"] for q, m in QUESTION_META.items()}


# ============================================================================
# 1. Demographics
# ============================================================================
def chart_demographics(raw):
    degree = raw["Demographic Q1"].dropna()
    degree = degree[~degree.isin([""])]
    counts = degree.value_counts()

    fig, ax = plt.subplots(figsize=(9, 5.5))
    y = np.arange(len(counts))
    ax.barh(y, counts.values, color=CAT[0], height=0.6)
    ax.set_yticks(y)
    ax.set_yticklabels(counts.index, fontsize=9.5)
    ax.invert_yaxis()
    ax.set_xlabel("Respondents")
    ax.set_title("Respondents by degree programme", fontsize=13, loc="left", weight="bold")
    for yi, v in zip(y, counts.values):
        ax.text(v + 0.3, yi, str(v), va="center", fontsize=9, color=INK2)
    ax.margins(x=0.08)
    savefig(fig, "01_demographics_degree.png")

    exp_order = ["None", "Written tiny programs (Up to 100 lines)", "Written small programs (100-500 lines)",
                 "Written medium programs (500-2000 lines)", "Written large programs (2000+ lines)"]
    exp_short = ["None", "Tiny\n(<100 lines)", "Small\n(100-500)", "Medium\n(500-2000)", "Large\n(2000+)"]
    exp = raw["Demographic Q2"].value_counts().reindex(exp_order, fill_value=0)

    fig, ax = plt.subplots(figsize=(7.5, 5))
    ax.bar(exp_short, exp.values, color=CAT[2], width=0.6)
    for i, v in enumerate(exp.values):
        ax.text(i, v + 0.5, str(v), ha="center", fontsize=9, color=INK2)
    ax.set_ylabel("Respondents")
    ax.set_title("Self-rated Java experience\n(by size of programs written)", fontsize=12.5, loc="left", weight="bold")
    savefig(fig, "02_demographics_java_experience.png")


# ============================================================================
# 2. Response distributions (the "which side did people pick" headline charts)
# ============================================================================
def pct_table(sub):
    counts = sub["Choice"].value_counts().reindex(RESPONSE_ORDER, fill_value=0)
    return counts / counts.sum() * 100


def chart_diverging_by_question(long_df):
    qs = sorted(long_df["Q"].unique())
    rows = []
    for q in qs:
        pct = pct_table(long_df[long_df["Q"] == q])
        rows.append(pct.values)
    mat = np.array(rows)  # (n_questions, 5)

    fig, ax = plt.subplots(figsize=(10, 6.5))
    left = np.zeros(len(qs))
    ylabels = [f"Q{q}: {QNAME[q]}" for q in qs]
    y = np.arange(len(qs))
    for i, (lab, col) in enumerate(zip(RESPONSE_LABELS, RESPONSE_COLORS)):
        ax.barh(y, mat[:, i], left=left, color=col, height=0.62,
                label=lab.replace("\n", " "))
        for yi, (v, l) in enumerate(zip(mat[:, i], left)):
            if v > 6:
                txt_color = "white" if col in ("#184f95", "#d03b3b") else INK
                ax.text(l + v / 2, yi, f"{v:.0f}%", ha="center", va="center",
                        fontsize=8.5, color=txt_color)
        left += mat[:, i]
    ax.set_yticks(y)
    ax.set_yticklabels(ylabels, fontsize=10)
    ax.invert_yaxis()
    ax.set_xlabel("Share of responses (%)")
    ax.set_xlim(0, 100)
    ax.set_title("Which method felt less complex? — by question", fontsize=13, loc="left", weight="bold")
    ax.legend(loc="upper center", bbox_to_anchor=(0.5, -0.1), ncol=5, frameon=False, fontsize=8.5)
    savefig(fig, "03_response_distribution_by_question.png")


def chart_diverging_overall(long_df):
    pct = pct_table(long_df)
    fig, ax = plt.subplots(figsize=(10, 3.2))
    left = 0
    for lab, col, v in zip(RESPONSE_LABELS, RESPONSE_COLORS, pct.values):
        ax.barh(0, v, left=left, color=col, height=0.5, label=lab.replace("\n", " "))
        if v > 3:
            txt_color = "white" if col in ("#184f95", "#d03b3b") else INK
            ax.text(left + v / 2, 0, f"{v:.0f}%", ha="center", va="center", fontsize=10, color=txt_color)
        left += v
    ax.set_yticks([])
    ax.set_xlim(0, 100)
    ax.set_xlabel("Share of all responses (%)")
    ax.set_title(f"All {len(long_df):,} pairwise comparisons, combined", fontsize=13, loc="left", weight="bold")
    ax.legend(loc="upper center", bbox_to_anchor=(0.5, -0.5), ncol=3, frameon=False, fontsize=9)
    savefig(fig, "04_response_distribution_overall.png")


def chart_engagement(raw, long_df):
    # Qualtrics randomly routes each respondent to exactly one pairing per
    # question (10 questions -> 10 comparisons/respondent by design), so this
    # distribution has ~zero spread; it's really a completion check.
    per_resp = long_df.groupby("ResponseId").size()
    fig, ax = plt.subplots(figsize=(8, 5))
    counts = per_resp.value_counts().sort_index()
    ax.bar(counts.index.astype(str), counts.values, color=CAT[3], width=0.5)
    ax.bar_label(ax.containers[0], padding=4)
    ax.set_xlabel("Comparisons answered (survey shows 1 per question, 10 questions)")
    ax.set_ylabel("Respondents")
    ax.set_title("Engagement: nearly every respondent completes all 10 assigned comparisons",
                 fontsize=12.5, loc="left", weight="bold")
    savefig(fig, "05_engagement_per_respondent.png")


# ============================================================================
# 3. Metric prediction accuracy (headline research chart)
# ============================================================================
def compute_accuracy(long_df, exclude_unverified=True):
    d = long_df.copy()
    if exclude_unverified:
        d = d[~d["UnverifiedPairing"]]
    out = {}
    for m in METRIC_COLS:
        delta = d[f"{m}_delta"]
        pred_dir = -np.sign(delta)  # metricB - metricA > 0 => B more complex => predict A favoured (negative)
        valid = delta.notna() & d["Score"].notna()
        agree = (pred_dir[valid] == d.loc[valid, "ActualDir"])
        decisive = d.loc[valid, "ActualDir"] != 0  # respondent expressed a preference
        out[m] = {
            "n": int(valid.sum()),
            "accuracy_all": agree.mean() * 100 if valid.sum() else np.nan,
            "accuracy_decisive": agree[decisive].mean() * 100 if decisive.sum() else np.nan,
        }
    return pd.DataFrame(out).T


def chart_prediction_accuracy(long_df):
    acc = compute_accuracy(long_df)
    acc.to_csv(TABLES / "metric_prediction_accuracy.csv")
    acc = acc.sort_values("accuracy_decisive", ascending=True)

    fig, ax = plt.subplots(figsize=(8.5, 5.5))
    y = np.arange(len(acc))
    h = 0.34
    ax.barh(y + h / 2, acc["accuracy_decisive"], color=CAT[0], height=h,
            label="vs. decisive responses (excl. 'no difference')")
    ax.barh(y - h / 2, acc["accuracy_all"], color=CAT[0], alpha=0.45, height=h,
            label="vs. all responses")
    ax.axvline(50, color=MUTED, linewidth=1, linestyle="--")
    ax.text(50, len(acc) - 0.4, " chance", color=MUTED, fontsize=8.5, va="bottom")
    ax.set_yticks(y)
    ax.set_yticklabels([METRIC_LABELS[m] for m in acc.index], fontsize=10)
    ax.set_xlabel("Agreement with participants' choice (%)")
    ax.set_xlim(0, 100)
    ax.set_title("Which complexity metric best predicts perceived complexity?",
                 fontsize=13, loc="left", weight="bold")
    ax.legend(loc="lower right", frameon=False, fontsize=8.5)
    for yi, v in zip(y, acc["accuracy_decisive"]):
        ax.text(v + 1, yi + h / 2, f"{v:.0f}%", va="center", fontsize=8.5, color=INK2)
    for yi, v in zip(y, acc["accuracy_all"]):
        ax.text(v + 1, yi - h / 2, f"{v:.0f}%", va="center", fontsize=8.5, color=INK2)
    savefig(fig, "06_metric_prediction_accuracy.png")


def chart_accuracy_heatmap_by_question(long_df):
    qs = sorted(long_df["Q"].unique())
    mat = np.full((len(METRIC_COLS), len(qs)), np.nan)
    for j, q in enumerate(qs):
        sub = long_df[(long_df["Q"] == q) & (~long_df["UnverifiedPairing"])]
        if sub.empty:
            continue
        acc = compute_accuracy(sub, exclude_unverified=False)
        for i, m in enumerate(METRIC_COLS):
            mat[i, j] = acc.loc[m, "accuracy_decisive"]

    fig, ax = plt.subplots(figsize=(11, 5.5))
    im = ax.imshow(mat, cmap="RdBu_r", vmin=0, vmax=100, aspect="auto")
    ax.set_xticks(range(len(qs)))
    ax.set_xticklabels([f"Q{q}\n{QNAME[q]}" for q in qs], fontsize=8.5)
    ax.set_yticks(range(len(METRIC_COLS)))
    ax.set_yticklabels([METRIC_LABELS[m] for m in METRIC_COLS], fontsize=9.5)
    ax.grid(False)
    for i in range(len(METRIC_COLS)):
        for j in range(len(qs)):
            v = mat[i, j]
            if not np.isnan(v):
                ax.text(j, i, f"{v:.0f}", ha="center", va="center",
                        fontsize=8, color="white" if abs(v - 50) > 25 else INK)
    cbar = fig.colorbar(im, ax=ax, shrink=0.8)
    cbar.set_label("Agreement with decisive responses (%)")
    ax.set_title("Metric prediction accuracy, by question",
                 fontsize=13, loc="left", weight="bold")
    savefig(fig, "07_accuracy_by_question_heatmap.png")


def chart_delta_vs_strength(long_df):
    d = long_df[~long_df["UnverifiedPairing"]].copy()
    d["AbsScore"] = d["Score"].abs().map({0: "No difference", 1: "Slightly", 2: "Much"})
    order = ["No difference", "Slightly", "Much"]

    fig, axes = plt.subplots(1, 2, figsize=(11, 5))
    for ax, m in zip(axes, ["CC", "Cognitive"]):
        data = [d.loc[d["AbsScore"] == cat, f"{m}_delta"].abs().dropna() for cat in order]
        bp = ax.boxplot(data, tick_labels=order, patch_artist=True, widths=0.5, showfliers=False)
        for patch, col in zip(bp["boxes"], [BASELINE, CAT[0], CAT[7]]):
            patch.set_facecolor(col)
            patch.set_alpha(0.75)
        for med in bp["medians"]:
            med.set_color(INK)
        ax.set_title(METRIC_LABELS[m], fontsize=11, loc="left")
        ax.set_ylabel(f"|Δ {m}| between the two methods shown")
        ax.set_xlabel("How strongly the response favoured one side")
    fig.suptitle("Bigger metric gaps -> stronger stated preference?", fontsize=13, x=0.02, ha="left", weight="bold")
    savefig(fig, "08_metric_gap_vs_response_strength.png")


def chart_delta_vs_strength_medians(long_df):
    """Companion to chart 08 -- same data (|delta| by response strength), but
    a two-line median chart with an IQR band instead of box-and-whisker, so
    the CC-flat-vs-Cognitive-rising contrast reads without explaining a box
    plot. Trades away the full spread for legibility; the IQR band keeps the
    'spread widens for Much' detail without box-plot weight."""
    d = long_df[~long_df["UnverifiedPairing"]].copy()
    d["AbsScore"] = d["Score"].abs().map({0: "No difference", 1: "Slightly", 2: "Much"})
    order = ["No difference", "Slightly", "Much"]
    x = np.arange(len(order))

    fig, ax = plt.subplots(figsize=(7.5, 5.8))
    for m, col, marker in zip(["CC", "Cognitive"], [CAT[0], CAT[7]], ["o", "s"]):
        vals = [d.loc[d["AbsScore"] == cat, f"{m}_delta"].abs().dropna() for cat in order]
        median = [v.median() for v in vals]
        q1 = [v.quantile(0.25) for v in vals]
        q3 = [v.quantile(0.75) for v in vals]
        ax.fill_between(x, q1, q3, color=col, alpha=0.15, linewidth=0, zorder=1)
        ax.plot(x, median, color=col, marker=marker, markersize=7, linewidth=2.2,
                label=f"{METRIC_LABELS[m]} (median, IQR band)", zorder=3)
        for xi, v in zip(x, median):
            ax.annotate(f"{v:.1f}", (xi, v), xytext=(0, 8), textcoords="offset points",
                        ha="center", fontsize=8.5, color=col, weight="bold")

    ax.set_xticks(x)
    ax.set_xticklabels(order)
    ax.set_xlabel("How strongly the response favoured one side")
    ax.set_ylabel("|Δ metric| between the two methods shown")
    ax.set_title("Bigger metric gaps -> stronger stated preference?", fontsize=13, loc="left", weight="bold")
    ax.legend(loc="upper left", frameon=False, fontsize=9.5)
    savefig(fig, "36_metric_gap_vs_strength_medians.png")


def chart_cc_cognitive_disagreement(long_df):
    """CC and Cognitive Complexity never actually disagree in *sign* across this
    survey's code pairs (checked directly: 0 opposite-sign cases once ties are
    excluded) -- when they differ it's because CC sees a tie (delta 0, blind to
    control-flow shape) while Cognitive Complexity still detects a difference.
    That's the more interesting comparison, so this chart measures it instead:
    on exactly those tie-for-CC pairs, does Cognitive Complexity's predicted
    side match what participants actually said?"""
    d = long_df[~long_df["UnverifiedPairing"]].copy()
    d = d.dropna(subset=["CC_delta", "Cognitive_delta"])
    d = d[(d["CC_delta"] == 0) & (d["Cognitive_delta"] != 0) & (d["ActualDir"] != 0)]
    cog_dir = -np.sign(d["Cognitive_delta"])
    agree = (cog_dir == d["ActualDir"]).mean() * 100
    n_pairs = d.drop_duplicates(subset=["Q", "VersionA", "VersionB"]).shape[0]

    fig, ax = plt.subplots(figsize=(8.5, 5.2))
    bars = ax.bar(["Cyclomatic Complexity\n(sees a tie)", "Cognitive Complexity\n(sees a difference)"],
                   [50, agree], color=[BASELINE, CAT[6]], width=0.5)
    ax.bar_label(bars, labels=["tie", f"{agree:.0f}%"], padding=4)
    ax.axhline(50, color=MUTED, linewidth=1, linestyle="--")
    ax.set_ylim(0, 100)
    ax.set_ylabel("Agreement with participants' decisive choice (%)")
    ax.set_title(
        f"When CC ties but Cognitive Complexity doesn't ({n_pairs} code pairs, {len(d)} responses)\n"
        f"— does Cognitive Complexity call it right?",
        fontsize=12.5, loc="left", weight="bold")
    savefig(fig, "09_cc_tie_cognitive_breaks_it.png")


# ============================================================================
# 4. Metric overview + experience moderator
# ============================================================================
def chart_metric_distributions(mdf):
    fig, axes = plt.subplots(2, 3, figsize=(13, 7.5))
    for ax, m in zip(axes.flat, ["CC", "Cognitive", "LOC", "MaxNest", "HalVol", "HalEff"]):
        vals = mdf[m].dropna()
        ax.hist(vals, bins=12, color=CAT[0], edgecolor=SURFACE, linewidth=1)
        ax.set_title(METRIC_LABELS[m], fontsize=10.5, loc="left")
        ax.set_ylabel("Code variants")
    fig.suptitle("Distribution of measured complexity across all screenshotted code variants",
                 fontsize=13, x=0.02, ha="left", weight="bold")
    savefig(fig, "10_metric_distributions_overview.png")


def chart_metric_correlation(mdf):
    corr = mdf[METRIC_COLS].corr(numeric_only=True)
    fig, ax = plt.subplots(figsize=(8.5, 6.8))
    im = ax.imshow(corr, cmap="RdBu_r", vmin=-1, vmax=1)
    labels = [METRIC_LABELS[m] for m in corr.columns]
    ax.set_xticks(range(len(labels)))
    ax.set_xticklabels(labels, rotation=45, ha="right", fontsize=9)
    ax.set_yticks(range(len(labels)))
    ax.set_yticklabels(labels, fontsize=9)
    ax.grid(False)
    for i in range(len(labels)):
        for j in range(len(labels)):
            v = corr.values[i, j]
            ax.text(j, i, f"{v:.2f}", ha="center", va="center", fontsize=8,
                    color="white" if abs(v) > 0.6 else INK)
    fig.colorbar(im, ax=ax, shrink=0.8, label="Pearson correlation")
    ax.set_title("How correlated are the complexity metrics\nwith each other?",
                 fontsize=13, loc="left", weight="bold")
    savefig(fig, "11_metric_correlation_matrix.png")


def chart_experience_vs_accuracy(long_df):
    exp_order = ["None", "Written tiny programs (Up to 100 lines)", "Written small programs (100-500 lines)",
                 "Written medium programs (500-2000 lines)", "Written large programs (2000+ lines)"]
    exp_short = {exp_order[0]: "None", exp_order[1]: "Tiny", exp_order[2]: "Small",
                 exp_order[3]: "Medium", exp_order[4]: "Large"}

    d = long_df[~long_df["UnverifiedPairing"]].copy()
    d = d.dropna(subset=["Experience", "CC_delta", "Score"])
    d = d[(d["Score"] != 0) & (d["Experience"].isin(exp_order))]
    pred_dir = -np.sign(d["CC_delta"])
    d["Agree"] = (pred_dir == d["ActualDir"]).astype(int)

    grp = d.groupby("Experience", observed=True)["Agree"].agg(["mean", "count"]).reindex(exp_order).dropna()

    fig, ax = plt.subplots(figsize=(8, 5.2))
    labels = [exp_short[i] for i in grp.index]
    bars = ax.bar(labels, grp["mean"] * 100, color=CAT[4], width=0.55)
    ax.bar_label(bars, fmt="%.0f%%", padding=4)
    for i, (idx, row) in enumerate(grp.iterrows()):
        ax.text(i, 3, f"n={int(row['count'])}", ha="center", fontsize=8.5, color="white")
    ax.set_ylim(0, 100)
    ax.set_ylabel("Agreement with Cyclomatic Complexity's prediction (%)")
    ax.set_xlabel("Self-rated Java experience (size of programs written)")
    ax.set_title("Does experience change how closely judgement tracks CC?",
                 fontsize=13, loc="left", weight="bold")
    savefig(fig, "12_experience_vs_cc_agreement.png")


# ============================================================================
# 5. Deeper metric relationships
# ============================================================================
def chart_delta_vs_strength_all_metrics(long_df):
    d = long_df.copy()
    d["AbsScore"] = d["Score"].abs().map({0: "No difference", 1: "Slightly", 2: "Much"})
    order = ["No difference", "Slightly", "Much"]
    metrics = ["CC", "Cognitive", "LOC", "MaxNest", "HalVol", "HalEff"]

    fig, axes = plt.subplots(2, 3, figsize=(14, 8))
    for ax, m in zip(axes.flat, metrics):
        data = [d.loc[d["AbsScore"] == cat, f"{m}_delta"].abs().dropna() for cat in order]
        bp = ax.boxplot(data, tick_labels=order, patch_artist=True, widths=0.5, showfliers=False)
        for patch, col in zip(bp["boxes"], [BASELINE, CAT[0], CAT[7]]):
            patch.set_facecolor(col)
            patch.set_alpha(0.75)
        for med in bp["medians"]:
            med.set_color(INK)
        ax.set_title(METRIC_LABELS[m], fontsize=10.5, loc="left")
        ax.set_ylabel(f"|Δ {m}|", fontsize=9)
        ax.tick_params(labelsize=8.5)
    fig.suptitle("Metric gap vs. strength of stated preference — all metrics",
                 fontsize=13.5, x=0.02, ha="left", weight="bold")
    savefig(fig, "13_metric_gap_vs_strength_all.png")


def chart_metric_scatter_vs_score(long_df, metric, filename):
    d = long_df.dropna(subset=[f"{metric}_delta", "Score"]).copy()
    rng = np.random.default_rng(7)
    jitter = rng.uniform(-0.15, 0.15, size=len(d))
    fig, ax = plt.subplots(figsize=(8.5, 5.5))
    ax.scatter(d["Score"] + jitter, d[f"{metric}_delta"], s=18, alpha=0.35, color=CAT[0], edgecolors="none")
    ax.axhline(0, color=MUTED, linewidth=1)
    ax.axvline(0, color=MUTED, linewidth=1)
    ax.set_xticks([-2, -1, 0, 1, 2])
    ax.set_xticklabels(["A much\nless complex", "A slightly\nless complex", "No\ndifference",
                         "B slightly\nless complex", "B much\nless complex"], fontsize=8.5)
    ax.set_ylabel(f"Δ {METRIC_LABELS[metric]}  (Method B − Method A)")
    ax.set_title(f"{METRIC_LABELS[metric]} gap vs. what participants actually said",
                 fontsize=12.5, loc="left", weight="bold")
    savefig(fig, filename)


def chart_confusion_matrix(long_df, metric, filename):
    d = long_df.dropna(subset=[f"{metric}_delta", "Choice"]).copy()
    pred_dir = -np.sign(d[f"{metric}_delta"])
    d["Predicted"] = pred_dir.map({-1: "Predicts A", 0: "Predicts tie", 1: "Predicts B"})
    pred_order = ["Predicts A", "Predicts tie", "Predicts B"]

    mat = np.zeros((len(pred_order), len(RESPONSE_ORDER)))
    for i, p in enumerate(pred_order):
        sub = d[d["Predicted"] == p]
        counts = sub["Choice"].value_counts().reindex(RESPONSE_ORDER, fill_value=0)
        row_total = counts.sum()
        mat[i] = (counts / row_total * 100) if row_total else 0

    fig, ax = plt.subplots(figsize=(9.5, 5))
    im = ax.imshow(mat, cmap="Blues", vmin=0, vmax=100, aspect="auto")
    ax.set_xticks(range(len(RESPONSE_ORDER)))
    ax.set_xticklabels([l.replace("\n", " ") for l in RESPONSE_LABELS], fontsize=8.5, rotation=20, ha="right")
    ax.set_yticks(range(len(pred_order)))
    ax.set_yticklabels(pred_order, fontsize=10)
    ax.grid(False)
    for i in range(len(pred_order)):
        for j in range(len(RESPONSE_ORDER)):
            v = mat[i, j]
            ax.text(j, i, f"{v:.0f}%", ha="center", va="center", fontsize=9,
                    color="white" if v > 55 else INK)
    fig.colorbar(im, ax=ax, shrink=0.8, label="Row %")
    ax.set_title(f"What people actually said, given what {METRIC_LABELS[metric]} predicted",
                 fontsize=12, loc="left", weight="bold")
    savefig(fig, filename)


def chart_variant_winrate(long_df):
    d = long_df.dropna(subset=["Score"]).copy()
    d["VariantA"] = d["QuestionName"] + "-" + d["VersionA"]
    d["VariantB"] = d["QuestionName"] + "-" + d["VersionB"]

    tally = {}
    for _, row in d.iterrows():
        a, b, s = row["VariantA"], row["VariantB"], row["Score"]
        for v in (a, b):
            tally.setdefault(v, {"win": 0.0, "total": 0.0, "is_orig": v.endswith("-ORIG")})
        if s < 0:
            tally[a]["win"] += 1
        elif s > 0:
            tally[b]["win"] += 1
        else:
            tally[a]["win"] += 0.5
            tally[b]["win"] += 0.5
        tally[a]["total"] += 1
        tally[b]["total"] += 1

    rows = [{"Variant": k, "WinRate": v["win"] / v["total"] * 100, "n": int(v["total"]), "IsOrig": v["is_orig"]}
            for k, v in tally.items()]
    wr = pd.DataFrame(rows).sort_values("WinRate", ascending=True)
    wr.to_csv(TABLES / "variant_winrate.csv", index=False)

    fig, ax = plt.subplots(figsize=(9, 11))
    y = np.arange(len(wr))
    colors = [CAT[7] if orig else CAT[2] for orig in wr["IsOrig"]]
    ax.barh(y, wr["WinRate"], color=colors, height=0.65)
    ax.set_yticks(y)
    ax.set_yticklabels(wr["Variant"], fontsize=7.5)
    ax.axvline(50, color=MUTED, linewidth=1, linestyle="--")
    ax.set_xlabel("Share of comparisons this variant was judged less complex (%)\n(ties split 50/50)")
    ax.set_title("Every code variant, ranked by how often it 'won' its comparisons",
                 fontsize=13, loc="left", weight="bold")
    handles = [plt.Rectangle((0, 0), 1, 1, color=CAT[7]), plt.Rectangle((0, 0), 1, 1, color=CAT[2])]
    ax.legend(handles, ["Baseline (ORIG)", "Refactored variant"], loc="lower right", frameon=False, fontsize=9)
    savefig(fig, "18_variant_winrate_leaderboard.png")


def chart_baseline_vs_refactor(long_df):
    # ORIG is always first in each versions list, so it only ever appears as
    # "Method A" -- filtering on VersionA == "ORIG" isolates every comparison
    # that pits the original baseline against one of its refactors.
    d = long_df[long_df["VersionA"] == "ORIG"]
    pct = pct_table(d)
    fig, ax = plt.subplots(figsize=(10, 3.2))
    left = 0
    for lab, col, v in zip(RESPONSE_LABELS, RESPONSE_COLORS, pct.values):
        ax.barh(0, v, left=left, color=col, height=0.5, label=lab.replace("\n", " "))
        if v > 3:
            txt_color = "white" if col in ("#184f95", "#d03b3b") else INK
            ax.text(left + v / 2, 0, f"{v:.0f}%", ha="center", va="center", fontsize=10, color=txt_color)
        left += v
    ax.set_yticks([])
    ax.set_xlim(0, 100)
    ax.set_xlabel("Share of responses (%)  |  \"Method A\" is the original baseline in every one of these")
    ax.set_title(f"Baseline vs. its refactored counterpart ({len(d):,} comparisons involving ORIG)",
                 fontsize=12.5, loc="left", weight="bold")
    ax.legend(loc="upper center", bbox_to_anchor=(0.5, -0.5), ncol=3, frameon=False, fontsize=9)
    savefig(fig, "19_baseline_vs_refactor.png")


# ============================================================================
# 6. Comprehension checks & respondent-level patterns
# ============================================================================
def chart_comprehension_pass_rate(raw):
    q1 = raw["Java Q1"].astype(str).str.strip()
    q2 = raw["Java Q2"].astype(str).str.strip()
    q1_total, q2_total = (q1 != "").sum(), (q2 != "").sum()
    q1_correct, q2_correct = (q1 == "C").sum(), (q2 == "2").sum()

    labels = ["Q1: ternary\ngrade(72) -> \"C\"", "Q2: 17 % 5 -> \"2\""]
    rates = [q1_correct / q1_total * 100 if q1_total else 0,
             q2_correct / q2_total * 100 if q2_total else 0]
    ns = [q1_total, q2_total]

    fig, ax = plt.subplots(figsize=(6.5, 5))
    bars = ax.bar(labels, rates, color=CAT[1], width=0.5)
    ax.bar_label(bars, fmt="%.0f%%", padding=4)
    for i, n in enumerate(ns):
        ax.text(i, 3, f"n={n}", ha="center", fontsize=8.5, color="white")
    ax.set_ylim(0, 100)
    ax.set_ylabel("Respondents answering correctly (%)")
    ax.set_title("Comprehension check pass rate", fontsize=13, loc="left", weight="bold")
    savefig(fig, "20_comprehension_check_pass_rate.png")


def chart_comprehension_vs_agreement(raw, long_df):
    comp = raw[["ResponseId", "Java Q1", "Java Q2"]].copy()
    comp["BothCorrect"] = (comp["Java Q1"].astype(str).str.strip() == "C") & \
                          (comp["Java Q2"].astype(str).str.strip() == "2")
    comp["Group"] = comp["BothCorrect"].map({True: "Passed both checks", False: "Missed at least one"})

    d = long_df.dropna(subset=["CC_delta", "Score"]).copy()
    d = d[d["Score"] != 0]
    d = d.merge(comp[["ResponseId", "Group"]], on="ResponseId", how="left")
    pred_dir = -np.sign(d["CC_delta"])
    d["Agree"] = (pred_dir == d["ActualDir"]).astype(int)

    grp = d.dropna(subset=["Group"]).groupby("Group")["Agree"].agg(["mean", "count"])
    grp = grp.reindex(["Missed at least one", "Passed both checks"]).dropna()

    fig, ax = plt.subplots(figsize=(7.5, 5.2))
    bars = ax.bar(grp.index, grp["mean"] * 100, color=CAT[5], width=0.5)
    ax.bar_label(bars, fmt="%.0f%%", padding=4)
    for i, (idx, row) in enumerate(grp.iterrows()):
        ax.text(i, 3, f"n={int(row['count'])}", ha="center", fontsize=8.5, color="white")
    ax.set_ylim(0, 100)
    ax.set_ylabel("Agreement with Cyclomatic Complexity's prediction (%)")
    ax.set_title("Does passing the Java comprehension check change CC agreement?",
                 fontsize=12, loc="left", weight="bold")
    savefig(fig, "21_comprehension_vs_cc_agreement.png")


def chart_agreement_by_degree(long_df):
    d = long_df.dropna(subset=["CC_delta", "Score", "Degree"]).copy()
    d = d[(d["Score"] != 0) & (d["Degree"] != "")]
    pred_dir = -np.sign(d["CC_delta"])
    d["Agree"] = (pred_dir == d["ActualDir"]).astype(int)

    grp = d.groupby("Degree")["Agree"].agg(["mean", "count"])
    grp = grp[grp["count"] >= 15].sort_values("mean", ascending=True)

    fig, ax = plt.subplots(figsize=(9.5, 5.5))
    y = np.arange(len(grp))
    ax.barh(y, grp["mean"] * 100, color=CAT[4], height=0.55)
    ax.set_yticks(y)
    ax.set_yticklabels(grp.index, fontsize=9.5)
    for yi, v, n in zip(y, grp["mean"] * 100, grp["count"]):
        ax.text(v + 1, yi, f"{v:.0f}% (n={int(n)})", va="center", fontsize=8.5, color=INK2)
    ax.set_xlim(0, 100)
    ax.axvline(50, color=MUTED, linewidth=1, linestyle="--")
    ax.set_xlabel("Agreement with Cyclomatic Complexity's prediction (%)")
    ax.set_title("Agreement with CC, by degree programme (n≥15 only)",
                 fontsize=12.5, loc="left", weight="bold")
    savefig(fig, "22_agreement_by_degree.png")


def chart_why_length_vs_strength(long_df):
    d = long_df.copy()
    d["WhyLen"] = d["Why"].fillna("").astype(str).apply(lambda s: len(s.split()))
    d = d[d["WhyLen"] > 0]  # optional field -- only respondents who wrote something
    d["AbsScore"] = d["Score"].abs().map({0: "No difference", 1: "Slightly", 2: "Much"})
    order = ["No difference", "Slightly", "Much"]

    fig, ax = plt.subplots(figsize=(7.5, 5.5))
    data = [d.loc[d["AbsScore"] == cat, "WhyLen"] for cat in order]
    bp = ax.boxplot(data, tick_labels=order, patch_artist=True, widths=0.5, showfliers=False)
    for patch, col in zip(bp["boxes"], [BASELINE, CAT[0], CAT[7]]):
        patch.set_facecolor(col)
        patch.set_alpha(0.75)
    for med in bp["medians"]:
        med.set_color(INK)
    ax.set_ylabel("Words written in \"what made it easier/harder\" (when answered)")
    ax.set_xlabel("How strongly the response favoured one side")
    ax.set_title("Do people write more to justify a stronger opinion?",
                 fontsize=12.5, loc="left", weight="bold")
    savefig(fig, "23_explain_length_vs_strength.png")


def chart_duration_distribution(raw):
    dur = pd.to_numeric(raw["Duration (in seconds)"], errors="coerce").dropna()
    dur = dur[dur > 0]
    fig, ax = plt.subplots(figsize=(8, 5.2))
    bins = np.logspace(np.log10(dur.min()), np.log10(dur.max()), 25)
    ax.hist(dur, bins=bins, color=CAT[3], edgecolor=SURFACE, linewidth=1)
    ax.set_xscale("log")
    ax.set_xlabel("Completion time (seconds, log scale)")
    ax.set_ylabel("Respondents")
    median = dur.median()
    ax.axvline(median, color=MUTED, linewidth=1.2, linestyle="--")
    ax.text(median, ax.get_ylim()[1] * 0.95, f" median = {median:.0f}s", color=INK2, fontsize=9, va="top")
    ax.set_title("How long the survey took to complete", fontsize=13, loc="left", weight="bold")
    savefig(fig, "24_duration_distribution.png")


def chart_respondent_decisiveness(long_df):
    grp = long_df.groupby("ResponseId")["Score"].apply(lambda s: (s == 0).mean() * 100)
    fig, ax = plt.subplots(figsize=(8, 5.2))
    ax.hist(grp, bins=np.arange(0, 105, 10), color=CAT[6], edgecolor=SURFACE, linewidth=1.2)
    ax.set_xlabel("Share of that respondent's answers marked \"No difference\" (%)")
    ax.set_ylabel("Respondents")
    ax.set_title("How often do individual respondents call it a tie?", fontsize=12.5, loc="left", weight="bold")
    savefig(fig, "25_respondent_decisiveness.png")


def chart_metric_spread_by_question(mdf):
    group_to_q = {f"{q:02d}": q for q in QUESTION_META}
    mdf2 = mdf.copy()
    mdf2["Q"] = mdf2["screenshot_group"].map(group_to_q)
    mdf2 = mdf2.dropna(subset=["Q"])
    order = [f"Q{q}\n{QNAME[q]}" for q in sorted(QUESTION_META)]
    mdf2["QLabel"] = mdf2["Q"].astype(int).map(lambda q: f"Q{q}\n{QNAME[q]}")

    fig, axes = plt.subplots(2, 1, figsize=(12, 9))
    for ax, m in zip(axes, ["CC", "LOC"]):
        data = [mdf2.loc[mdf2["QLabel"] == lab, m].dropna() for lab in order]
        bp = ax.boxplot(data, tick_labels=order, patch_artist=True, widths=0.5, showfliers=True)
        for patch in bp["boxes"]:
            patch.set_facecolor(CAT[0])
            patch.set_alpha(0.7)
        for med in bp["medians"]:
            med.set_color(INK)
        ax.set_ylabel(METRIC_LABELS[m])
        ax.tick_params(axis="x", labelsize=8.5)
    fig.suptitle("Spread of measured complexity, by question", fontsize=13.5, x=0.02, ha="left", weight="bold")
    savefig(fig, "26_metric_spread_by_question.png")


# ============================================================================
# 7. Metrics on their own terms -- no survey responses, no A/B, no question number
# ============================================================================
def chart_metric_pairwise_scatters(mdf):
    pairs = [("CC", "Cognitive"), ("CC", "LOC"), ("LOC", "HalVol"),
             ("HalVol", "HalEff"), ("MaxNest", "Cognitive"), ("FanOut", "AvgIdW")]
    fig, axes = plt.subplots(2, 3, figsize=(14, 8.5))
    for ax, (x, y) in zip(axes.flat, pairs):
        d = mdf[[x, y]].dropna()
        ax.scatter(d[x], d[y], s=28, alpha=0.6, color=CAT[0], edgecolors="none")
        if len(d) > 2 and d[x].std() > 0:
            coeffs = np.polyfit(d[x], d[y], 1)
            xs = np.linspace(d[x].min(), d[x].max(), 50)
            ax.plot(xs, np.polyval(coeffs, xs), color=CAT[7], linewidth=1.5)
            r = np.corrcoef(d[x], d[y])[0, 1]
            ax.text(0.05, 0.92, f"r = {r:.2f}", transform=ax.transAxes, fontsize=9.5, color=INK2)
        ax.set_xlabel(METRIC_LABELS[x], fontsize=9)
        ax.set_ylabel(METRIC_LABELS[y], fontsize=9)
    fig.suptitle("How the complexity metrics relate to each other, variant by variant",
                 fontsize=13.5, x=0.02, ha="left", weight="bold")
    savefig(fig, "27_metric_pairwise_scatters.png")


def chart_composite_complexity_ranking(mdf):
    metrics = ["CC", "Cognitive", "LOC", "MaxNest", "HalVol", "HalEff"]
    d = mdf.dropna(subset=metrics).copy()
    z = (d[metrics] - d[metrics].mean()) / d[metrics].std()
    d["CompositeZ"] = z.mean(axis=1)
    d["Task"] = d["screenshot_group"].map(group_to_task_name())
    d["Label"] = d["Task"] + "-" + d["png_version"]  # png_version, not version: two
    # screenshots turned out to be code-identical to another row's baseline (see
    # png_metrics_match_verified.csv notes) and would otherwise print the same label
    d = d.sort_values("CompositeZ")

    fig, ax = plt.subplots(figsize=(9, 11))
    y = np.arange(len(d))
    colors = [CAT[7] if v == "ORIG" else CAT[2] for v in d["version"]]
    ax.barh(y, d["CompositeZ"], color=colors, height=0.65)
    ax.set_yticks(y)
    ax.set_yticklabels(d["Label"], fontsize=7.5)
    ax.axvline(0, color=MUTED, linewidth=1)
    ax.set_xlabel("Composite complexity (mean z-score across CC, Cognitive, LOC, MaxNest, HalVol, HalEff)")
    ax.set_title("Every code variant, ranked by overall measured complexity",
                 fontsize=13, loc="left", weight="bold")
    handles = [plt.Rectangle((0, 0), 1, 1, color=CAT[7]), plt.Rectangle((0, 0), 1, 1, color=CAT[2])]
    ax.legend(handles, ["Baseline (ORIG)", "Refactored variant"], loc="lower right", frameon=False, fontsize=9)
    savefig(fig, "28_composite_complexity_ranking.png")


def chart_orig_vs_refactor_metrics(mdf):
    metrics = ["CC", "Cognitive", "LOC", "MaxNest", "HalVol", "HalEff"]
    d = mdf.copy()
    d["Group"] = np.where(d["version"] == "ORIG", "Baseline", "Refactor")

    fig, axes = plt.subplots(2, 3, figsize=(13, 8))
    for ax, m in zip(axes.flat, metrics):
        data = [d.loc[d["Group"] == g, m].dropna() for g in ["Baseline", "Refactor"]]
        bp = ax.boxplot(data, tick_labels=["Baseline", "Refactor"], patch_artist=True, widths=0.5, showfliers=True)
        for patch, col in zip(bp["boxes"], [CAT[7], CAT[2]]):
            patch.set_facecolor(col)
            patch.set_alpha(0.75)
        for med in bp["medians"]:
            med.set_color(INK)
        ax.set_title(METRIC_LABELS[m], fontsize=10.5, loc="left")
    fig.suptitle("Does refactoring systematically lower each metric?",
                 fontsize=13.5, x=0.02, ha="left", weight="bold")
    savefig(fig, "29_orig_vs_refactor_by_metric.png")


def chart_metric_cv(mdf):
    cv = (mdf[METRIC_COLS].std() / mdf[METRIC_COLS].mean()).abs() * 100
    cv = cv.sort_values(ascending=True)
    fig, ax = plt.subplots(figsize=(8.5, 5.5))
    y = np.arange(len(cv))
    ax.barh(y, cv.values, color=CAT[3], height=0.6)
    ax.set_yticks(y)
    ax.set_yticklabels([METRIC_LABELS[m] for m in cv.index], fontsize=10)
    for yi, v in zip(y, cv.values):
        ax.text(v + 2, yi, f"{v:.0f}%", va="center", fontsize=9, color=INK2)
    ax.set_xlabel("Coefficient of variation (std / mean, %)")
    ax.set_title("Which metric varies most across code variants, relative to its own scale?",
                 fontsize=12.5, loc="left", weight="bold")
    savefig(fig, "30_metric_coefficient_of_variation.png")


def chart_spearman_correlation(mdf):
    corr = mdf[METRIC_COLS].corr(method="spearman", numeric_only=True)
    fig, ax = plt.subplots(figsize=(8.5, 6.8))
    im = ax.imshow(corr, cmap="RdBu_r", vmin=-1, vmax=1)
    labels = [METRIC_LABELS[m] for m in corr.columns]
    ax.set_xticks(range(len(labels)))
    ax.set_xticklabels(labels, rotation=45, ha="right", fontsize=9)
    ax.set_yticks(range(len(labels)))
    ax.set_yticklabels(labels, fontsize=9)
    ax.grid(False)
    for i in range(len(labels)):
        for j in range(len(labels)):
            v = corr.values[i, j]
            ax.text(j, i, f"{v:.2f}", ha="center", va="center", fontsize=8,
                    color="white" if abs(v) > 0.6 else INK)
    fig.colorbar(im, ax=ax, shrink=0.8, label="Spearman correlation")
    ax.set_title("Metric correlations by rank\n(robust to outliers, unlike Pearson)",
                 fontsize=13, loc="left", weight="bold")
    savefig(fig, "31_spearman_correlation_matrix.png")


def _scatter_with_fit(mdf, x, y, xlabel, ylabel, title, filename):
    d = mdf.dropna(subset=[x, y])
    fig, ax = plt.subplots(figsize=(8, 5.5))
    ax.scatter(d[x], d[y], s=30, alpha=0.6, color=CAT[0], edgecolors="none")
    if d[x].std() > 0:
        coeffs = np.polyfit(d[x], d[y], 1)
        xs = np.linspace(d[x].min(), d[x].max(), 50)
        ax.plot(xs, np.polyval(coeffs, xs), color=CAT[7], linewidth=1.5)
        r = np.corrcoef(d[x], d[y])[0, 1]
        ax.text(0.05, 0.92, f"r = {r:.2f}", transform=ax.transAxes, fontsize=10, color=INK2)
    ax.set_xlabel(xlabel)
    ax.set_ylabel(ylabel)
    ax.set_title(title, fontsize=12.5, loc="left", weight="bold")
    savefig(fig, filename)


def chart_pca_dimensions(mdf):
    metrics = ["CC", "Cognitive", "LOC", "MaxNest", "FanOut", "HalVol", "HalEff", "AvgIdW"]
    d = mdf.dropna(subset=metrics).copy()
    X = d[metrics].values
    Xz = (X - X.mean(axis=0)) / X.std(axis=0)
    cov = np.cov(Xz, rowvar=False)
    eigvals, eigvecs = np.linalg.eigh(cov)
    order = np.argsort(eigvals)[::-1]
    eigvals, eigvecs = eigvals[order], eigvecs[:, order]
    scores = Xz @ eigvecs[:, :2]
    var_explained = eigvals / eigvals.sum() * 100

    d["Task"] = d["screenshot_group"].map(group_to_task_name())
    tasks = sorted(d["Task"].unique())
    cmap = plt.get_cmap("tab10")

    fig, ax = plt.subplots(figsize=(9.5, 6.8))
    for i, t in enumerate(tasks):
        mask = (d["Task"] == t).values
        ax.scatter(scores[mask, 0], scores[mask, 1], label=t, s=45, alpha=0.8, color=cmap(i % 10))
    ax.axhline(0, color=MUTED, linewidth=0.8)
    ax.axvline(0, color=MUTED, linewidth=0.8)
    ax.set_xlabel(f"PC1 ({var_explained[0]:.0f}% of variance)")
    ax.set_ylabel(f"PC2 ({var_explained[1]:.0f}% of variance)")
    ax.set_title("Do the 8 complexity metrics measure one thing, or several?",
                 fontsize=12.5, loc="left", weight="bold")
    ax.legend(loc="upper left", bbox_to_anchor=(1.02, 1), frameon=False, fontsize=8.5, title="Task")
    savefig(fig, "33_pca_complexity_dimensions.png")


def chart_cc_vs_cognitive_per_method(mdf):
    """Grouped bars of CC vs. Cognitive Complexity for every refactor variant,
    one small-multiple panel per method/task -- shows how far the two metrics
    diverge on the exact same code, and whether refactoring moves them together
    or pulls them apart."""
    def version_key(v):
        return 0 if v == "ORIG" else int(re.sub(r"\D", "", v) or 0)

    mdf2 = mdf.copy()
    mdf2["Task"] = mdf2["screenshot_group"].map(group_to_task_name())
    mdf2 = mdf2.dropna(subset=["Task", "CC", "Cognitive"])

    tasks = [QNAME[q] for q in sorted(QUESTION_META)]
    fig, axes = plt.subplots(2, 5, figsize=(20, 7.5))
    for ax, task in zip(axes.flat, tasks):
        d = mdf2[mdf2["Task"] == task].copy()
        d = d.sort_values("png_version", key=lambda s: s.map(version_key))
        x = np.arange(len(d))
        w = 0.36
        ax.bar(x - w / 2, d["CC"], width=w, color=CAT[0], label="Cyclomatic Complexity")
        ax.bar(x + w / 2, d["Cognitive"], width=w, color=CAT[1], label="Cognitive Complexity")
        ax.set_xticks(x)
        ax.set_xticklabels(d["png_version"], fontsize=8.5)
        ax.set_title(task, fontsize=11.5, loc="left", weight="bold")
        ax.tick_params(axis="y", labelsize=8)
    for ax in axes.flat[len(tasks):]:
        ax.axis("off")
    handles, labels = axes.flat[0].get_legend_handles_labels()
    fig.legend(handles, labels, loc="lower center", ncol=2, frameon=False, fontsize=10)
    fig.suptitle("Cyclomatic vs. Cognitive Complexity, by method and refactor variant",
                 fontsize=14, x=0.02, ha="left", weight="bold")
    savefig(fig, "35_cc_vs_cognitive_per_method.png")


# ============================================================================
def main():
    mdf, metrics_lookup = load_metrics()
    raw, long_df = load_long_responses(metrics_lookup)

    long_df.to_csv(TABLES / "long_responses.csv", index=False)
    mdf.to_csv(TABLES / "metrics_clean.csv", index=False)

    print(f"Loaded {len(raw)} finished responses, {len(long_df)} pairwise comparisons.")
    print(f"Using metrics file: {METRICS_CSV.name}")

    chart_demographics(raw)
    chart_diverging_by_question(long_df)
    chart_diverging_overall(long_df)
    chart_engagement(raw, long_df)
    chart_prediction_accuracy(long_df)
    chart_accuracy_heatmap_by_question(long_df)
    chart_delta_vs_strength(long_df)
    chart_cc_cognitive_disagreement(long_df)
    chart_metric_distributions(mdf)
    chart_metric_correlation(mdf)
    chart_experience_vs_accuracy(long_df)

    chart_delta_vs_strength_all_metrics(long_df)
    chart_metric_scatter_vs_score(long_df, "CC", "14_cc_delta_vs_score_scatter.png")
    chart_metric_scatter_vs_score(long_df, "Cognitive", "15_cognitive_delta_vs_score_scatter.png")
    chart_confusion_matrix(long_df, "CC", "16_confusion_matrix_cc.png")
    chart_confusion_matrix(long_df, "Cognitive", "17_confusion_matrix_cognitive.png")
    chart_variant_winrate(long_df)
    chart_baseline_vs_refactor(long_df)
    chart_comprehension_pass_rate(raw)
    chart_comprehension_vs_agreement(raw, long_df)
    chart_agreement_by_degree(long_df)
    chart_why_length_vs_strength(long_df)
    chart_duration_distribution(raw)
    chart_respondent_decisiveness(long_df)
    chart_metric_spread_by_question(mdf)

    chart_metric_pairwise_scatters(mdf)
    chart_composite_complexity_ranking(mdf)
    chart_orig_vs_refactor_metrics(mdf)
    chart_metric_cv(mdf)
    chart_spearman_correlation(mdf)
    _scatter_with_fit(mdf, "HalVol", "HalEff", "Halstead Volume", "Halstead Effort",
                       "Halstead Volume vs. Effort — two views of the same size?",
                       "32_halstead_volume_vs_effort.png")
    chart_pca_dimensions(mdf)
    _scatter_with_fit(mdf, "FanOut", "CC", "Fan-Out", "Cyclomatic Complexity",
                       "Fan-Out vs. Cyclomatic Complexity — does calling out to more\nhelpers/library methods track with more branching, or trade off against it?",
                       "34_fanout_vs_cc.png")
    chart_cc_vs_cognitive_per_method(mdf)
    chart_delta_vs_strength_medians(long_df)

    print(f"Wrote {len(list(OUT.glob('*.png')))} charts to {OUT}")
    print(f"Wrote tables to {TABLES}")


if __name__ == "__main__":
    main()
