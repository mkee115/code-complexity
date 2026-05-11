package com.complexity;

import com.github.javaparser.ParserConfiguration;
import com.github.javaparser.StaticJavaParser;
import com.github.javaparser.ast.CompilationUnit;
import com.github.javaparser.ast.body.ClassOrInterfaceDeclaration;
import com.github.javaparser.ast.body.MethodDeclaration;

import org.eclipse.jgit.api.Git;

import java.io.File;
import java.io.FileWriter;
import java.io.PrintWriter;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.stream.Stream;

public class CCCalculator
{
    // "LOCAL_PATH" | "GITHUB_REPO" | "GITHUB_SEARCH"
    private static final String RUN_MODE = "GITHUB_SEARCH";

    // used by LOCAL_PATH: path to a .java file or directory to scan recursively
    private static final String LOCAL_INPUT = "";
    // used by GITHUB_REPO: full clone URL of a single repo
    private static final String SINGLE_REPO_URL = "";

    // GitHub search filters - set to null to omit that filter from the query
    private static final String LANGUAGE = "java";
    private static final Integer MIN_STARS = null;
    private static final Integer MIN_FORKS = null;
    private static final Integer MIN_SIZE_KB = null;   // repo size lower bound
    private static final Integer MAX_SIZE_KB = null;   // repo size upper bound
    private static final String PUSHED_AFTER = null;   // e.g. "2020-01-01"
    private static final Integer MIN_COMMITS = null;

    // max repos to search; actual Maven repos collected will be less due to post-filter
    private static final int TARGET_REPOS = 10000;
    // only include repos created before this date (YYYY-MM-DD); controls chunk planning range
    private static final String CREATED_BEFORE = "2026-01-01";

    // true = add rows to existing CSV files; false = overwrite them from scratch
    private static final boolean APPEND_OUTPUT = false;

    private static final String OUTPUT_DIR = ".\\Cyclomatic Complexity Calculator\\analysis";
    private static final String CC_FILE = OUTPUT_DIR + "\\cc_data.csv";
    private static final String REPOS_FILE = OUTPUT_DIR + "\\repos.csv";
    private static final String SKIPPED_FILE = OUTPUT_DIR + "\\skipped.csv";
    // plain-text file containing a GitHub personal access token (no extra whitespace)
    private static final String TOKEN_FILE = ".\\Cyclomatic Complexity Calculator\\javaparser-complexity-calculator\\.token";

    public static void main(String[] args) throws Exception
    {
        StaticJavaParser.getParserConfiguration().setLanguageLevel(ParserConfiguration.LanguageLevel.JAVA_17);

        File ccFile = new File(CC_FILE);
        File reposFile = new File(REPOS_FILE);
        File skippedFile = new File(SKIPPED_FILE);

        boolean writeCcHeader = !APPEND_OUTPUT || !ccFile.exists() || ccFile.length() == 0;
        boolean writeReposHeader = !APPEND_OUTPUT || !reposFile.exists() || reposFile.length() == 0;
        boolean writeSkippedHeader = !APPEND_OUTPUT || !skippedFile.exists() || skippedFile.length() == 0;

        String scrapedAt = LocalDate.now().toString();

        try (PrintWriter ccOut = new PrintWriter(new FileWriter(ccFile, APPEND_OUTPUT));
             PrintWriter reposOut = new PrintWriter(new FileWriter(reposFile, APPEND_OUTPUT));
             PrintWriter skipOut = new PrintWriter(new FileWriter(skippedFile, APPEND_OUTPUT)))
        {
            if (writeCcHeader)
                ccOut.println("project,class_name,method_name,cc,loc,loc_physical");
            if (writeReposHeader)
                reposOut.println("full_name,url,scraped_at,language,stars,forks,size_kb,commit_count,java_file_count,created_at,pushed_at");
            if (writeSkippedHeader)
                skipOut.println("type,repo,file,method,reason");

            switch (RUN_MODE)
            {
                case "LOCAL_PATH" -> runLocalPath(ccOut, skipOut);
                case "GITHUB_REPO" -> runSingleRepo(ccOut, skipOut);
                case "GITHUB_SEARCH" -> runGitHubSearch(ccOut, reposOut, skipOut, scrapedAt);
                default -> throw new IllegalArgumentException("Unknown RUN_MODE: " + RUN_MODE);
            }
        }

        System.out.println();
        System.out.println("Output files:");
        System.out.println("  CC data:       " + ccFile.getAbsolutePath());
        System.out.println("  Repo metadata: " + reposFile.getAbsolutePath());
        System.out.println("  Skipped log:   " + skippedFile.getAbsolutePath());
    }

    private static void runLocalPath(PrintWriter ccOut, PrintWriter skipOut) throws Exception
    {
        File target = new File(LOCAL_INPUT);
        int[] result = processRepo(target, target.getName(), ccOut, skipOut);
        System.out.printf("Done. Java files: %d, methods written: %d%n", result[0], result[1]);
    }

