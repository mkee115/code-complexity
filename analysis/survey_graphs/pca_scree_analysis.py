"""
Full PCA breakdown of the 8 complexity metrics (companion to chart 33, which
only shows PC1/PC2). Prints variance explained by every component and plots
a scree chart, so you can see whether the ~24% left after PC1+PC2 is spread
thinly across PC3-PC8 or concentrated in one further meaningful component.

Same PCA as chart_pca_dimensions in survey_analysis.py: z-score the 8 metrics
across all 35 code variants, eigendecompose the covariance matrix.

Run:  python pca_scree_analysis.py
"""
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

from survey_analysis import load_metrics, CAT, INK, INK2, MUTED, OUT, TABLES, savefig

METRICS = ["CC", "Cognitive", "LOC", "MaxNest", "FanOut", "HalVol", "HalEff", "AvgIdW"]


def main():
    mdf, _ = load_metrics()
    d = mdf.dropna(subset=METRICS).copy()
    X = d[METRICS].values
    Xz = (X - X.mean(axis=0)) / X.std(axis=0)
    cov = np.cov(Xz, rowvar=False)
    eigvals, eigvecs = np.linalg.eigh(cov)
    order = np.argsort(eigvals)[::-1]
    eigvals = eigvals[order]
    var_explained = eigvals / eigvals.sum() * 100
    cum = np.cumsum(var_explained)

    table = pd.DataFrame({
        "PC": [f"PC{i+1}" for i in range(len(eigvals))],
        "eigenvalue": eigvals.round(3),
        "pct_variance": var_explained.round(1),
        "cumulative_pct": cum.round(1),
    }).set_index("PC")
    print(f"PCA on {len(METRICS)} z-scored metrics, {len(d)} code variants:\n")
    print(table.to_string())
    table.to_csv(TABLES / "pca_full_variance_explained.csv")

    fig, ax1 = plt.subplots(figsize=(8.5, 5.5))
    x = np.arange(len(eigvals))
    ax1.bar(x, var_explained, color=CAT[0], width=0.55, label="% variance (this PC)", zorder=2)
    for xi, v in zip(x, var_explained):
        ax1.annotate(f"{v:.0f}%", (xi, v), xytext=(0, 5), textcoords="offset points",
                     ha="center", fontsize=9, color=INK2)

    ax1.plot(x, cum, color=CAT[7], marker="o", markersize=5.5, linewidth=2, label="cumulative %", zorder=3)
    for xi, v in zip(x, cum):
        ax1.annotate(f"{v:.0f}%", (xi, v), xytext=(0, 8), textcoords="offset points",
                     ha="center", fontsize=8.5, color=CAT[7], weight="bold")

    ax1.set_xticks(x)
    ax1.set_xticklabels(table.index, fontsize=10)
    ax1.set_ylabel("% variance explained")
    ax1.set_ylim(0, 112)

    ax1.legend(loc="center right", frameon=False, fontsize=9)

    fig.suptitle("Scree plot: all 8 principal components of the complexity metrics",
                 fontsize=13, x=0.02, ha="left", weight="bold")
    savefig(fig, "pca_scree_plot.png")
    print(f"\nWrote {OUT / 'pca_scree_plot.png'}")


if __name__ == "__main__":
    main()
