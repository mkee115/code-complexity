"""
Are Fan-Out and Avg Identifier Words below-chance because their own signal is
bad, or because they're usually just riding along with (and getting outvoted
by) the other six metrics? Isolates code-pairs where each metric's predicted
direction actually diverges from the other six (or where the other six tie
and only this metric distinguishes the pair), then recomputes accuracy_decisive
restricted to just those pairs -- same "tie-breaker" methodology as
chart_cc_cognitive_disagreement (chart 09), generalized to a 6-metric majority
vote instead of a single comparator.

"Other six" = CC, Cognitive, LOC, MaxNest, HalVol, HalEff (i.e. every metric
except Fan-Out and Avg Identifier Words, used as a fixed reference set for
both). Per unique code-pair: sum the signs of the other six metrics' deltas.
  - Case A: that sum's sign is nonzero (a real majority direction) and the
    target metric's sign is nonzero and opposite it -- target actively
    disagrees with where the other six point.
  - Case B: that sum is exactly zero (other six net to a tie/even split) and
    the target metric still distinguishes the pair (nonzero delta).
A pair is "isolated" for a metric if it satisfies A or B.

Run:  python fanout_avgidw_isolation_analysis.py
"""
import numpy as np
import pandas as pd

from survey_analysis import load_metrics, load_long_responses, compute_accuracy, TABLES

OTHER_SIX = ["CC", "Cognitive", "LOC", "MaxNest", "HalVol", "HalEff"]
TARGETS = ["FanOut", "AvgIdW"]


def main():
    mdf, metrics_lookup = load_metrics()
    raw, long_df = load_long_responses(metrics_lookup)
    d = long_df[~long_df["UnverifiedPairing"]].copy()

    pairs = d.drop_duplicates(subset=["Q", "VersionA", "VersionB"]).copy()
    for m in OTHER_SIX + TARGETS:
        pairs[f"{m}_sign"] = np.sign(pairs[f"{m}_delta"])
    pairs["other6_sum"] = pairs[[f"{m}_sign" for m in OTHER_SIX]].sum(axis=1)
    pairs["other6_majority"] = np.sign(pairs["other6_sum"])

    overall = compute_accuracy(d, exclude_unverified=False)
    print("Baseline (all pairs, all questions) accuracy_decisive:")
    for t in TARGETS:
        print(f"  {t:9s}: {overall.loc[t, 'accuracy_decisive']:.1f}%")
    print()

    summary_rows = []
    for target in TARGETS:
        sign = pairs[f"{target}_sign"]
        maj = pairs["other6_majority"]
        case_a = (maj != 0) & (sign != 0) & (sign != maj)
        case_b = (maj == 0) & (sign != 0)
        isolated = case_a | case_b

        iso_pairs = pairs.loc[isolated, ["Q", "QuestionName", "VersionA", "VersionB",
                                          "other6_sum", f"{target}_delta"]].copy()
        iso_pairs["case"] = np.where(case_a[isolated], "A: disagrees w/ majority", "B: other six tied")
        iso_pairs.to_csv(TABLES / f"{target.lower()}_isolated_pairs.csv", index=False)

        iso_keys = pairs.loc[isolated, ["Q", "VersionA", "VersionB"]]
        d_iso = d.merge(iso_keys, on=["Q", "VersionA", "VersionB"], how="inner")
        d_iso_decisive = d_iso[d_iso["ActualDir"] != 0].dropna(subset=[f"{target}_delta"])

        pred_dir = -np.sign(d_iso_decisive[f"{target}_delta"])
        agree = (pred_dir == d_iso_decisive["ActualDir"]).mean() * 100
        n_resp, n_pairs = len(d_iso_decisive), int(isolated.sum())

        print(f"=== {target}: isolated from other six ({n_pairs} unique pairs, {n_resp} decisive responses) ===")
        print(iso_pairs.to_string(index=False))
        print(f"  Accuracy on isolated cases: {agree:.1f}%  "
              f"(baseline overall = {overall.loc[target, 'accuracy_decisive']:.1f}%, chance = 50%)\n")

        summary_rows.append({"metric": target, "n_isolated_pairs": n_pairs, "n_decisive_responses": n_resp,
                              "accuracy_isolated": round(agree, 1),
                              "accuracy_overall_baseline": round(overall.loc[target, "accuracy_decisive"], 1)})

    pd.DataFrame(summary_rows).to_csv(TABLES / "fanout_avgidw_isolation_summary.csv", index=False)
    print(f"Wrote {TABLES / 'fanout_avgidw_isolation_summary.csv'} and per-metric isolated-pairs tables")


if __name__ == "__main__":
    main()
