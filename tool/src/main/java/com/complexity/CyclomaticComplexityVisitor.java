package com.complexity;

import com.github.javaparser.ast.body.CallableDeclaration;
import com.github.javaparser.ast.stmt.*;
import com.github.javaparser.ast.expr.*;
import com.github.javaparser.ast.visitor.VoidVisitorAdapter;

/**
 * Extended cyclomatic complexity (McCabe 1976, with Myers' 1977 extension):
 * 1 plus one for every decision point. Decision points are if / else if,
 * for, for-each, while, do, each non-default case label, catch, the ternary
 * operator, and each && or || (each short-circuit operator is a hidden branch).
 * else, default, try, finally, throw and return are not decision points.
 */
public class CyclomaticComplexityVisitor extends VoidVisitorAdapter<int[]>
{
    /**
     * Computes the cyclomatic complexity of a method or constructor, starting
     * from the baseline of 1 and adding 1 for each decision point.
     */
    public static int compute(CallableDeclaration<?> method)
    {
        int[] counter = {1};
        method.accept(new CyclomaticComplexityVisitor(), counter);
        return counter[0];
    }

    @Override
    public void visit(IfStmt n, int[] counter)
    {
        counter[0]++;
        super.visit(n, counter);
    }

    @Override
    public void visit(ForStmt n, int[] counter)
    {
        counter[0]++;
        super.visit(n, counter);
    }

    @Override
    public void visit(ForEachStmt n, int[] counter)
    {
        counter[0]++;
        super.visit(n, counter);
    }

    @Override
    public void visit(WhileStmt n, int[] counter)
    {
        counter[0]++;
        super.visit(n, counter);
    }

    @Override
    public void visit(DoStmt n, int[] counter)
    {
        counter[0]++;
        super.visit(n, counter);
    }

    @Override
    public void visit(SwitchEntry n, int[] counter)
    {
        // Each label is a separate outcome, so "case A, B ->" adds 2, the same
        // as the classic "case A: case B:". default has no label and adds 0.
        counter[0] += n.getLabels().size();
        super.visit(n, counter);
    }

    @Override
    public void visit(CatchClause n, int[] counter)
    {
        counter[0]++;
        super.visit(n, counter);
    }

    @Override
    public void visit(BinaryExpr n, int[] counter)
    {
        BinaryExpr.Operator op = n.getOperator();
        if (op == BinaryExpr.Operator.AND || op == BinaryExpr.Operator.OR)
        {
            counter[0]++;
        }
        super.visit(n, counter);
    }

    @Override
    public void visit(ConditionalExpr n, int[] counter)
    {
        counter[0]++;
        super.visit(n, counter);
    }
}