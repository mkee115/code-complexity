package com.complexity;

import com.github.javaparser.JavaParser;
import com.github.javaparser.ParseResult;
import com.github.javaparser.ParserConfiguration;
import com.github.javaparser.ast.CompilationUnit;
import com.github.javaparser.ast.body.MethodDeclaration;
import com.github.javaparser.ast.body.TypeDeclaration;

import org.eclipse.jgit.api.Git;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileWriter;
import java.io.IOException;
import java.io.PrintWriter;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Locale;
import java.util.Optional;
import java.util.Set;
import java.util.concurrent.Callable;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.ThreadFactory;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.stream.Stream;

public class ComplexityCalculator
{
    static final String CC_HEADER =
            "project,class_name,method_name,cc,cognitive_complexity,loc,loc_physical,"
            + "avg_nesting,max_nesting,avg_id_words,abbreviated_ratio,single_letter_ids,"
            + "longest_id,total_words,comment_count,comment_words,"
            + "halstead_volume,halstead_difficulty,halstead_effort,"
            + "maintainability_index,mi_normalized,param_count,return_count,fan_out,"
            + "max_line_length,avg_line_length";

    static final String REPOS_HEADER =
            "full_name,url,scraped_at,language,stars,forks,size_kb,commit_count,"
            + "java_file_count,created_at,pushed_at";

    static final String SKIPPED_HEADER = "type,repo,file,method,reason";

    // One JavaParser per thread: JavaParser instances are not thread-safe, and
    // sharing the global StaticJavaParser across workers would corrupt parses.
    // BLEEDING_EDGE accepts the widest syntax range (newest Java features as well
    // as older code), minimising parse failures; tokens are stored because the
    // metrics read from the token stream.
    private static final ThreadLocal<JavaParser> PARSER = ThreadLocal.withInitial(() ->
            new JavaParser(new ParserConfiguration()
                    .setLanguageLevel(ParserConfiguration.LanguageLevel.BLEEDING_EDGE)
                    .setStoreTokens(true)));

    // Deeply nested ASTs blow the default thread stack during parsing/traversal.
    // Running the work on threads with a large stack lets those methods compute
    // instead of being skipped with a StackOverflowError.
    private static final long WORKER_STACK_BYTES = 64L * 1024 * 1024;
    private static final ThreadFactory BIG_STACK_FACTORY = new ThreadFactory()
    {
        private final AtomicInteger n = new AtomicInteger();

        @Override
        public Thread newThread(Runnable r)
        {
            Thread t = new Thread(null, r, "cc-worker-" + n.incrementAndGet(), WORKER_STACK_BYTES);
            t.setDaemon(true);
            return t;
        }
    };

    public static void main(String[] args) throws Exception
    {
        Config cfg = Config.load(args.length > 0 ? args[0] : null);

        new File(cfg.outputDir).mkdirs();

        File ccFile = new File(cfg.outputDir, "cc_data.csv");
        File reposFile = new File(cfg.outputDir, "repos.csv");
        File skippedFile = new File(cfg.outputDir, "skipped.csv");

        boolean writeCcHeader = headerNeeded(cfg, ccFile);
        boolean writeReposHeader = headerNeeded(cfg, reposFile);
        boolean writeSkippedHeader = headerNeeded(cfg, skippedFile);

        String scrapedAt = LocalDate.now().toString();

        try (CsvWriter ccOut = new CsvWriter(ccFile, cfg.appendOutput);
             CsvWriter reposOut = new CsvWriter(reposFile, cfg.appendOutput);
             CsvWriter skipOut = new CsvWriter(skippedFile, cfg.appendOutput))
        {
            if (writeCcHeader) ccOut.writeLine(CC_HEADER);
            if (writeReposHeader) reposOut.writeLine(REPOS_HEADER);
            if (writeSkippedHeader) skipOut.writeLine(SKIPPED_HEADER);

            switch (cfg.runMode)
            {
                case "LOCAL_PATH" -> runLocalPath(cfg, ccOut, skipOut);
                case "GITHUB_REPO" -> runSingleRepo(cfg, ccOut, skipOut);
                case "GITHUB_SEARCH" -> runGitHubSearch(cfg, ccOut, reposOut, skipOut, scrapedAt, reposFile);
                default -> throw new IllegalArgumentException("Unknown run.mode: " + cfg.runMode);
            }
        }

        System.out.println();
        System.out.println("Output files:");
        System.out.println("  CC data:       " + ccFile.getAbsolutePath());
        System.out.println("  Repo metadata: " + reposFile.getAbsolutePath());
        System.out.println("  Skipped log:   " + skippedFile.getAbsolutePath());
    }

