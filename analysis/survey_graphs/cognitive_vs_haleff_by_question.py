"""
Per-question accuracy_decisive, Cognitive Complexity vs. Halstead Effort --
the evidence behind the "HalEff's overall edge is really just one question"
finding: the two metrics produce identical predictions on 9 of 10 tasks, and
the entire gap comes from sd (Q3), where Cognitive ties on the ORIG-vs-V2
pair (deliberately built to hold cognitive complexity constant) and eats an
automatic miss on every decisive response to that pair, while HalEff -- being
continuous -- essentially never ties and always gets to guess.

Run:  python cognitive_vs_haleff_by_question.py
"""
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

from survey_analysis import load_metrics, load_long_responses, compute_accuracy, QNAME, CAT, INK, INK2, MUTED, OUT, TABLES, savefig


def main():
    mdf, metrics_lookup = load_metrics()
    raw, long_df = load_long_responses(metrics_lookup)
    d = long_df[~long_df["UnverifiedPairing"]].copy()

    rows = []
    for q in sorted(d["Q"].unique()):
        sub = d[d["Q"] == q]
        acc = compute_accuracy(sub, exclude_unverified=False)
        decisive = sub[sub["ActualDir"] != 0]
        rows.append({
            "Q": q, "Name": QNAME[q],
            "Cognitive": round(acc.loc["Cognitive", "accuracy_decisive"], 1),
            "HalEff": round(acc.loc["HalEff", "accuracy_decisive"], 1),
            "Cognitive_tie_rate": round((decisive["Cognitive_delta"] == 0).mean() * 100, 1),
            "HalEff_tie_rate": round((decisive["HalEff_delta"] == 0).mean() * 100, 1),
        })
    import pandas as pd
    per_q = pd.DataFrame(rows).set_index("Q")
    per_q["Cognitive_minus_HalEff"] = (per_q["Cognitive"] - per_q["HalEff"]).round(1)
    print(per_q.to_string())
    per_q.to_csv(TABLES / "cognitive_vs_haleff_by_question.csv")
    print(f"\nWrote {TABLES / 'cognitive_vs_haleff_by_question.csv'}")

    # --- chart ---
    labels = [f"{QNAME[q]}" for q in per_q.index]
    x = np.arange(len(per_q))
    w = 0.36

    fig, ax = plt.subplots(figsize=(12, 6))
    bars_cog = ax.bar(x - w / 2, per_q["Cognitive"], width=w, color=CAT[7], label="Cognitive Complexity")
    bars_hal = ax.bar(x + w / 2, per_q["HalEff"], width=w, color=CAT[0], label="Halstead Effort")
    ax.bar_label(bars_cog, fmt="%.0f%%", padding=3, fontsize=8.5)
    ax.bar_label(bars_hal, fmt="%.0f%%", padding=3, fontsize=8.5)

    ax.axhline(50, color=MUTED, linewidth=1, linestyle="--")
    ax.text(len(per_q) - 0.5, 51.5, "chance", color=MUTED, fontsize=8.5, ha="right")

    ax.set_xticks(x)
    ax.set_xticklabels(labels, fontsize=10)
    ax.set_ylim(0, 100)
    ax.set_ylabel("Agreement with participants' decisive choice (%)")
    ax.set_title("Cognitive Complexity vs. Halstead Effort, by question",
                 fontsize=13.5, loc="left", weight="bold")
    ax.legend(loc="upper left", frameon=False, fontsize=10)

    # Annotate the one question where they diverge, with the tie-rate explanation
    sd_q = 3
    sd_idx = list(per_q.index).index(sd_q)
    cog_v, hal_v = per_q.loc[sd_q, "Cognitive"], per_q.loc[sd_q, "HalEff"]
    cog_tie, hal_tie = per_q.loc[sd_q, "Cognitive_tie_rate"], per_q.loc[sd_q, "HalEff_tie_rate"]
    ax.annotate(
        f"sd is the only question where they differ.\n"
        f"Cognitive ties on {cog_tie:.0f}% of its decisive\n"
        f"responses here (an automatic miss each time) --\n"
        f"HalEff, being continuous, ties on {hal_tie:.0f}%.",
        xy=(sd_idx, max(cog_v, hal_v) + 3), xytext=(sd_idx + 1.3, 78),
        fontsize=9, color=INK2, ha="left",
        arrowprops=dict(arrowstyle="->", color=INK2, linewidth=1),
        bbox=dict(boxstyle="round,pad=0.4", facecolor="white", edgecolor=MUTED, linewidth=0.8),
    )
    ax.annotate("all 9 other questions: identical predictions\n(0.0pt difference, bar heights match exactly)",
                xy=(6, 15), fontsize=9, color=INK2, ha="center", style="italic")

    savefig(fig, "cognitive_vs_haleff_by_question.png")
    print(f"Wrote {OUT / 'cognitive_vs_haleff_by_question.png'}")


if __name__ == "__main__":
    main()
