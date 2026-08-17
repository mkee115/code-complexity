package com.complexity;

import com.github.javaparser.StaticJavaParser;
import com.github.javaparser.ast.body.MethodDeclaration;
import org.junit.Test;
import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertTrue;

public class HalsteadCalculatorTest
{
    private static final double DELTA = 1e-6;

    private static HalsteadCalculator.Metrics metrics(String methodSrc)
    {
        MethodDeclaration method = StaticJavaParser.parse("class T { " + methodSrc + " }")
                .findFirst(MethodDeclaration.class).get();
        return HalsteadCalculator.compute(method);
    }

    @Test
    public void baseCounts()
    {
        // void m ( ) { int x = 1 ; }
        // operators: void ( ) { int = ; }   -> 8 total, 8 distinct
        // operands : m x 1                   -> 3 total, 3 distinct
        HalsteadCalculator.Metrics m = metrics("void m() { int x = 1; }");
        assertEquals(8, m.distinctOperators());
        assertEquals(3, m.distinctOperands());
        assertEquals(8, m.totalOperators());
        assertEquals(3, m.totalOperands());
    }

    @Test
    public void volumeMatchesFormula()
    {
        HalsteadCalculator.Metrics m = metrics("void m() { int x = 1; }");
        int vocabulary = m.distinctOperators() + m.distinctOperands();
        int length = m.totalOperators() + m.totalOperands();
        double expectedVolume = length * (Math.log(vocabulary) / Math.log(2));
        assertEquals(expectedVolume, m.volume(), DELTA);
    }

    @Test
    public void difficultyMatchesFormula()
    {
        HalsteadCalculator.Metrics m = metrics("void m() { int x = 1; }");
        double expectedDifficulty =
                ((double) m.distinctOperators() / 2.0)
                * ((double) m.totalOperands() / m.distinctOperands());
        assertEquals(expectedDifficulty, m.difficulty(), DELTA);
    }

    @Test
    public void effortIsDifficultyTimesVolume()
    {
        HalsteadCalculator.Metrics m = metrics("void m(int a) { return a + a + 1; }");
        assertEquals(m.difficulty() * m.volume(), m.effort(), DELTA);
    }

    @Test
    public void repeatedOperandsRaiseTotalNotDistinct()
    {
        // 'a' appears many times: total operands rises but distinct stays bounded
        HalsteadCalculator.Metrics m = metrics("int m(int a) { return a + a + a; }");
        assertTrue(m.totalOperands() > m.distinctOperands());
    }
}