    private static boolean headerNeeded(Config cfg, File f)
    {
        return !cfg.appendOutput || !f.exists() || f.length() == 0;
    }

    private static void runLocalPath(Config cfg, CsvWriter ccOut, CsvWriter skipOut) throws Exception
    {
        File target = new File(cfg.localInput);
        int[] result = onBigStack(() -> processRepo(target, target.getName(), ccOut, skipOut));
        System.out.printf("Done. Java files: %d, methods written: %d%n", result[0], result[1]);
    }

    private static void runSingleRepo(Config cfg, CsvWriter ccOut, CsvWriter skipOut)
    {
        File cloneDir = null;
        try
        {
            System.out.println("Cloning: " + cfg.singleRepoUrl);
            cloneDir = cloneRepo(cfg.singleRepoUrl);
            final File repoDir = cloneDir;
            String repoName = cfg.singleRepoUrl.replaceAll(".*/([^/]+)\\.git$", "$1");
            int[] result = onBigStack(() -> processRepo(repoDir, repoName, ccOut, skipOut));
            System.out.printf("Done. Java files: %d, methods written: %d%n", result[0], result[1]);
        }
        catch (Exception e)
        {
            System.err.println("Failed to process repo: " + classifyError(e));
        }
        finally
        {
            deleteQuietly(cloneDir);
        }
    }

    /** Runs a task on a single large-stack worker thread and returns its result. */
    private static <T> T onBigStack(Callable<T> task) throws Exception
    {
        ExecutorService ex = Executors.newSingleThreadExecutor(BIG_STACK_FACTORY);
        try
        {
            return ex.submit(task).get();
        }
        finally
        {
            ex.shutdown();
        }
    }

    private static void runGitHubSearch(Config cfg, CsvWriter ccOut, CsvWriter reposOut,
                                        CsvWriter skipOut, String scrapedAt, File reposFile)
            throws Exception
    {
        String token = GitHubRepositorySearcher.readToken(Paths.get(cfg.tokenFile));
        GitHubRepositorySearcher searcher = new GitHubRepositorySearcher(token);

        // Resumability: when appending, don't re-process repos already in repos.csv.
        Set<String> done = cfg.appendOutput ? loadProcessedRepos(reposFile) : ConcurrentHashMap.newKeySet();
        if (!done.isEmpty())
            System.out.println("Resuming: " + done.size() + " repos already present will be skipped.");

        String baseQuery = buildBaseQuery(cfg);
        LocalDate createdBefore = LocalDate.parse(cfg.createdBefore);
        System.out.println("Planning search chunks for " + cfg.targetRepos + " results"
                + " created on or before " + createdBefore + "...");

        List<GitHubRepositorySearcher.SearchChunk> chunks =
                searcher.planChunks(baseQuery, createdBefore, cfg.targetRepos);

        int grandTotal = chunks.stream().mapToInt(c -> c.expectedCount).sum();
        System.out.println();
        System.out.println("Search parameters: " + baseQuery);
        System.out.println("Total raw results planned: " + grandTotal);
        System.out.println("Worker threads: " + cfg.threads);
        for (int i = 0; i < chunks.size(); i++)
        {
            GitHubRepositorySearcher.SearchChunk c = chunks.get(i);
            System.out.printf("  Chunk %d: %d results between %s and %s%n",
                    i + 1, c.expectedCount, c.startDate, c.endDate);
        }
        System.out.println();

        AtomicInteger mavenProcessed = new AtomicInteger(0);
        ExecutorService pool = Executors.newFixedThreadPool(cfg.threads, BIG_STACK_FACTORY);

        try
        {
            for (int i = 0; i < chunks.size(); i++)
            {
                if (mavenProcessed.get() >= cfg.targetRepos) break;

                GitHubRepositorySearcher.SearchChunk chunk = chunks.get(i);
                String chunkQuery = baseQuery + " " + chunk.dateFilter();

                System.out.printf("Processing chunk %d/%d (%s to %s)...%n",
                        i + 1, chunks.size(), chunk.startDate, chunk.endDate);

                List<GitHubRepositorySearcher.Repo> repos = searcher.search(chunkQuery);
                System.out.println("  Retrieved " + repos.size() + " repos in chunk");

                List<Future<?>> futures = new ArrayList<>();
                final int chunkIndex = i;
                final int chunkTotal = chunks.size();

                for (GitHubRepositorySearcher.Repo repo : repos)
                {
                    if (mavenProcessed.get() >= cfg.targetRepos) break;
                    if (!done.add(repo.fullName))   // already processed (resume or duplicate)
                    {
                        System.out.println("  Skipping (already done): " + repo.fullName);
                        continue;
                    }

                    futures.add(pool.submit(() -> processOneRepo(
                            cfg, repo, scrapedAt, ccOut, reposOut, skipOut,
                            mavenProcessed, chunkIndex, chunkTotal)));
                }

                awaitAll(futures);
            }
        }
        finally
        {
            pool.shutdown();
        }

        System.out.println();
        System.out.println("Maven repos written to CSV: " + mavenProcessed.get() + " / " + cfg.targetRepos);
    }

