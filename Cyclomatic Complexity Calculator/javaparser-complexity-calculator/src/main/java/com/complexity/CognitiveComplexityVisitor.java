package com.complexity;

import com.github.javaparser.ast.Node;
import com.github.javaparser.ast.body.MethodDeclaration;
import com.github.javaparser.ast.expr.BinaryExpr;
import com.github.javaparser.ast.expr.ConditionalExpr;
import com.github.javaparser.ast.expr.EnclosedExpr;
import com.github.javaparser.ast.expr.Expression;
import com.github.javaparser.ast.expr.LambdaExpr;
import com.github.javaparser.ast.expr.MethodCallExpr;
import com.github.javaparser.ast.stmt.CatchClause;
import com.github.javaparser.ast.stmt.DoStmt;
import com.github.javaparser.ast.stmt.ForEachStmt;
import com.github.javaparser.ast.stmt.ForStmt;
import com.github.javaparser.ast.stmt.IfStmt;
import com.github.javaparser.ast.stmt.SwitchStmt;
import com.github.javaparser.ast.stmt.WhileStmt;
import com.github.javaparser.ast.visitor.VoidVisitorAdapter;

import java.util.Optional;

public class CognitiveComplexityVisitor extends VoidVisitorAdapter<Void>
{
    private final String methodName;
    private int complexity = 0;
    private int nestingLevel = 0;

    private CognitiveComplexityVisitor(String methodName)
    {
        this.methodName = methodName;
    }

    public static int compute(MethodDeclaration method)
    {
        CognitiveComplexityVisitor visitor = new CognitiveComplexityVisitor(method.getNameAsString());
        visitor.visit(method, null);
        return visitor.complexity;
    }

    @Override
    public void visit(IfStmt n, Void arg)
    {
        boolean elseIf = isElseIf(n);

        if (elseIf)
            complexity += 1;
        else
            complexity += 1 + nestingLevel;

        if (n.getElseStmt().isPresent() && !(n.getElseStmt().get() instanceof IfStmt))
            complexity += 1;

        if (!elseIf)
            nestingLevel++;

        super.visit(n, arg);

        if (!elseIf)
            nestingLevel--;
    }

    @Override
    public void visit(ForStmt n, Void arg)
    {
        complexity += 1 + nestingLevel;
        nestingLevel++;
        super.visit(n, arg);
        nestingLevel--;
    }

    @Override
    public void visit(ForEachStmt n, Void arg)
    {
        complexity += 1 + nestingLevel;
        nestingLevel++;
        super.visit(n, arg);
        nestingLevel--;
    }

    @Override
    public void visit(WhileStmt n, Void arg)
    {
        complexity += 1 + nestingLevel;
        nestingLevel++;
        super.visit(n, arg);
        nestingLevel--;
    }

    @Override
    public void visit(DoStmt n, Void arg)
    {
        complexity += 1 + nestingLevel;
        nestingLevel++;
        super.visit(n, arg);
        nestingLevel--;
    }

    @Override
    public void visit(CatchClause n, Void arg)
    {
        complexity += 1 + nestingLevel;
        nestingLevel++;
        super.visit(n, arg);
        nestingLevel--;
    }

    @Override
    public void visit(SwitchStmt n, Void arg)
    {
        complexity += 1 + nestingLevel;
        nestingLevel++;
        super.visit(n, arg);
        nestingLevel--;
    }

    @Override
    public void visit(ConditionalExpr n, Void arg)
    {
        complexity += 1 + nestingLevel;
        super.visit(n, arg);
    }

    @Override
    public void visit(LambdaExpr n, Void arg)
    {
        nestingLevel++;
        super.visit(n, arg);
        nestingLevel--;
    }

    @Override
    public void visit(BinaryExpr n, Void arg)
    {
        if (isLogicalOperator(n.getOperator()) && isLogicalChainRoot(n))
            complexity += countLogicalSequences(n, null);

        super.visit(n, arg);
    }

    @Override
    public void visit(MethodCallExpr n, Void arg)
    {
        if (n.getNameAsString().equals(methodName))
            complexity += 1;

        super.visit(n, arg);
    }

    private boolean isElseIf(IfStmt n)
    {
        Optional<Node> parent = n.getParentNode();
        if (parent.isEmpty() || !(parent.get() instanceof IfStmt parentIf))
            return false;

        return parentIf.getElseStmt().map(elseStmt -> elseStmt == n).orElse(false);
    }

    private boolean isLogicalChainRoot(BinaryExpr n)
    {
        Optional<Node> parent = n.getParentNode();
        while (parent.isPresent() && parent.get() instanceof EnclosedExpr)
            parent = parent.get().getParentNode();

        return parent
                .filter(p -> p instanceof BinaryExpr)
                .map(p -> (BinaryExpr) p)
                .filter(parentBinary -> isLogicalOperator(parentBinary.getOperator()))
                .isEmpty();
    }

    private int countLogicalSequences(Expression expr, BinaryExpr.Operator parentOperator)
    {
        if (expr instanceof EnclosedExpr enclosed)
            return countLogicalSequences(enclosed.getInner(), parentOperator);

        if (!(expr instanceof BinaryExpr binary) || !isLogicalOperator(binary.getOperator()))
            return 0;

        int count = (parentOperator == null || binary.getOperator() != parentOperator) ? 1 : 0;
        count += countLogicalSequences(binary.getLeft(), binary.getOperator());
        count += countLogicalSequences(binary.getRight(), binary.getOperator());
        return count;
    }

    private boolean isLogicalOperator(BinaryExpr.Operator op)
    {
        return op == BinaryExpr.Operator.AND || op == BinaryExpr.Operator.OR;
    }
}