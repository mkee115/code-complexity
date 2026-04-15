package com.complexity;

import com.github.javaparser.StaticJavaParser;
import com.github.javaparser.ast.CompilationUnit;
import com.github.javaparser.ast.body.MethodDeclaration;

import java.io.File;

public class CCCalculator
{

    public static int computeCC(MethodDeclaration method)
    {
        int[] counter = {1};
        new CyclomaticComplexityVisitor().visit(method, counter);
        return counter[0];
    }

    public static void main(String[] args) throws Exception
    {
        System.out.print("File name: ");
        String fileName = System.console().readLine();
        CompilationUnit cu = StaticJavaParser.parse(new File(fileName));

        cu.findAll(MethodDeclaration.class).forEach(method -> {
            int cc = computeCC(method);
            System.out.println(method.getNameAsString() + ": " + cc);
        });
    }
}