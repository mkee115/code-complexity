package com.complexity;

import org.junit.Test;
import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertTrue;

public class MaintainabilityIndexCalculatorTest
{
    private static final double DELTA = 1e-6;

    @Test
    public void rawMatchesFormula()
    {
        double volume = 100.0;
        int cc = 5;
        int loc = 20;
        double expected = 171.0
                - 5.2 * Math.log(volume)
                - 0.23 * cc
                - 16.2 * Math.log(loc);
        assertEquals(expected, MaintainabilityIndexCalculator.compute(volume, cc, loc).raw(), DELTA);
    }

    @Test
    public void normalizedIsRawRescaled()
    {
        MaintainabilityIndexCalculator.Metrics m = MaintainabilityIndexCalculator.compute(100.0, 5, 20);
        assertEquals(Math.max(0.0, m.raw() * 100.0 / 171.0), m.normalized(), DELTA);
    }

    @Test
    public void normalizedNeverNegative()
    {
        // huge volume/CC/LOC drives raw MI well below zero; normalized clamps to 0
        MaintainabilityIndexCalculator.Metrics m = MaintainabilityIndexCalculator.compute(1_000_000.0, 200, 5000);
        assertTrue(m.raw() < 0);
        assertEquals(0.0, m.normalized(), DELTA);
    }

    @Test
    public void zeroInputsGuardedAgainstLogOfZero()
    {
        // volume=0 and loc=0 must not produce NaN/Infinity (ln guarded to ln(1)=0)
        MaintainabilityIndexCalculator.Metrics m = MaintainabilityIndexCalculator.compute(0, 0, 0);
        assertEquals(171.0, m.raw(), DELTA);
    }
}