    private static void processOneRepo(Config cfg, GitHubRepositorySearcher.Repo repo, String scrapedAt,
                                       CsvWriter ccOut, CsvWriter reposOut, CsvWriter skipOut,
                                       AtomicInteger mavenProcessed, int chunkIndex, int chunkTotal)
    {
        if (mavenProcessed.get() >= cfg.targetRepos) return;

        File cloneDir = null;
        try
        {
            System.out.printf("[chunk %d/%d | total %d/%d]  %s%n",
                    chunkIndex + 1, chunkTotal, mavenProcessed.get(), cfg.targetRepos, repo.cloneUrl);

            cloneDir = cloneRepo(repo.cloneUrl);
            int[] result = processRepo(cloneDir, repo.fullName, ccOut, skipOut);

            reposOut.writeLine(repoRow(repo, scrapedAt, result[0]));
            ccOut.flush();
            reposOut.flush();

            mavenProcessed.incrementAndGet();
        }
        catch (Exception e)
        {
            String reason = classifyError(e);
            System.err.println("  Skipping repo " + repo.fullName + ": " + reason);
            logSkip(skipOut, "repo", repo.fullName, "", "", reason);
        }
        finally
        {
            deleteQuietly(cloneDir);
        }
    }

    private static String buildBaseQuery(Config cfg)
    {
        StringBuilder q = new StringBuilder();

        if (cfg.language != null)
            q.append("language:").append(cfg.language).append(" ");
        if (cfg.minStars != null)
            q.append("stars:>=").append(cfg.minStars).append(" ");
        if (cfg.minForks != null)
            q.append("forks:>=").append(cfg.minForks).append(" ");
        if (cfg.minCommits != null)
            q.append("commits:>=").append(cfg.minCommits).append(" ");
        if (cfg.minSizeKb != null && cfg.maxSizeKb != null)
            q.append("size:").append(cfg.minSizeKb).append("..").append(cfg.maxSizeKb).append(" ");
        else if (cfg.minSizeKb != null)
            q.append("size:>=").append(cfg.minSizeKb).append(" ");
        else if (cfg.maxSizeKb != null)
            q.append("size:<=").append(cfg.maxSizeKb).append(" ");
        if (cfg.pushedAfter != null)
            q.append("pushed:>=").append(cfg.pushedAfter).append(" ");

        return q.toString().trim();
    }

    private static int[] processRepo(File target, String repoName,
                                     CsvWriter ccOut, CsvWriter skipOut)
    {
        List<File> javaFiles = target.isDirectory() ? findJavaFiles(target) : List.of(target);
        int methodsWritten = 0;

        for (File f : javaFiles)
        {
            try
            {
                methodsWritten += processFile(f, repoName, ccOut, skipOut);
            }
            catch (StackOverflowError | Exception e)
            {
                String reason = classifyError(e);
                System.err.println("  Skipping file " + f.getName() + ": " + reason);
                logSkip(skipOut, "file", repoName, f.getName(), "", reason);
            }
        }

        return new int[]{javaFiles.size(), methodsWritten};
    }

