"""
Ad hoc check: does Halstead Effort's overall prediction accuracy depend on
merge (Q7)? Recomputes accuracy_decisive (agreement with participants'
decisive choices, i.e. excluding "no difference" responses) for Halstead
Effort with Q7 excluded, against the all-10-questions figure, and breaks the
per-question numbers out individually.

Reuses load_metrics/load_long_responses/compute_accuracy from survey_analysis.py.

Run:  python haleff_accuracy_analysis.py
"""
import pandas as pd

from survey_analysis import load_metrics, load_long_responses, compute_accuracy, QNAME, TABLES


def main():
    mdf, metrics_lookup = load_metrics()
    raw, long_df = load_long_responses(metrics_lookup)
    d = long_df[~long_df["UnverifiedPairing"]].copy()

    overall = compute_accuracy(d, exclude_unverified=False).loc["HalEff"]
    excl_q7 = compute_accuracy(d[d["Q"] != 7], exclude_unverified=False).loc["HalEff"]

    print("Halstead Effort accuracy_decisive (agreement with decisive responses):")
    print(f"  All 10 questions   : {overall['accuracy_decisive']:.1f}%  (n={int(overall['n'])})")
    print(f"  Excluding Q7 merge : {excl_q7['accuracy_decisive']:.1f}%  (n={int(excl_q7['n'])})")
    print(f"  Difference         : {excl_q7['accuracy_decisive'] - overall['accuracy_decisive']:+.1f} pts")

    rows = []
    for q in sorted(d["Q"].unique()):
        sub = d[d["Q"] == q]
        acc = compute_accuracy(sub, exclude_unverified=False).loc["HalEff"]
        rows.append({"Q": q, "Name": QNAME[q], "n": int(acc["n"]),
                      "accuracy_decisive": round(acc["accuracy_decisive"], 1)})
    per_q = pd.DataFrame(rows).set_index("Q")
    print("\nHalstead Effort accuracy_decisive, by question:")
    print(per_q.to_string())
    per_q.to_csv(TABLES / "haleff_accuracy_by_question.csv")
    print(f"\nWrote {TABLES / 'haleff_accuracy_by_question.csv'}")


if __name__ == "__main__":
    main()
