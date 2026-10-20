package com.complexity;

import com.github.javaparser.StaticJavaParser;
import com.github.javaparser.ast.body.MethodDeclaration;
import org.junit.Test;
import static org.junit.Assert.assertEquals;

public class MethodStructureCalculatorTest
{
    private static MethodStructureCalculator.Metrics metrics(String methodSrc)
    {
        MethodDeclaration method = StaticJavaParser.parse("class T { " + methodSrc + " }")
                .findFirst(MethodDeclaration.class).get();
        return MethodStructureCalculator.compute(method);
    }

    @Test
    public void parameterCount()
    {
        assertEquals(2, metrics("int m(int a, String b) { return 0; }").paramCount());
    }

    @Test
    public void noParameters()
    {
        assertEquals(0, metrics("void m() {}").paramCount());
    }

    @Test
    public void singleReturn()
    {
        assertEquals(1, metrics("int m() { return 1; }").returnCount());
    }

    @Test
    public void multipleReturns()
    {
        assertEquals(2, metrics("int m(boolean a) { if (a) return 1; return 0; }").returnCount());
    }

    @Test
    public void fanOutDistinctCalls()
    {
        // foo and bar are distinct; foo called twice counts once
        assertEquals(2, metrics("void m() { foo(); bar(); foo(); }").fanOut());
    }

    @Test
    public void fanOutNoCalls()
    {
        assertEquals(0, metrics("int m() { return 1 + 2; }").fanOut());
    }
}
