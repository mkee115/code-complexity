package com.complexity;

import com.github.javaparser.StaticJavaParser;
import com.github.javaparser.ast.body.MethodDeclaration;
import org.junit.Test;
import static org.junit.Assert.assertEquals;

public class LOCCalculatorTest
{
    /** Builds a properly formatted multi-line method so each body line is on its own line. */
    private static int loc(String... bodyLines)
    {
        StringBuilder sb = new StringBuilder("class T {\n  void m() {\n");
        for (String line : bodyLines)
            sb.append("    ").append(line).append("\n");
        sb.append("  }\n}\n");
        MethodDeclaration method = StaticJavaParser.parse(sb.toString())
                .findFirst(MethodDeclaration.class).get();
        return LOCCalculator.computeLOC(method);
    }

    @Test
    public void emptyBody()
    {
        // method signature line + closing brace = 2
        assertEquals(2, loc());
    }

    @Test
    public void singleStatement()
    {
        // signature + statement + closing brace = 3
        assertEquals(3, loc("int x = 1;"));
    }

    @Test
    public void twoStatements()
    {
        assertEquals(4, loc("int x = 1;", "int y = 2;"));
    }

    @Test
    public void blankLinesNotCounted()
    {
        // blank line between two statements should not count
        assertEquals(4, loc("int x = 1;", "", "int y = 2;"));
    }

    @Test
    public void singleLineCommentNotCounted()
    {
        assertEquals(3, loc("// this is a comment", "int x = 1;"));
    }

    @Test
    public void blockCommentNotCounted()
    {
        assertEquals(3, loc("/* a comment */", "int x = 1;"));
    }

    @Test
    public void codeAndCommentOnSameLine()
    {
        // inline comment: the line still has code tokens, so it counts
        assertEquals(3, loc("int x = 1; // inline comment"));
    }
}
