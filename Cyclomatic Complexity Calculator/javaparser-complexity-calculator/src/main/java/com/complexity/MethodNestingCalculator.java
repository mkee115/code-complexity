package com.complexity;

import com.github.javaparser.ast.Node;
import com.github.javaparser.ast.body.CallableDeclaration;
import com.github.javaparser.ast.stmt.*;

import java.util.List;
import java.util.Optional;

/**
 * Structural nesting depth: for each statement, the number of enclosing control
 * structures (if, loops, switch case, catch) between it and the method.
 *
 * An else-if is not a level deeper than the if it continues. JavaParser stores
 * "else if" as an if inside the previous if's else branch, but a chain reads as
 * one flat sequence of alternatives, so that link is not counted. This matches
 * how cognitive complexity treats else-if.
 */
public class MethodNestingCalculator
{
    // returns [averageNesting, maxNesting]
    public static double[] computeNesting(CallableDeclaration<?> method)
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

    private static int nestingLevelOf(Statement statement, CallableDeclaration<?> method)
    {
        int level = 0;
        Node child = statement;
        Optional<Node> current = statement.getParentNode();
        while (current.isPresent())
        {
            Node node = current.get();
            if (node == method)
            {
                break;
            }
            if (isNestingNode(node) && !isElseIfLink(node, child))
            {
                level++;
            }
            child = node;
            current = node.getParentNode();
        }
        return level;
    }

    /** True when child is the else-if branch of node, which adds no depth. */
    private static boolean isElseIfLink(Node node, Node child)
    {
        return node instanceof IfStmt parentIf
                && child instanceof IfStmt
                && parentIf.getElseStmt().map(e -> e == child).orElse(false);
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