    private static void runSingleRepo(PrintWriter ccOut, PrintWriter skipOut) throws Exception
    {
        File cloneDir = null;
        try
        {
            System.out.println("Cloning: " + SINGLE_REPO_URL);
            cloneDir = cloneRepo(SINGLE_REPO_URL);
            String repoName = SINGLE_REPO_URL.replaceAll(".*/([^/]+)\\.git$", "$1");
            int[] result = processRepo(cloneDir, repoName, ccOut, skipOut);
            System.out.printf("Done. Java files: %d, methods written: %d%n", result[0], result[1]);
        }
        catch (Exception e)
        {
            System.err.println("Failed to process repo: " + classifyError(e));
        }
        finally
        {
            if (cloneDir != null) deleteRecursively(cloneDir);
        }
    }

    private static void runGitHubSearch(PrintWriter ccOut, PrintWriter reposOut,
                                        PrintWriter skipOut, String scrapedAt) throws Exception
    {
        String token = GitHubSearcher.readToken(Paths.get(TOKEN_FILE));
        GitHubSearcher searcher = new GitHubSearcher(token);

        String baseQuery = buildBaseQuery();
        LocalDate createdBefore = LocalDate.parse(CREATED_BEFORE);
        System.out.println("Planning search chunks for " + TARGET_REPOS + " results"
                + " created on or before " + createdBefore + "...");

        List<GitHubSearcher.SearchChunk> chunks = searcher.planChunks(baseQuery, createdBefore, TARGET_REPOS);

        int grandTotal = chunks.stream().mapToInt(c -> c.expectedCount).sum();
        System.out.println();
        System.out.println("Search parameters: " + baseQuery);
        System.out.println("Total raw results planned: " + grandTotal);
        for (int i = 0; i < chunks.size(); i++)
        {
            GitHubSearcher.SearchChunk c = chunks.get(i);
            System.out.printf("  Chunk %d: %d results between %s and %s%n",
                    i + 1, c.expectedCount, c.startDate, c.endDate);
        }
        System.out.println();

        int mavenProcessed = 0;

        outer:
        for (int i = 0; i < chunks.size(); i++)
        {
            GitHubSearcher.SearchChunk chunk = chunks.get(i);
            String chunkQuery = baseQuery + " " + chunk.dateFilter();

            System.out.printf("Processing chunk %d/%d (%s to %s)...%n",
                    i + 1, chunks.size(), chunk.startDate, chunk.endDate);

            List<GitHubSearcher.Repo> repos = searcher.search(chunkQuery);
            System.out.println("  Retrieved " + repos.size() + " repos in chunk");

            for (GitHubSearcher.Repo repo : repos)
            {
                if (mavenProcessed >= TARGET_REPOS) break outer;

                File cloneDir = null;
                try
                {
                    System.out.printf("[chunk %d/%d | total %d/%d]  %s%n",
                            i + 1, chunks.size(), mavenProcessed, TARGET_REPOS, repo.cloneUrl);

                    cloneDir = cloneRepo(repo.cloneUrl);

                    int[] result = processRepo(cloneDir, repo.fullName, ccOut, skipOut);

                    writeRepoRow(reposOut, repo, scrapedAt, result[0]);
                    ccOut.flush();
                    reposOut.flush();

                    mavenProcessed++;
                }
                catch (Exception e)
                {
                    String reason = classifyError(e);
                    System.err.println("  Skipping repo " + repo.fullName + ": " + reason);
                    logSkip(skipOut, "repo", repo.fullName, "", "", reason);
                }
                finally
                {
                    if (cloneDir != null) deleteRecursively(cloneDir);
                }
            }
        }

        System.out.println();
        System.out.println("Maven repos written to CSV: " + mavenProcessed + " / " + TARGET_REPOS);
    }

    private static String buildBaseQuery()
    {
        StringBuilder q = new StringBuilder();

        if (LANGUAGE != null)
            q.append("language:").append(LANGUAGE).append(" ");
        if (MIN_STARS != null)
            q.append("stars:>=").append(MIN_STARS).append(" ");
        if (MIN_FORKS != null)
            q.append("forks:>=").append(MIN_FORKS).append(" ");
        if (MIN_COMMITS != null)
            q.append("commits:>=").append(MIN_COMMITS).append(" ");
        if (MIN_SIZE_KB != null && MAX_SIZE_KB != null)
            q.append("size:").append(MIN_SIZE_KB).append("..").append(MAX_SIZE_KB).append(" ");
        else if (MIN_SIZE_KB != null)
            q.append("size:>=").append(MIN_SIZE_KB).append(" ");
        else if (MAX_SIZE_KB != null)
            q.append("size:<=").append(MAX_SIZE_KB).append(" ");
        if (PUSHED_AFTER != null)
            q.append("pushed:>=").append(PUSHED_AFTER).append(" ");

        return q.toString().trim();
    }

