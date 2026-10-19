package com.complexity;

import com.github.javaparser.JavaParser;
import com.github.javaparser.ParseResult;
import com.github.javaparser.ParserConfiguration;
import com.github.javaparser.ast.CompilationUnit;
import com.github.javaparser.ast.body.MethodDeclaration;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Paths;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Reads a survey code file, splits it into its labelled snippet blocks,
 * wraps each snippet in a throwaway class so JavaParser can parse it,
 * then prints all complexity metrics for every method found.
 *
 * Every block's ID is used exactly as written in the file, and every block is
 * measured; the file should therefore hold only the snippets to be measured.
 * Metrics come from the same calculator classes as the corpus pipeline.
 *
 * Usage: SurveyAnalyser <survey file> [--csv <path>]
 * The CSV has one row per snippet, measuring its main (first) method only.
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

    private record Metrics(int cc, int cognitive, int loc, int maxNest, double avgNest,
                           int fanOut, int params, double halVol, double halEff, double avgIdW,
                           int commentCount, boolean hasJavadoc, boolean recursive) {}

    private record CsvRow(String id, String method, Metrics metrics) {}

    private static final List<CsvRow> CSV_ROWS = new ArrayList<>();

    public static void main(String[] args) throws IOException
    {
        String path = System.getenv().getOrDefault("SURVEY_FILE", "survey_code.java");
        String csvPath = null;
        for (int i = 0; i < args.length; i++)
        {
            if (args[i].equals("--csv") && i + 1 < args.length)
                csvPath = args[++i];
            else
                path = args[i];
        }

        String source = Files.readString(Paths.get(path));

        printHeader();
        for (String block : BANNER_SPLIT.split(source))
        {
            if (!block.isBlank())
                processBlock(block);
        }

        if (csvPath != null)
            writeCsv(csvPath);
    }

    private static void writeCsv(String csvPath) throws IOException
    {
        StringBuilder out = new StringBuilder("group,variant,id,method,cc,cognitive,loc,max_nesting,"
                + "avg_nesting,fan_out,params,hal_vol,hal_eff,avg_id_words,comment_count,"
                + "has_javadoc,recursive\n");
        for (CsvRow row : CSV_ROWS)
        {
            String[] parts = row.id().split("-", 2);
            Metrics m = row.metrics();
            out.append(String.format(Locale.ROOT,
                    "%d,%s,%s,%s,%d,%d,%d,%d,%.2f,%d,%d,%.2f,%.2f,%.2f,%d,%d,%d\n",
                    Integer.parseInt(parts[0]), parts[1], row.id(), row.method(),
                    m.cc(), m.cognitive(), m.loc(), m.maxNest(), m.avgNest(),
                    m.fanOut(), m.params(), m.halVol(), m.halEff(), m.avgIdW(),
                    m.commentCount(), m.hasJavadoc() ? 1 : 0, m.recursive() ? 1 : 0));
        }
        Files.writeString(Paths.get(csvPath), out.toString());
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

        // Wrap in a synthetic class so JavaParser sees a valid compilation unit
        String wrapped = imports + "class _Survey {\n" + body + "}";

        ParseResult<CompilationUnit> parsed = PARSER.parse(wrapped);
        if (parsed.getResult().isEmpty())
        {
            System.err.println("[PARSE FAILED] " + id + ": " + firstProblem(parsed));
            return;
        }

        CompilationUnit cu = parsed.getResult().get();
        List<MethodDeclaration> methods = cu.findAll(MethodDeclaration.class);
        for (MethodDeclaration method : methods)
        {
            Metrics metrics = computeMetrics(method);
            printRow(id, method.getNameAsString(), metrics);
            if (method == methods.get(0))
                CSV_ROWS.add(new CsvRow(id, method.getNameAsString(), metrics));
        }
    }

    private static Metrics computeMetrics(MethodDeclaration method)
    {
        double[] nesting = MethodNestingCalculator.computeNesting(method);
        MethodStructureCalculator.Metrics struct = MethodStructureCalculator.compute(method);
        HalsteadCalculator.Metrics        hal    = HalsteadCalculator.compute(method);
        IdentifierMetricsCalculator.Metrics id_m = IdentifierMetricsCalculator.compute(method);

        return new Metrics(
                CyclomaticComplexityVisitor.compute(method),
                CognitiveComplexityVisitor.compute(method),
                MethodLocCalculator.computeLOC(method),
                (int) nesting[1], nesting[0],
                struct.fanOut(), struct.paramCount(),
                hal.volume(), hal.effort(),
                id_m.avgIdentifierWords(),
                id_m.commentCount(), id_m.hasJavadoc(),
                CognitiveComplexityVisitor.isRecursive(method));
    }

    private static void printRow(String id, String methodName, Metrics m)
    {
        System.out.printf(Locale.ROOT,
                "%-12s %-26s %4d %9d %5d %8d %8.2f %7d %7d %9.1f %9.1f %6.2f %9d %8s %6s%n",
                id, methodName,
                m.cc(), m.cognitive(), m.loc(), m.maxNest(), m.avgNest(),
                m.fanOut(), m.params(),
                m.halVol(), m.halEff(),
                m.avgIdW(),
                m.commentCount(), m.hasJavadoc() ? "yes" : "no", m.recursive() ? "yes" : "no");
    }

    private static void printHeader()
    {
        System.out.printf("%-12s %-26s %4s %9s %5s %8s %8s %7s %7s %9s %9s %6s %9s %8s %6s%n",
                "ID", "Method",
                "CC", "Cognitive", "LOC", "MaxNest", "AvgNest",
                "FanOut", "Params",
                "HalVol", "HalEff",
                "AvgIdW", "Comments", "Javadoc", "Recur");
        System.out.println("-".repeat(146));
    }

    private static String firstProblem(ParseResult<?> parsed)
    {
        return parsed.getProblems().isEmpty()
                ? "unknown parse error"
                : parsed.getProblems().get(0).getMessage().split("\\r?\\n")[0];
    }
}
