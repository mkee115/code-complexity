package com.complexity;

/**
 * Maintainability Index (MI) — a composite of Halstead volume, cyclomatic
 * complexity and lines of code.
 *
 * Raw (original Welker/Oman) formula:
 *   MI = 171 - 5.2*ln(V) - 0.23*CC - 16.2*ln(LOC)
 *
 * The raw value is unbounded (and can be negative). The widely-used
 * Visual Studio normalisation rescales it to a 0-100 range:
 *   MI_norm = max(0, MI * 100 / 171)
 *
 * Both are returned so downstream analysis can choose. ln(0) is guarded by
 * substituting a volume/LOC of 1 (ln = 0) when the input is non-positive.
 */
public class MaintainabilityIndexCalculator
{
    public record Metrics(double raw, double normalized) {}

    public static Metrics compute(double halsteadVolume, int cyclomaticComplexity, int loc)
    {
        double safeVolume = halsteadVolume > 0 ? halsteadVolume : 1.0;
        double safeLoc = loc > 0 ? loc : 1.0;

        double raw = 171.0
                - 5.2 * Math.log(safeVolume)
                - 0.23 * cyclomaticComplexity
                - 16.2 * Math.log(safeLoc);

        double normalized = Math.max(0.0, raw * 100.0 / 171.0);

        return new Metrics(raw, normalized);
    }
}
