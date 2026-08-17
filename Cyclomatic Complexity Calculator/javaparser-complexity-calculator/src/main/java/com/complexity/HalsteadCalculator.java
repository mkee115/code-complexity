package com.complexity;

import com.github.javaparser.JavaToken;
import com.github.javaparser.ast.body.MethodDeclaration;

import java.util.HashSet;
import java.util.Set;

/**
 * Computes Halstead complexity measures for a method from its token stream.
 *
 * Operationalisation for Java (a common, defensible convention):
 *   operands  = identifiers and literals
 *   operators = keywords, operators, and separators (punctuation)
 *
 * From the four base counts:
 *   n1 = distinct operators,  n2 = distinct operands
 *   N1 = total operators,     N2 = total operands
 * the derived measures are:
 *   vocabulary n = n1 + n2
 *   length     N = N1 + N2
 *   volume     V = N * log2(n)
 *   difficulty D = (n1 / 2) * (N2 / n2)
 *   effort     E = D * V
 */
public class HalsteadCalculator
{
    public record Metrics(
        int distinctOperators,
        int distinctOperands,
        int totalOperators,
        int totalOperands,
        double volume,
        double difficulty,
        double effort
    ) {}

    public static Metrics compute(MethodDeclaration method)
    {
        if (method.getTokenRange().isEmpty())
            return new Metrics(0, 0, 0, 0, 0, 0, 0);

        Set<String> operators = new HashSet<>();
        Set<String> operands = new HashSet<>();
        int totalOperators = 0;
        int totalOperands = 0;

        for (JavaToken token : method.getTokenRange().get())
        {
            JavaToken.Category cat = token.getCategory();
            String text = token.getText();

            switch (cat)
            {
                case IDENTIFIER, LITERAL ->
                {
                    operands.add(text);
                    totalOperands++;
                }
                case KEYWORD, OPERATOR, SEPARATOR ->
                {
                    operators.add(text);
                    totalOperators++;
                }
                default -> { /* whitespace, EOL, comments: ignored */ }
            }
        }

        int n1 = operators.size();
        int n2 = operands.size();
        int vocabulary = n1 + n2;
        int length = totalOperators + totalOperands;

        double volume = vocabulary > 0 ? length * (Math.log(vocabulary) / Math.log(2)) : 0.0;
        double difficulty = n2 > 0 ? ((double) n1 / 2.0) * ((double) totalOperands / n2) : 0.0;
        double effort = difficulty * volume;

        return new Metrics(n1, n2, totalOperators, totalOperands, volume, difficulty, effort);
    }
}
