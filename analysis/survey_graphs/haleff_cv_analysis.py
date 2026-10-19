"""
Ad hoc check: how much of Halstead Effort's coefficient of variation (chart 30)
is driven by the three merge variants that share the largest HalEff values in
the whole dataset (07-ORIG, 07-V1, 07-V3 -- 07-V2 is the one merge variant NOT
excluded, since it's the low-HalEff library-call rewrite)?

Reuses load_metrics from survey_analysis.py. CV = std / mean * 100, computed
across the 35 screenshotted code variants (one row per mdf row), matching
chart_metric_cv exactly.

Run:  python haleff_cv_analysis.py
"""
from survey_analysis import load_metrics

EXCLUDE = [("07", "ORIG"), ("07", "V1"), ("07", "V3")]


def cv(series):
    return series.std() / series.mean() * 100


def main():
    mdf, _ = load_metrics()
    d = mdf.dropna(subset=["HalEff"]).copy()

    mask = d.apply(lambda r: (r["screenshot_group"], r["png_version"]) in EXCLUDE, axis=1)
    excluded_rows = d[mask][["PNG File", "Method", "HalEff"]]
    kept = d[~mask]

    print("Excluded rows:")
    print(excluded_rows.to_string(index=False))

    print(f"\nHalstead Effort coefficient of variation (std / mean * 100):")
    print(f"  All {len(d)} variants                : {cv(d['HalEff']):.1f}%  "
          f"(mean={d['HalEff'].mean():.0f}, std={d['HalEff'].std():.0f})")
    print(f"  Excluding 07-ORIG/V1/V3 ({len(kept)} variants): {cv(kept['HalEff']):.1f}%  "
          f"(mean={kept['HalEff'].mean():.0f}, std={kept['HalEff'].std():.0f})")


if __name__ == "__main__":
    main()
