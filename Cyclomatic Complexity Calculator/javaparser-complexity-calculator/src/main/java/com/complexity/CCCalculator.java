package com.complexity;

import com.github.javaparser.ParserConfiguration;
import com.github.javaparser.StaticJavaParser;
import com.github.javaparser.ast.CompilationUnit;
import com.github.javaparser.ast.body.MethodDeclaration;

import java.io.File;
import java.util.ArrayList;
import java.util.List;
import java.util.Scanner;

public class CCCalculator
{

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

    public static void processFile(File file) throws Exception
    {
        CompilationUnit cu = StaticJavaParser.parse(file);
        List<MethodDeclaration> methods = cu.findAll(MethodDeclaration.class);
        if (methods.isEmpty()) return;

        System.out.println(file.getName());
        methods.forEach(method -> {
            int cc = computeCC(method);
            System.out.println("\t" + method.getNameAsString() + ": " + cc);
        });
    }

    public static void main(String[] args) throws Exception
    {
        StaticJavaParser.getParserConfiguration().setLanguageLevel(ParserConfiguration.LanguageLevel.JAVA_17);

        Scanner scanner = new Scanner(System.in);
        System.out.print("File or folder: ");
        String input = scanner.nextLine();
        scanner.close();
        File target = new File(input);

        if (target.isDirectory())
        {
            for (File f : findJavaFiles(target))
                processFile(f);
        }
        else
        {
            processFile(target);
        }
    }
}