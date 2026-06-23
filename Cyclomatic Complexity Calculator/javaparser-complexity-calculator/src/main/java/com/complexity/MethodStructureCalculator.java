package com.complexity;

import com.github.javaparser.ast.body.MethodDeclaration;
import com.github.javaparser.ast.expr.MethodCallExpr;
import com.github.javaparser.ast.stmt.ReturnStmt;

import java.util.HashSet;
import java.util.Set;

/**
 * Cheap structural metrics for a method: parameter count, return-statement
 * count, and fan-out (number of distinct method names invoked).
 */
public class MethodStructureCalculator
{
    public record Metrics(int paramCount, int returnCount, int fanOut) {}

    public static Metrics compute(MethodDeclaration method)
    {
        int paramCount = method.getParameters().size();
        int returnCount = method.findAll(ReturnStmt.class).size();

        Set<String> calledMethods = new HashSet<>();
        for (MethodCallExpr call : method.findAll(MethodCallExpr.class))
            calledMethods.add(call.getNameAsString());

        return new Metrics(paramCount, returnCount, calledMethods.size());
    }
}
