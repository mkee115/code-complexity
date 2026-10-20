package com.complexity;

import com.github.javaparser.StaticJavaParser;
import com.github.javaparser.ast.body.MethodDeclaration;
import org.junit.Test;
import static org.junit.Assert.assertEquals;

public class MethodNestingCalculatorTest
{
    private static final double DELTA = 0.001;

    private static double[] nesting(String methodBody)
    {
        String src = "class T { void m() { " + methodBody + " } }";
        MethodDeclaration method = StaticJavaParser.parse(src)
                .findFirst(MethodDeclaration.class).get();
        return MethodNestingCalculator.computeNesting(method);
    }

    @Test
    public void emptyBody()
    {
        double[] result = nesting("");
        assertEquals(0.0, result[0], DELTA);
        assertEquals(0.0, result[1], DELTA);
    }

    @Test
    public void flatStatementsAvgAndMaxAreZero()
    {
        double[] result = nesting("int x = 1; int y = 2;");
        assertEquals(0.0, result[0], DELTA);
        assertEquals(0.0, result[1], DELTA);
    }

    @Test
    public void singleIfMaxNesting()
    {
        // if body block sits one level deep
        double[] result = nesting("if (a) {}");
        assertEquals(1.0, result[1], DELTA);
    }

    @Test
    public void nestedIfMaxNesting()
    {
        double[] result = nesting("if (a) { if (b) {} }");
        assertEquals(2.0, result[1], DELTA);
    }

    @Test
    public void tripleNestedMaxNesting()
    {
        double[] result = nesting("if (a) { if (b) { if (c) {} } }");
        assertEquals(3.0, result[1], DELTA);
    }

    @Test
    public void forLoopMaxNesting()
    {
        double[] result = nesting("for (int i=0; i<10; i++) {}");
        assertEquals(1.0, result[1], DELTA);
    }

    @Test
    public void forWithNestedIfMaxNesting()
    {
        double[] result = nesting("for (int i=0; i<10; i++) { if (x) {} }");
        assertEquals(2.0, result[1], DELTA);
    }

    @Test
    public void catchClauseNesting()
    {
        // catch body is one nesting level deep
        double[] result = nesting("try {} catch (Exception e) {}");
        assertEquals(1.0, result[1], DELTA);
    }

    @Test
    public void elseIfChainIsFlat()
    {
        // an else-if chain is one level, however long it is
        double[] result = nesting("if (a) { x(); } else if (b) { x(); } else if (c) { x(); } else { x(); }");
        assertEquals(1.0, result[1], DELTA);
    }

    @Test
    public void ifInsideElseIfIsNested()
    {
        double[] result = nesting("if (a) {} else if (b) { if (c) { x(); } }");
        assertEquals(2.0, result[1], DELTA);
    }

    @Test
    public void ifInsidePlainElseIsNested()
    {
        // else { if } is a real nested if, unlike else if
        double[] result = nesting("if (a) {} else { if (b) { x(); } }");
        assertEquals(2.0, result[1], DELTA);
    }
}
