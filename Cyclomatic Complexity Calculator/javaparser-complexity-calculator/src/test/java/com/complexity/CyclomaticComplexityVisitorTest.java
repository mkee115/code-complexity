package com.complexity;

import com.github.javaparser.StaticJavaParser;
import com.github.javaparser.ast.body.MethodDeclaration;
import org.junit.Test;
import static org.junit.Assert.assertEquals;

public class CyclomaticComplexityVisitorTest
{
    private static int cc(String methodBody)
    {
        String src = "class T { void m() { " + methodBody + " } }";
        MethodDeclaration method = StaticJavaParser.parse(src)
                .findFirst(MethodDeclaration.class).get();
        int[] counter = {1};
        new CyclomaticComplexityVisitor().visit(method, counter);
        return counter[0];
    }

    @Test
    public void emptyMethod()
    {
        // baseline is always 1
        assertEquals(1, cc(""));
    }

    @Test
    public void singleIf()
    {
        assertEquals(2, cc("if (a) {}"));
    }

    @Test
    public void elseDoesNotAdd()
    {
        // else is not a decision point
        assertEquals(2, cc("if (a) {} else {}"));
    }

    @Test
    public void elseIfAdds()
    {
        assertEquals(3, cc("if (a) {} else if (b) {}"));
    }

    @Test
    public void forLoop()
    {
        assertEquals(2, cc("for (int i=0;i<10;i++) {}"));
    }

    @Test
    public void forEachLoop()
    {
        assertEquals(2, cc("for (int x : list) {}"));
    }

    @Test
    public void whileLoop()
    {
        assertEquals(2, cc("while (a) {}"));
    }

    @Test
    public void doWhileLoop()
    {
        assertEquals(2, cc("do {} while (a);"));
    }

    @Test
    public void switchTwoCases()
    {
        // each non-default case label adds 1
        assertEquals(3, cc("switch (x) { case 1: break; case 2: break; }"));
    }

    @Test
    public void switchDefaultNotCounted()
    {
        // default has no label so it does not add
        assertEquals(2, cc("switch (x) { case 1: break; default: break; }"));
    }

    @Test
    public void catchClause()
    {
        assertEquals(2, cc("try {} catch (Exception e) {}"));
    }

    @Test
    public void andOperator()
    {
        // each && adds 1
        assertEquals(3, cc("if (a && b) {}"));
    }

    @Test
    public void orOperator()
    {
        assertEquals(3, cc("if (a || b) {}"));
    }

    @Test
    public void chainedAndOperators()
    {
        // a && b && c: two && operators, each adds 1
        assertEquals(4, cc("if (a && b && c) {}"));
    }

    @Test
    public void ternary()
    {
        assertEquals(2, cc("int x = a ? 1 : 2;"));
    }

    @Test
    public void nestedIf()
    {
        assertEquals(3, cc("if (a) { if (b) {} }"));
    }
}
