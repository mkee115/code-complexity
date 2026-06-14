package com.complexity;

import com.github.javaparser.StaticJavaParser;
import com.github.javaparser.ast.body.MethodDeclaration;
import org.junit.Test;
import static org.junit.Assert.assertEquals;

public class CognitiveComplexityVisitorTest
{
    private static int score(String methodBody)
    {
        String src = "class T { void m() { " + methodBody + " } }";
        MethodDeclaration method = StaticJavaParser.parse(src)
                .findFirst(MethodDeclaration.class).get();
        int[] counter = {0, 0};
        new CognitiveComplexityVisitor().visit(method, counter);
        return counter[0];
    }

    @Test
    public void emptyMethod()
    {
        assertEquals(0, score(""));
    }

    @Test
    public void singleIf()
    {
        // if at nesting=0: +1
        assertEquals(1, score("if (a) {}"));
    }

    @Test
    public void nestedIf()
    {
        // outer if: +1 (nesting=0), inner if: +2 (nesting=1) → 3
        assertEquals(3, score("if (a) { if (b) {} }"));
    }

    @Test
    public void ifElseIfElse()
    {
        // if +1, else-if +1, else +1 → 3  (all at nesting=0, no penalty)
        assertEquals(3, score("if (a) {} else if (b) {} else {}"));
    }

    @Test
    public void forLoop()
    {
        // for at nesting=0: +1
        assertEquals(1, score("for (int i=0;i<10;i++) {}"));
    }

    @Test
    public void ifInsideLoop()
    {
        // for +1 (nesting=0), if +2 (nesting=1) → 3
        assertEquals(3, score("for (int i=0;i<10;i++) { if (x) {} }"));
    }

    @Test
    public void logicalOperatorSameType()
    {
        // a && b && c → one run of && → +1
        assertEquals(1, score("boolean r = a && b && c;"));
    }

    @Test
    public void logicalOperatorMixedTypes()
    {
        // a && b → +1, then || c → +1 → 2
        assertEquals(2, score("boolean r = a && b || c;"));
    }

    @Test
    public void ternaryAtTopLevel()
    {
        // ternary at nesting=0: +1
        assertEquals(1, score("int x = a ? 1 : 2;"));
    }

    @Test
    public void nestedTernary()
    {
        // outer ternary: +1 (nesting=0), inner ternary: +2 (nesting=1 from outer if)
        // Actually ternary inside an if-then: if +1, ternary inside at nesting=1 → +2 → total 3
        assertEquals(3, score("if (a) { int x = b ? 1 : 2; }"));
    }

    @Test
    public void switchStatement()
    {
        // switch counts once (not per case): +1
        assertEquals(1, score("switch (x) { case 1: break; case 2: break; }"));
    }

    @Test
    public void catchClause()
    {
        // catch at nesting=0: +1
        assertEquals(1, score("try {} catch (Exception e) {}"));
    }
}