    private static int processFile(File file, String projectName,
                                   CsvWriter out, CsvWriter skipOut) throws Exception
    {
        int count = 0;

        ParseResult<CompilationUnit> parsed = PARSER.get().parse(file);
        Optional<CompilationUnit> recovered = parsed.getResult();

        // Nothing usable came back at all: record the whole file once and move on.
        if (recovered.isEmpty())
            throw new IOException("parse error: " + firstProblem(parsed));

        CompilationUnit cu = recovered.get();

        // Partial parse: JavaParser recovered an AST despite syntax problems. Keep
        // every method it could read, and record the parse issue so the part it
        // could not interpret is not lost from the skip log.
        if (!parsed.isSuccessful())
            logSkip(skipOut, "file_partial", projectName, file.getName(), "", firstProblem(parsed));

        // findAll captures methods in classes, interfaces, enums, records and
        // anonymous classes — not just the methods of top-level classes.
        for (MethodDeclaration method : cu.findAll(MethodDeclaration.class))
        {
            String className = method.findAncestor(TypeDeclaration.class)
                    .map(t -> t.getNameAsString())
                    .orElse("(anonymous)");
            String methodName = method.getNameAsString();
            try
            {
                out.writeLine(methodRow(projectName, className, methodName, method));
                count++;
            }
            catch (StackOverflowError | Exception e)
            {
                logSkip(skipOut, "method", projectName, file.getName(), methodName, classifyError(e));
            }
        }
        return count;
    }

    private static String firstProblem(ParseResult<?> parsed)
    {
        return parsed.getProblems().isEmpty()
                ? "unknown parse error"
                : parsed.getProblems().get(0).getMessage().split("\\r?\\n")[0];
    }

    private static String methodRow(String projectName, String className, String methodName,
                                    MethodDeclaration method)
    {
        int cc = CyclomaticComplexityVisitor.compute(method);
        int cognitiveComplexity = CognitiveComplexityVisitor.compute(method);
        int loc = MethodLocCalculator.computeLOC(method);
        int locPhysical = MethodLocCalculator.computePhysicalLOC(method);

        double[] nesting = MethodNestingCalculator.computeNesting(method);
        double avgNesting = nesting[0];
        int maxNesting = (int) nesting[1];

        IdentifierMetricsCalculator.Metrics idMetrics = IdentifierMetricsCalculator.compute(method);
        HalsteadCalculator.Metrics hal = HalsteadCalculator.compute(method);
        MaintainabilityIndexCalculator.Metrics mi =
                MaintainabilityIndexCalculator.compute(hal.volume(), cc, loc);
        MethodStructureCalculator.Metrics struct = MethodStructureCalculator.compute(method);
        LineLengthCalculator.Metrics lines = LineLengthCalculator.compute(method);

        return String.format(Locale.ROOT,
                "\"%s\",\"%s\",\"%s\",%d,%d,%d,%d,%.2f,%d,%.2f,%.3f,%d,%d,%d,%d,%d,"
                + "%.2f,%.2f,%.2f,%.2f,%.2f,%d,%d,%d,%d,%.2f",
                escape(projectName), escape(className), escape(methodName),
                cc, cognitiveComplexity, loc, locPhysical, avgNesting, maxNesting,
                idMetrics.avgIdentifierWords(), idMetrics.abbreviatedRatio(),
                idMetrics.singleLetterCount(), idMetrics.longestIdentifier(),
                idMetrics.totalWordCount(), idMetrics.commentCount(), idMetrics.commentWordCount(),
                hal.volume(), hal.difficulty(), hal.effort(),
                mi.raw(), mi.normalized(),
                struct.paramCount(), struct.returnCount(), struct.fanOut(),
                lines.maxLineLength(), lines.avgLineLength());
    }

