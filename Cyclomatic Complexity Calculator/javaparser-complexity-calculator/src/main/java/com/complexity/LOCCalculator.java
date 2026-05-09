package com.complexity;

import com.github.javaparser.JavaToken;
import com.github.javaparser.ast.body.MethodDeclaration;

import java.util.HashSet;
import java.util.Set;

public class LOCCalculator
{
    /**
     * Counts non-blank, non-comment lines in a method by iterating over
     * its AST token range and recording the line numbers of any token that
     * is not whitespace, an end-of-line marker, or a comment.
     */
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