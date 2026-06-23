package com.complexity;

import com.github.javaparser.StaticJavaParser;
import com.github.javaparser.ast.body.MethodDeclaration;
import org.junit.Test;
import static org.junit.Assert.assertTrue;

public class LineLengthCalculatorTest
{
    private static LineLengthCalculator.Metrics metrics(String classSrc)
    {
        MethodDeclaration method = StaticJavaParser.parse(classSrc)
                .findFirst(MethodDeclaration.class).get();
        return LineLengthCalculator.compute(method);
    }

    @Test
    public void nonEmptyMethodHasPositiveLengths()
    {
        LineLengthCalculator.Metrics m = metrics("class T {\n  void m() {\n    int x = 1;\n  }\n}\n");
        assertTrue(m.maxLineLength() > 0);
        assertTrue(m.avgLineLength() > 0);
    }

    @Test
    public void maxIsAtLeastAverage()
    {
        LineLengthCalculator.Metrics m = metrics(
            "class T {\n  void m() {\n    int x = 1;\n    int yy = 22;\n  }\n}\n");
        assertTrue(m.maxLineLength() >= m.avgLineLength());
    }

    @Test
    public void longerLineProducesLargerMax()
    {
        LineLengthCalculator.Metrics shortM = metrics(
            "class T {\n  void m() {\n    int x = 1;\n  }\n}\n");
        LineLengthCalculator.Metrics longM = metrics(
            "class T {\n  void m() {\n    int aLongVariableName = anotherFairlyLongName + 12345;\n  }\n}\n");
        assertTrue(longM.maxLineLength() > shortM.maxLineLength());
    }
}
