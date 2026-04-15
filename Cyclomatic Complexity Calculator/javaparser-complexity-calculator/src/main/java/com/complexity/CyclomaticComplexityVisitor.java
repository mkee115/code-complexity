package com.complexity;

import com.github.javaparser.ast.stmt.*;
import com.github.javaparser.ast.expr.*;
import com.github.javaparser.ast.visitor.VoidVisitorAdapter;

public class CyclomaticComplexityVisitor extends VoidVisitorAdapter<int[]>
{

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
        if (!n.getLabels().isEmpty())
        {
            counter[0]++;
        }
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