    private static int[] processRepo(File target, String repoName,
                                     PrintWriter ccOut, PrintWriter skipOut)
    {
        List<File> javaFiles = target.isDirectory() ? findJavaFiles(target) : List.of(target);
        int methodsWritten = 0;

        for (File f : javaFiles)
        {
            try
            {
                methodsWritten += processFile(f, repoName, ccOut, skipOut);
            }
            catch (StackOverflowError e)
            {
                String reason = classifyError(e);
                System.err.println("  Skipping file " + f.getName() + ": " + reason);
                logSkip(skipOut, "file", repoName, f.getName(), "", reason);
            }
            catch (Exception e)
            {
                String reason = classifyError(e);
                System.err.println("  Skipping file " + f.getName() + ": " + reason);
                logSkip(skipOut, "file", repoName, f.getName(), "", reason);
            }
        }

        return new int[]{javaFiles.size(), methodsWritten};
    }

    private static int processFile(File file, String projectName,
                                   PrintWriter out, PrintWriter skipOut) throws Exception
    {
        int count = 0;
        CompilationUnit cu = StaticJavaParser.parse(file);

        for (ClassOrInterfaceDeclaration cls : cu.findAll(ClassOrInterfaceDeclaration.class))
        {
            String className = cls.getNameAsString();
            for (MethodDeclaration method : cls.getMethods())
            {
                String methodName = method.getNameAsString();
                try
                {
                    int cc = computeCC(method);
                    int loc = LOCCalculator.computeLOC(method);
                    int locPhysical = LOCCalculator.computePhysicalLOC(method);
                    out.printf("\"%s\",\"%s\",\"%s\",%d,%d,%d%n",
                            escape(projectName),
                            escape(className),
                            escape(methodName),
                            cc,
                            loc,
                            locPhysical);
                    count++;
                }
                catch (StackOverflowError e)
                {
                    String reason = classifyError(e);
                    logSkip(skipOut, "method", projectName, file.getName(), methodName, reason);
                }
                catch (Exception e)
                {
                    String reason = classifyError(e);
                    logSkip(skipOut, "method", projectName, file.getName(), methodName, reason);
                }
            }
        }
        return count;
    }

    private static int computeCC(MethodDeclaration method)
    {
        int[] counter = {1};
        new CyclomaticComplexityVisitor().visit(method, counter);
        return counter[0];
    }

    private static List<File> findJavaFiles(File dir)
    {
        List<File> results = new ArrayList<>();
        File[] entries = dir.listFiles();
        if (entries == null) return results;

        for (File f : entries)
        {
            if (f.isDirectory())
                results.addAll(findJavaFiles(f));
            else if (f.getName().endsWith(".java"))
                results.add(f);
        }
        return results;
    }

    private static File cloneRepo(String repoUrl) throws Exception
    {
        Path tempDir = Files.createTempDirectory("cc-repo-");

        Git.cloneRepository()
                .setURI(repoUrl)
                .setDirectory(tempDir.toFile())
                .setDepth(1)
                .call()
                .close();

        return tempDir.toFile();
    }

    private static void deleteRecursively(File dir) throws Exception
    {
        if (!dir.exists()) return;
        try (Stream<Path> walk = Files.walk(dir.toPath()))
        {
            walk.sorted(Comparator.reverseOrder())
                    .map(Path::toFile)
                    .forEach(File::delete);
        }
    }

    private static void writeRepoRow(PrintWriter out, GitHubSearcher.Repo r,
                                     String scrapedAt, int javaFileCount)
    {
        out.printf("\"%s\",\"%s\",%s,\"%s\",%d,%d,%d,%d,%d,%s,%s%n",
                escape(r.fullName),
                escape(r.htmlUrl),
                scrapedAt,
                escape(r.language),
                r.stars,
                r.forks,
                r.sizeKb,
                r.commitCount,
                javaFileCount,
                r.createdAt,
                r.pushedAt);
    }

    private static String classifyError(Throwable e)
    {
        if (e instanceof StackOverflowError)
            return "stack overflow (deeply nested AST)";

        String msg = e.getMessage();
        String firstLine = msg != null ? msg.split("\\r?\\n")[0] : null;
        String className = e.getClass().getSimpleName();

        if (msg != null && (msg.contains("source level")
                || msg.contains("not supported")
                || msg.contains("not allowed at")))
            return "unsupported Java feature: " + firstLine;

        if (className.contains("ParseProblem")
                || (firstLine != null && (firstLine.startsWith("(line") || firstLine.contains("Parse error"))))
            return "parse error: " + firstLine;

        return firstLine != null ? firstLine : className;
    }

    private static void logSkip(PrintWriter out, String type, String repo,
                                 String file, String method, String reason)
    {
        out.printf("\"%s\",\"%s\",\"%s\",\"%s\",\"%s\"%n",
                escape(type),
                escape(repo),
                escape(file),
                escape(method),
                escape(reason));
        out.flush();
    }

    private static String escape(String value)
    {
        if (value == null) return "";
        return value.replace("\"", "\"\"");
    }
}
