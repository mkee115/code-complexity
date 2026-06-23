package com.complexity;

import com.github.javaparser.JavaToken;
import com.github.javaparser.ast.body.MethodDeclaration;

import java.util.HashMap;
import java.util.Map;

/**
 * Computes the maximum and average source line length spanned by a method.
 *
 * Line length is derived from the token ranges rather than the raw file, so it
 * is consistent with the other token-based metrics. For each line touched by a
 * non-whitespace token, the effective length is the rightmost column reached by
 * any token on that line (1-based end column), which captures indentation and
 * code width while ignoring trailing whitespace. Comments are included, since a
 * long comment line is still a long line.
 */
public class LineLengthCalculator
{
    public record Metrics(int maxLineLength, double avgLineLength) {}

    public static Metrics compute(MethodDeclaration method)
    {
        if (method.getTokenRange().isEmpty())
            return new Metrics(0, 0.0);

        // line number -> rightmost end column observed on that line
        Map<Integer, Integer> lineWidth = new HashMap<>();

        for (JavaToken token : method.getTokenRange().get())
        {
            JavaToken.Category cat = token.getCategory();
            if (cat == JavaToken.Category.WHITESPACE_NO_EOL || cat == JavaToken.Category.EOL)
                continue;

            token.getRange().ifPresent(r ->
                lineWidth.merge(r.end.line, r.end.column, Math::max));
        }

        if (lineWidth.isEmpty())
            return new Metrics(0, 0.0);

        int max = 0;
        long sum = 0;
        for (int width : lineWidth.values())
        {
            if (width > max) max = width;
            sum += width;
        }

        double avg = (double) sum / lineWidth.size();
        return new Metrics(max, avg);
    }
}
