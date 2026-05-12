package com.complexity;

import com.github.javaparser.JavaToken;
import com.github.javaparser.ast.body.MethodDeclaration;

import java.util.ArrayList;
import java.util.List;
import java.util.Set;
import java.util.regex.Pattern;

public class IdentifierMetricsCalculator
{
    private static final Set<String> COMMON_SHORT_WORDS = Set.of(
        "is", "of", "to", "in", "at", "by", "do", "if", "or", "as",
        "on", "up", "an", "be", "id", "it", "no", "go", "ok", "so", "vs"
    );

    // split on camelCase boundaries and underscores
    private static final Pattern WORD_SPLIT = Pattern.compile(
        "(?<=[a-z])(?=[A-Z])|(?<=[A-Z])(?=[A-Z][a-z])|_+"
    );

    public record Metrics(
        double avgIdentifierWords,
        double abbreviatedRatio,
        int singleLetterCount,
        int longestIdentifier,
        int totalWordCount,
        int commentCount,
        int commentWordCount
    ) {}

    public static Metrics compute(MethodDeclaration method)
    {
        if (method.getTokenRange().isEmpty())
            return new Metrics(0, 0, 0, 0, 0, 0, 0);

        List<Integer> idWordCounts = new ArrayList<>();
        int abbreviatedCount = 0;
        int singleLetterCount = 0;
        int longestIdentifier = 0;
        int totalWordCount = 0;
        int commentCount = 0;
        int commentWordCount = 0;

        for (JavaToken token : method.getTokenRange().get())
        {
            JavaToken.Category cat = token.getCategory();
            String text = token.getText();

            if (cat == JavaToken.Category.IDENTIFIER)
            {
                List<String> words = splitWords(text);
                idWordCounts.add(words.size());
                totalWordCount += words.size();
                if (text.length() == 1) singleLetterCount++;
                if (text.length() > longestIdentifier) longestIdentifier = text.length();
                if (text.length() <= 3 && !COMMON_SHORT_WORDS.contains(text.toLowerCase()))
                    abbreviatedCount++;
            }
            else if (cat == JavaToken.Category.KEYWORD)
            {
                totalWordCount++;
            }
            else if (cat == JavaToken.Category.LITERAL && text.startsWith("\""))
            {
                String inner = text.length() > 2 ? text.substring(1, text.length() - 1) : "";
                for (String part : inner.split("[^a-zA-Z0-9]+"))
                    if (!part.isEmpty()) totalWordCount++;
            }
            else if (cat == JavaToken.Category.COMMENT)
            {
                commentCount++;
                String stripped = stripComment(text);
                for (String w : stripped.split("\\s+"))
                    if (!w.isEmpty()) commentWordCount++;
            }
        }

        double avgWords = idWordCounts.isEmpty() ? 0
            : idWordCounts.stream().mapToInt(i -> i).average().orElse(0);
        double abbrevRatio = idWordCounts.isEmpty() ? 0
            : (double) abbreviatedCount / idWordCounts.size();

        return new Metrics(avgWords, abbrevRatio, singleLetterCount, longestIdentifier,
            totalWordCount, commentCount, commentWordCount);
    }

    private static List<String> splitWords(String identifier)
    {
        String[] parts = WORD_SPLIT.split(identifier);
        List<String> words = new ArrayList<>();
        for (String p : parts)
            if (!p.isEmpty()) words.add(p);
        return words.isEmpty() ? List.of(identifier) : words;
    }

    private static String stripComment(String text)
    {
        return text
            .replaceAll("/\\*+", "")
            .replaceAll("\\*/", "")
            .replaceAll("//+", "")
            .replaceAll("(?m)^[ \t]*\\*[ \t]?", " ")
            .trim();
    }
}
