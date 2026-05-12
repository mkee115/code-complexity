package com.complexity;

import com.github.javaparser.ast.Node;
import com.github.javaparser.ast.body.MethodDeclaration;
import com.github.javaparser.ast.stmt.*;

import java.util.List;
import java.util.Optional;

public class MethodNestingCalculator
{
    // returns [averageNesting, maxNesting]
    public static double[] computeNesting(MethodDeclaration method)
    {
        List<Statement> statements = method.findAll(Statement.class);
        if (statements.isEmpty())
        {
            return new double[]{0.0, 0.0};
        }

        int sumNesting = 0;
        int maxNesting = 0;

        for (Statement statement : statements)
        {
            int level = nestingLevelOf(statement, method);
            sumNesting += level;
            if (level > maxNesting)
            {
                maxNesting = level;
            }
        }

        int lineCount = statements.size();
        double avg = (double) sumNesting / (double) lineCount;
        return new double[]{avg, (double) maxNesting};
    }

    private static int nestingLevelOf(Statement statement, MethodDeclaration method)
    {
        int level = 0;
        Optional<Node> current = statement.getParentNode();

        while (current.isPresent())
        {
            Node node = current.get();
            if (node == method)
            {
                break;
            }

            if (isNestingNode(node))
            {
                level++;
            }

            current = node.getParentNode();
        }

        return level;
    }

    private static boolean isNestingNode(Node node)
    {
        return node instanceof IfStmt
                || node instanceof ForStmt
                || node instanceof ForEachStmt
                || node instanceof WhileStmt
                || node instanceof DoStmt
                || node instanceof SwitchEntry
                || node instanceof CatchClause;
    }
}
