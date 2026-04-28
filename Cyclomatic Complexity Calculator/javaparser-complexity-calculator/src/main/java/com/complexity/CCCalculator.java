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
    private static final String  LANGUAGE = "java";
    private static final Integer MIN_STARS = null;
    private static final Integer MIN_FORKS = null;
    private static final Integer MIN_SIZE_KB = null;
    private static final Integer MAX_SIZE_KB = null;
    private static final String  CREATED_AFTER = null; // YYYY-MM-DD
    private static final String  CREATED_BEFORE = null;
    private static final String  PUSHED_AFTER = null;
    
    private static final Integer MIN_COMMITS   = null;

    private static final String OUTPUT_DIR = ".\\Cyclomatic Complexity Calculator\\analysis";
    private static final String CC_FILE = OUTPUT_DIR + "\\cc_data.csv";
    private static final String REPOS_FILE = OUTPUT_DIR + "\\repos.csv";
    private static final String TOKEN_FILE = ".\\Cyclomatic Complexity Calculator\\javaparser-complexity-calculator\\.token";

    public static void main(String[] args) throws Exception
    {
        StaticJavaParser.getParserConfiguration().setLanguageLevel(ParserConfiguration.LanguageLevel.JAVA_17);

        String query = buildQuery();

        String token = GitHubSearcher.readToken(Paths.get(TOKEN_FILE));
        GitHubSearcher searcher = new GitHubSearcher(token);

        List<GitHubSearcher.Repo> repos = searcher.search(query);
        System.out.println("Found " + repos.size() + " repos");

        File ccFile = new File(CC_FILE);
        File reposFile = new File(REPOS_FILE);
        boolean writeCcHeader = !ccFile.exists() || ccFile.length() == 0;
        boolean writeReposHeader = !reposFile.exists() || reposFile.length() == 0;
        String scrapedAt = LocalDate.now().toString();

        try (PrintWriter ccOut = new PrintWriter(new FileWriter(ccFile, true));
             PrintWriter reposOut = new PrintWriter(new FileWriter(reposFile, true)))
        {
            if (writeCcHeader)
                ccOut.println("project,class_name,method_name,cc");
            
            if (writeReposHeader)
                reposOut.println("full_name,url,scraped_at,language,stars,forks,size_kb,commit_count,java_file_count,created_at,pushed_at");

            for (GitHubSearcher.Repo repo : repos)
            {
                File cloneDir = null;
                try
                {
                    cloneDir = cloneRepo(repo.cloneUrl);
                    List<File> javaFiles = findJavaFiles(cloneDir);

                    for (File f : javaFiles)
                    {
                        try
                        {
                            processFile(f, repo.fullName, ccOut);
                        }
                        catch (Exception e)
                        {
                            System.err.println("Skipping " + f.getName() + ": " + e.getMessage());
                        }
                    }

                    writeRepoRow(reposOut, repo, scrapedAt, javaFiles.size());
                    ccOut.flush();
                    reposOut.flush();
                }
                catch (Exception e)
                {
                    System.err.println("Skipping repo " + repo.fullName + ": " + e.getMessage());
                }
                finally
                {
                    if (cloneDir != null) deleteRecursively(cloneDir);
                }
            }
        }

        System.out.println("Done.");
        System.out.println("CC data: " + ccFile.getAbsolutePath());
        System.out.println("Repo metadata: " + reposFile.getAbsolutePath());
    }

    private static String buildQuery()
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
        if (CREATED_AFTER != null && CREATED_BEFORE != null) 
            q.append("created:").append(CREATED_AFTER).append("..").append(CREATED_BEFORE).append(" ");
        else if (CREATED_AFTER != null) 
            q.append("created:>=").append(CREATED_AFTER).append(" ");
        else if (CREATED_BEFORE != null) 
            q.append("created:<=").append(CREATED_BEFORE).append(" ");
        if (PUSHED_AFTER != null) 
            q.append("pushed:>=").append(PUSHED_AFTER).append(" ");
        
        return q.toString().trim();
    }

    private static void writeRepoRow(PrintWriter out, GitHubSearcher.Repo r, String scrapedAt, int javaFileCount)
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

    private static void processFile(File file, String projectName, PrintWriter out) throws Exception
    {
        CompilationUnit cu = StaticJavaParser.parse(file);

        for (ClassOrInterfaceDeclaration cls : cu.findAll(ClassOrInterfaceDeclaration.class))
        {
            String className = cls.getNameAsString();
            for (MethodDeclaration method : cls.getMethods())
            {
                int cc = computeCC(method);
                out.printf("\"%s\",\"%s\",\"%s\",%d%n",
                        escape(projectName),
                        escape(className),
                        escape(method.getNameAsString()),
                        cc);
            }
        }
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
        System.out.println("Cloning " + repoUrl + " ...");

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

    private static String escape(String value)
    {
        return value.replace("\"", "\"\"");
    }
}