    private static List<File> findJavaFiles(File dir)
    {
        List<File> results = new ArrayList<>();
        File[] entries = dir.listFiles();
        if (entries == null) return results;

        for (File f : entries)
        {
            if (f.isDirectory())
            {
                if (!isMavenTestDir(f))
                    results.addAll(findJavaFiles(f));
            }
            else if (f.getName().endsWith(".java"))
                results.add(f);
        }
        return results;
    }

    // Matches src/test and src/it — the standard Maven test source directories
    private static boolean isMavenTestDir(File dir)
    {
        String name = dir.getName();
        if (!name.equals("test") && !name.equals("it")) return false;
        File parent = dir.getParentFile();
        return parent != null && parent.getName().equals("src");
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

    private static void deleteQuietly(File dir)
    {
        if (dir == null || !dir.exists()) return;
        try (Stream<Path> walk = Files.walk(dir.toPath()))
        {
            walk.sorted(Comparator.reverseOrder())
                    .map(Path::toFile)
                    .forEach(File::delete);
        }
        catch (IOException e)
        {
            System.err.println("  Could not delete temp dir " + dir + ": " + e.getMessage());
        }
    }

    private static void awaitAll(List<Future<?>> futures)
    {
        for (Future<?> f : futures)
        {
            try
            {
                f.get();   // task swallows its own errors; this just blocks
            }
            catch (Exception e)
            {
                System.err.println("  Worker task failed: " + classifyError(e));
            }
        }
    }

    /** Reads the first CSV column (full_name) from an existing repos.csv for resume. */
    private static Set<String> loadProcessedRepos(File reposFile)
    {
        Set<String> done = ConcurrentHashMap.newKeySet();
        if (!reposFile.exists()) return done;

        try (BufferedReader r = Files.newBufferedReader(reposFile.toPath()))
        {
            String line;
            boolean header = true;
            while ((line = r.readLine()) != null)
            {
                if (header) { header = false; continue; }
                if (line.isBlank()) continue;
                String name = parseFirstCsvField(line);
                if (!name.isEmpty()) done.add(name);
            }
        }
        catch (IOException e)
        {
            System.err.println("Could not read existing repos for resume: " + e.getMessage());
        }
        return done;
    }

    private static String parseFirstCsvField(String line)
    {
        if (!line.startsWith("\""))
        {
            int comma = line.indexOf(',');
            return comma >= 0 ? line.substring(0, comma) : line;
        }

        StringBuilder sb = new StringBuilder();
        int i = 1;
        while (i < line.length())
        {
            char c = line.charAt(i);
            if (c == '"')
            {
                if (i + 1 < line.length() && line.charAt(i + 1) == '"') { sb.append('"'); i += 2; continue; }
                break;
            }
            sb.append(c);
            i++;
        }
        return sb.toString();
    }

    private static String repoRow(GitHubRepositorySearcher.Repo r, String scrapedAt, int javaFileCount)
    {
        return String.format(Locale.ROOT,
                "\"%s\",\"%s\",%s,\"%s\",%d,%d,%d,%d,%d,%s,%s",
                escape(r.fullName), escape(r.htmlUrl), scrapedAt, escape(r.language),
                r.stars, r.forks, r.sizeKb, r.commitCount, javaFileCount, r.createdAt, r.pushedAt);
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

    private static void logSkip(CsvWriter out, String type, String repo,
                                String file, String method, String reason)
    {
        out.writeLine(String.format(Locale.ROOT, "\"%s\",\"%s\",\"%s\",\"%s\",\"%s\"",
                escape(type), escape(repo), escape(file), escape(method), escape(truncate(reason, 200))));
        out.flush();
    }

    private static String truncate(String s, int max)
    {
        if (s == null) return "";
        return s.length() <= max ? s : s.substring(0, max) + "...";
    }

    private static String escape(String value)
    {
        if (value == null) return "";
        return value.replace("\"", "\"\"");
    }

    /** Thread-safe line writer so parallel workers can share one output file. */
    private static final class CsvWriter implements AutoCloseable
    {
        private final PrintWriter out;

        CsvWriter(File file, boolean append) throws IOException
        {
            this.out = new PrintWriter(new FileWriter(file, append));
        }

        synchronized void writeLine(String line)
        {
            out.println(line);
        }

        synchronized void flush()
        {
            out.flush();
        }

        @Override
        public synchronized void close()
        {
            out.close();
        }
    }
}
