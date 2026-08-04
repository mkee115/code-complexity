package com.complexity;

import com.github.javaparser.JavaParser;
import com.github.javaparser.ParseResult;
import com.github.javaparser.ParserConfiguration;
import com.github.javaparser.ast.CompilationUnit;
import com.github.javaparser.ast.body.MethodDeclaration;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.Locale;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Reads survey_code.java, splits it into its labelled method blocks,
 * wraps each snippet in a throwaway class so JavaParser can parse it,
 * then prints all complexity metrics for every method found.
 *
 * Usage: pass the path to survey_code.java as the first argument, or
 * set the SURVEY_FILE environment variable; defaults to "survey_code.java"
 * in the working directory.
 */
public class SurveyAnalyser
{
    private static final JavaParser PARSER = new JavaParser(
            new ParserConfiguration()
                    .setLanguageLevel(ParserConfiguration.LanguageLevel.BLEEDING_EDGE)
                    .setStoreTokens(true));

    // Matches the " * ID: XX-YYYY" line inside a banner comment
    private static final Pattern ID_PAT = Pattern.compile("\\*\\s+ID:\\s+(\\S+)");

    // Split point: just before every banner comment ( /* ----... )
    private static final Pattern BANNER_SPLIT = Pattern.compile("(?=/\\* -{10,})");

    public static void main(String[] args) throws IOException
    {
        String path = args.length > 0 ? args[0]
                : System.getenv().getOrDefault("SURVEY_FILE", "survey_code.java");

        String source = Files.readString(Paths.get(path));

        printHeader();
        for (String block : BANNER_SPLIT.split(source))
        {
            if (!block.isBlank())
                processBlock(block);
        }
    }

    // -------------------------------------------------------------------------

    private static void processBlock(String block)
    {
        Matcher m = ID_PAT.matcher(block);
        if (!m.find()) return;
        String id = m.group(1);

        // Remove the leading banner comment, leaving only the Java code
        String code = block.replaceFirst("(?s)/\\*.*?\\*/\\s*", "");

        // Import statements must sit outside the wrapping class
        StringBuilder imports = new StringBuilder();
        StringBuilder body    = new StringBuilder();
        for (String line : code.split("\n", -1))
        {
            if (line.stripLeading().startsWith("import "))
                imports.append(line).append("\n");
            else
                body.append(line).append("\n");
        }

        // Wrap in a synthetic class so JavaParser sees a valid compilation unit.
        // Inner-class declarations (e.g. "class Account { double balance; }") and
        // static field declarations (constants blocks) are valid class members.
        String wrapped = imports + "class _Survey {\n" + body + "}";

        ParseResult<CompilationUnit> parsed = PARSER.parse(wrapped);
        if (parsed.getResult().isEmpty())
        {
            System.err.println("[PARSE FAILED] " + id + ": " + firstProblem(parsed));
            return;
        }

        CompilationUnit cu = parsed.getResult().get();
        for (MethodDeclaration method : cu.findAll(MethodDeclaration.class))
            printRow(id, method.getNameAsString(), method);
    }

    private static void printRow(String id, String methodName, MethodDeclaration method)
    {
        int cc        = CyclomaticComplexityVisitor.compute(method);
        int cognitive = CognitiveComplexityVisitor.compute(method);
        int loc       = MethodLocCalculator.computeLOC(method);
        int maxNest   = (int) MethodNestingCalculator.computeNesting(method)[1];

        MethodStructureCalculator.Metrics struct = MethodStructureCalculator.compute(method);
        HalsteadCalculator.Metrics        hal    = HalsteadCalculator.compute(method);
        IdentifierMetricsCalculator.Metrics id_m = IdentifierMetricsCalculator.compute(method);

        System.out.printf(Locale.ROOT,
                "%-12s %-26s %4d %9d %5d %8d %7d %7d %9.1f %9.1f %6.2f%n",
                id, methodName,
                cc, cognitive, loc, maxNest,
                struct.fanOut(), struct.paramCount(),
                hal.volume(), hal.effort(),
                id_m.avgIdentifierWords());
    }

    private static void printHeader()
    {
        System.out.printf("%-12s %-26s %4s %9s %5s %8s %7s %7s %9s %9s %6s%n",
                "ID", "Method",
                "CC", "Cognitive", "LOC", "MaxNest",
                "FanOut", "Params",
                "HalVol", "HalEff",
                "AvgIdW");
        System.out.println("-".repeat(110));
    }

    private static String firstProblem(ParseResult<?> parsed)
    {
        return parsed.getProblems().isEmpty()
                ? "unknown parse error"
                : parsed.getProblems().get(0).getMessage().split("\\r?\\n")[0];
    }
}
