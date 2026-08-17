package com.complexity;

import com.github.javaparser.StaticJavaParser;
import com.github.javaparser.ast.body.MethodDeclaration;
import org.junit.Test;
import static org.junit.Assert.assertEquals;

public class IdentifierMetricsCalculatorTest
{
    private static final double DELTA = 0.001;

    /**
     * The token range of a MethodDeclaration includes its signature, so the
     * method name 'm' is always present as an identifier in every test.
     */
    private static IdentifierMetricsCalculator.Metrics metrics(String methodBody)
    {
        String src = "class T {\n  void m() {\n    " + methodBody + "\n  }\n}\n";
        MethodDeclaration method = StaticJavaParser.parse(src)
                .findFirst(MethodDeclaration.class).get();
        return IdentifierMetricsCalculator.compute(method);
    }

    @Test
    public void singleLetterCount()
    {
        // method name 'm' + body variable 'x' → 2 single-letter identifiers
        IdentifierMetricsCalculator.Metrics result = metrics("int x = 0;");
        assertEquals(2, result.singleLetterCount());
    }

    @Test
    public void longestIdentifier()
    {
        // 'myLongVariable' is 14 characters
        IdentifierMetricsCalculator.Metrics result = metrics("int myLongVariable = 0;");
        assertEquals(14, result.longestIdentifier());
    }

    @Test
    public void camelCaseAvgWords()
    {
        // 'm' = 1 word, 'myValue' splits into ["my", "Value"] = 2 words → avg = 1.5
        IdentifierMetricsCalculator.Metrics result = metrics("int myValue = 0;");
        assertEquals(1.5, result.avgIdentifierWords(), DELTA);
    }

    @Test
    public void abbreviatedRatioAllShort()
    {
        // 'm' and 'cnt' are both ≤3 chars and not in the common-short-words list
        IdentifierMetricsCalculator.Metrics result = metrics("int cnt = 0;");
        assertEquals(1.0, result.abbreviatedRatio(), DELTA);
    }

    @Test
    public void commonShortWordNotAbbreviated()
    {
        // 'id' is in the common-short-words list so it is not counted as abbreviated
        // only 'm' (method name) is abbreviated → ratio = 1/2
        IdentifierMetricsCalculator.Metrics result = metrics("int id = 0;");
        assertEquals(0.5, result.abbreviatedRatio(), DELTA);
    }

    @Test
    public void commentCountAndWords()
    {
        IdentifierMetricsCalculator.Metrics result = metrics("/* hello world */ int x = 0;");
        assertEquals(1, result.commentCount());
        assertEquals(2, result.commentWordCount());
    }

    @Test
    public void totalWordCount()
    {
        // keywords: void, int → +2
        // identifiers: m (1 word), x (1 word) → +2
        // numeric literal 0 is not a string → no contribution
        IdentifierMetricsCalculator.Metrics result = metrics("int x = 0;");
        assertEquals(4, result.totalWordCount());
    }

    @Test
    public void stringLiteralContributesToWordCount()
    {
        // keywords: void → +1
        // identifiers: m, String, message → +3
        // string literal "hello world" → +2
        IdentifierMetricsCalculator.Metrics result = metrics("String message = \"hello world\";");
        assertEquals(6, result.totalWordCount());
    }
}
