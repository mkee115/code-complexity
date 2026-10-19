"""
Targeted follow-up: for specific sd (Q3) pairings, does answering a Java
comprehension check correctly change perceived-complexity ratings or win-rate?

Three checks were given in the survey (Java Q1/Q2/Q3): ternary, modulo (%) and
recursion. `sd` is the only one of the 10 surveyed tasks that uses % or
recursion at all, so it's the only task these checks can plausibly validate
against -- and each check is paired against the specific sd variant-pair that
actually isolates that feature in the code (see survey_code.java's "Isolating:"
comments):
  - ternary   : ORIG vs V2 -- both recursive, only the base-case expression changes
  - recursion : ORIG vs V1 -- ORIG is recursive, V1 is the iterative rewrite
  - modulo (%): ORIG vs V2 -- no sd pair actually isolates %, since all three
                variants use `n % 10`; kept on the same pair as ternary as a
                general Java-competency control rather than an isolating test

Reuses the loaders/style/helpers from survey_analysis.py.

Run:  python sd_comprehension_analysis.py
"""
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

from survey_analysis import (
    load_metrics, load_long_responses,
    CAT, INK, MUTED, OUT, TABLES, savefig,
    RESPONSE_LABELS, RESPONSE_COLORS, pct_table,
)

GROUP_ORDER = ["Correct", "Incorrect"]

CHECKS = [
    {"pair": ("ORIG", "V2"), "col": "Java Q1", "correct": "C",
     "feature": "ternary operator", "slug": "ternary"},
    {"pair": ("ORIG", "V2"), "col": "Java Q2", "correct": "2",
     "feature": "modulo (%)", "slug": "modulo"},
    {"pair": ("ORIG", "V1"), "col": "Java Q3", "correct": "24",
     "feature": "recursion", "slug": "recursion"},
]


def winrate_b(scores):
    # Score > 0 means "Method B is less complex"; ties (Score == 0) split
    # 50/50, matching chart_variant_winrate's convention.
    wins = (scores > 0).sum() + 0.5 * (scores == 0).sum()
    return wins / len(scores) * 100


def run_check(long_df, raw, check):
    va, vb = check["pair"]
    col, correct, feature, slug = check["col"], check["correct"], check["feature"], check["slug"]

    d = long_df[(long_df["QuestionName"] == "sd") &
                (long_df["VersionA"] == va) & (long_df["VersionB"] == vb)].copy()
    assert len(d), f"No sd {va}-{vb} responses found -- check QUESTION_META/block mapping."

    comp = raw[["ResponseId", col]].copy()
    comp[col] = comp[col].astype(str).str.strip()
    n_blank = (comp[col] == "").sum()
    comp = comp[comp[col] != ""]
    comp["Group"] = np.where(comp[col] == correct, "Correct", "Incorrect")

    d = d.merge(comp[["ResponseId", "Group"]], on="ResponseId", how="inner")

    summary = d.groupby("Group").agg(
        n=("Score", "size"), mean_score=("Score", "mean"), winrate_b=("Score", winrate_b),
    ).reindex(GROUP_ORDER).dropna(how="all")
    summary["mean_score"] = summary["mean_score"].round(3)
    summary["winrate_b"] = summary["winrate_b"].round(1)

    print(f"\nsd {va} vs. {vb}, split by {col} ({feature}) -- correct answer '{correct}' "
          f"({len(d)} responses with an answered check, {n_blank} dropped for leaving it blank):")
    print(summary.to_string())
    summary.to_csv(TABLES / f"sd_{va}_v_{vb}_by_{slug}_summary.csv")

    groups = [g for g in GROUP_ORDER if g in summary.index]

    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(13, 4.6), gridspec_kw={"width_ratios": [1.6, 1]})

    mat = np.array([pct_table(d[d["Group"] == g]).values for g in groups])
    left = np.zeros(len(groups))
    y = np.arange(len(groups))
    for i, (lab, col_) in enumerate(zip(RESPONSE_LABELS, RESPONSE_COLORS)):
        ax1.barh(y, mat[:, i], left=left, color=col_, height=0.55, label=lab.replace("\n", " "))
        for yi, (v, l) in enumerate(zip(mat[:, i], left)):
            if v > 6:
                txt_color = "white" if col_ in ("#184f95", "#d03b3b") else INK
                ax1.text(l + v / 2, yi, f"{v:.0f}%", ha="center", va="center", fontsize=8.5, color=txt_color)
        left += mat[:, i]
    ax1.set_yticks(y)
    ax1.set_yticklabels([f"{g} (n={int(summary.loc[g, 'n'])})" for g in groups], fontsize=9.5)
    ax1.invert_yaxis()
    ax1.set_xlim(0, 100)
    ax1.set_xlabel(f"Share of responses (%)  |  \"Method A\" = {va}, \"Method B\" = {vb}")
    ax1.set_title("Response distribution", fontsize=11.5, loc="left", weight="bold")
    ax1.legend(loc="upper center", bbox_to_anchor=(0.5, -0.28), ncol=3, frameon=False, fontsize=8)

    x = np.arange(len(groups))
    bars = ax2.bar(x, summary.loc[groups, "winrate_b"], color=CAT[2], width=0.5)
    ax2.bar_label(bars, fmt="%.0f%%", padding=4)
    ax2.axhline(50, color=MUTED, linewidth=1, linestyle="--")
    ax2.set_xticks(x)
    ax2.set_xticklabels(groups, fontsize=9)
    ax2.set_ylim(0, 100)
    ax2.set_ylabel(f"Share saying {vb} is less complex (%)\n(ties split 50/50)")
    ax2.set_title(f"{vb} win-rate", fontsize=11.5, loc="left", weight="bold")

    fig.suptitle(f"sd, {va} vs. {vb} — does the {feature} check ({col}) change the verdict?",
                 fontsize=13, x=0.02, ha="left", weight="bold")
    savefig(fig, f"sd_{va}_v_{vb}_by_{slug}.png")
    print(f"Wrote {OUT / f'sd_{va}_v_{vb}_by_{slug}.png'}")


def main():
    mdf, metrics_lookup = load_metrics()
    raw, long_df = load_long_responses(metrics_lookup)
    for check in CHECKS:
        run_check(long_df, raw, check)


if __name__ == "__main__":
    main()
