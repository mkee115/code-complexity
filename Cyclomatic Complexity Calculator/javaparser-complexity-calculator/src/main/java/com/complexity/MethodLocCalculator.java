package com.complexity;

import com.github.javaparser.JavaToken;
import com.github.javaparser.ast.body.MethodDeclaration;

import java.util.HashSet;
import java.util.Set;

public class MethodLocCalculator
{
    public static int computePhysicalLOC(MethodDeclaration method)
    {
        return method.getRange()
                .map(r -> r.end.line - r.begin.line + 1)
                .orElse(0);
    }

    public static int computeLOC(MethodDeclaration method)
    {
        return method.getTokenRange().map(tokenRange ->
        {
            Set<Integer> codeLines = new HashSet<>();

            for (JavaToken token : tokenRange)
            {
                JavaToken.Category category = token.getCategory();

                boolean isNoise = category == JavaToken.Category.COMMENT
                        || category == JavaToken.Category.WHITESPACE_NO_EOL
                        || category == JavaToken.Category.EOL;

                if (!isNoise)
                {
                    token.getRange().ifPresent(r -> codeLines.add(r.begin.line));
                }
            }

            return codeLines.size();

        }).orElse(0);
    }
}
