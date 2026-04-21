package com.complexity;

import com.github.javaparser.ParserConfiguration;
import com.github.javaparser.StaticJavaParser;
import com.github.javaparser.ast.CompilationUnit;
import com.github.javaparser.ast.body.ClassOrInterfaceDeclaration;
import com.github.javaparser.ast.body.MethodDeclaration;

import org.eclipse.jgit.api.Git;

import java.io.File;
import java.io.PrintWriter;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Scanner;
import java.util.stream.Stream;

public class CCCalculator
{
    private static final String OUTPUT_FILE = "cc_data.csv";

    public static int computeCC(MethodDeclaration method)
    {
        int[] counter = {1};
        new CyclomaticComplexityVisitor().visit(method, counter);
        return counter[0];
    }

    public static List<File> findJavaFiles(File dir)
    {
        List<File> results = new ArrayList<>();
        for (File f : dir.listFiles())
        {
            if (f.isDirectory())
                results.addAll(findJavaFiles(f));
            else if (f.getName().endsWith(".java"))
                results.add(f);
        }
        return results;
    }

    public static void processFile(File file, String projectName, PrintWriter out) throws Exception
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

    private static String escape(String value)
    {
        return value.replace("\"", "\"\"");
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
        if (!dir.exists()) 
            return;

        try (Stream<Path> walk = Files.walk(dir.toPath()))
        {
            walk.sorted(Comparator.reverseOrder())
                    .map(Path::toFile)
                    .forEach(File::delete);
        }
    }

    private static String deriveProjectName(String repoUrl)
    {
        String cleaned = repoUrl.trim();
        if (cleaned.endsWith("/"))
            cleaned = cleaned.substring(0, cleaned.length() - 1);
        
        if (cleaned.endsWith(".git"))
            cleaned = cleaned.substring(0, cleaned.length() - 4);

        cleaned = cleaned.replaceFirst("^https?://", "");
        cleaned = cleaned.replaceFirst("^git@", "");
        cleaned = cleaned.replaceFirst("^github\\.com[:/]", "");

        return cleaned;
    }

    public static void main(String[] args) throws Exception
    {
        StaticJavaParser.getParserConfiguration().setLanguageLevel(ParserConfiguration.LanguageLevel.JAVA_17);

        Scanner scanner = new Scanner(System.in);
        System.out.print("GitHub repo URL: ");
        String repoUrl = scanner.nextLine().trim();
        scanner.close();

        String projectName = deriveProjectName(repoUrl);
        File cloneDir = cloneRepo(repoUrl);

        File outputFile = new File(OUTPUT_FILE);
        boolean writeHeader = !outputFile.exists() || outputFile.length() == 0;

        try (PrintWriter out = new PrintWriter(new java.io.FileWriter(outputFile, false)))
        {
            if (writeHeader)
                out.println("project,class_name,method_name,cc");

            for (File f : findJavaFiles(cloneDir))
            {
                try
                {
                    processFile(f, projectName, out);
                }
                catch (Exception e)
                {
                    System.err.println("Skipping " + f.getName() + ": " + e.getMessage());
                }
            }
        }
        finally
        {
            try
            {
                deleteRecursively(cloneDir);
            }
            catch (Exception e)
            {
                System.err.println("Warning: could not delete temp clone dir " + cloneDir);
            }
        }

        System.out.println("Done. Project '" + projectName + "' written to: " + outputFile.getAbsolutePath());
    }
}