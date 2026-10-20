package com.complexity;

import com.github.javaparser.ast.Node;
import com.github.javaparser.ast.body.CallableDeclaration;
import com.github.javaparser.ast.body.ConstructorDeclaration;
import com.github.javaparser.ast.body.Parameter;
import com.github.javaparser.ast.body.TypeDeclaration;
import com.github.javaparser.ast.expr.BinaryExpr;
import com.github.javaparser.ast.expr.ConditionalExpr;
import com.github.javaparser.ast.expr.EnclosedExpr;
import com.github.javaparser.ast.expr.Expression;
import com.github.javaparser.ast.expr.LambdaExpr;
import com.github.javaparser.ast.expr.MethodCallExpr;
import com.github.javaparser.ast.expr.NameExpr;
import com.github.javaparser.ast.expr.ObjectCreationExpr;
import com.github.javaparser.ast.expr.ThisExpr;
import com.github.javaparser.ast.stmt.BreakStmt;
import com.github.javaparser.ast.stmt.CatchClause;
import com.github.javaparser.ast.stmt.ContinueStmt;
import com.github.javaparser.ast.stmt.DoStmt;
import com.github.javaparser.ast.stmt.ForEachStmt;
import com.github.javaparser.ast.stmt.ForStmt;
import com.github.javaparser.ast.stmt.IfStmt;
import com.github.javaparser.ast.stmt.LocalClassDeclarationStmt;
import com.github.javaparser.ast.stmt.LocalRecordDeclarationStmt;
import com.github.javaparser.ast.stmt.SwitchStmt;
import com.github.javaparser.ast.stmt.WhileStmt;
import com.github.javaparser.ast.visitor.VoidVisitorAdapter;

import java.util.List;
import java.util.Optional;

/**
 * Cognitive complexity, following G. A. Campbell, "Cognitive Complexity: A new
 * way of measuring understandability" (SonarSource, 2018):
 *
 *  - if, ternary, switch, loops and catch add 1 plus the current nesting level,
 *    and increase the nesting level for the code inside them;
 *  - else if and else add 1 with no nesting penalty (they read linearly);
 *  - switch adds 1 for the whole statement, whatever the number of cases;
 *  - each sequence of like logical operators adds 1 (a && b && c = 1,
 *    a && b || c = 2);
 *  - labelled break and continue add 1;
 *  - lambdas, local classes and anonymous classes increase the nesting level;
 *  - recursion adds 1 per method, not per recursive call.
 */
public class CognitiveComplexityVisitor extends VoidVisitorAdapter<Void>
{
    private int complexity = 0;
    private int nestingLevel = 0;

    public static int compute(CallableDeclaration<?> method)
    {
        CognitiveComplexityVisitor visitor = new CognitiveComplexityVisitor();
        method.accept(visitor, null);
        return visitor.complexity + (isRecursive(method) ? 1 : 0);
    }

    /**
     * True when the method calls itself directly. JavaParser does not resolve
     * call targets without a full symbol solver (impractical across thousands of
     * repositories with missing dependencies), so a call counts as a self-call
     * only when all of these hold:
     *  - it has the method's name;
     *  - it has no receiver, or the receiver is {@code this} or the method's own
     *    class name (so {@code Math.max} inside {@code max} is not recursion);
     *  - its argument count fits the parameter list (allowing for varargs);
     *  - it is not inside a nested class's own method.
     * Constructors are never recursive in this sense (this(...) is delegation).
     */
    public static boolean isRecursive(CallableDeclaration<?> method)
    {
        if (method instanceof ConstructorDeclaration)
            return false;
        for (MethodCallExpr call : method.findAll(MethodCallExpr.class))
        {
            if (isSelfCall(call, method))
                return true;
        }
        return false;
    }

    private static boolean isSelfCall(MethodCallExpr call, CallableDeclaration<?> method)
    {
        if (!call.getNameAsString().equals(method.getNameAsString()))
            return false;

        // The call must belong to this method, not to a method of a nested class
        Optional<CallableDeclaration> owner = call.findAncestor(CallableDeclaration.class);
        if (owner.isEmpty() || owner.get() != method)
            return false;

        if (call.getScope().isPresent())
        {
            Expression scope = call.getScope().get();
            String className = method.findAncestor(TypeDeclaration.class)
                    .map(t -> t.getNameAsString()).orElse(null);
            boolean ownReceiver = scope instanceof ThisExpr
                    || (scope instanceof NameExpr name && name.getNameAsString().equals(className));
            if (!ownReceiver)
                return false;
        }

        List<Parameter> params = method.getParameters();
        int args = call.getArguments().size();
        boolean varArgs = !params.isEmpty() && params.get(params.size() - 1).isVarArgs();
        return varArgs ? args >= params.size() - 1 : args == params.size();
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
        // A ternary nested inside another ternary is penalised for its nesting,
        // so a 4-way chained ternary scores 1 + 2 + 3 + 4 = 10
        complexity += 1 + nestingLevel;
        nestingLevel++;
        super.visit(n, arg);
        nestingLevel--;
    }

    @Override
    public void visit(BreakStmt n, Void arg)
    {
        if (n.getLabel().isPresent())
            complexity += 1;
        super.visit(n, arg);
    }

    @Override
    public void visit(ContinueStmt n, Void arg)
    {
        if (n.getLabel().isPresent())
            complexity += 1;
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
    public void visit(LocalClassDeclarationStmt n, Void arg)
    {
        nestingLevel++;
        super.visit(n, arg);
        nestingLevel--;
    }

    @Override
    public void visit(LocalRecordDeclarationStmt n, Void arg)
    {
        nestingLevel++;
        super.visit(n, arg);
        nestingLevel--;
    }

    @Override
    public void visit(ObjectCreationExpr n, Void arg)
    {
        // Arguments sit at the current level; an anonymous class body is nested
        n.getScope().ifPresent(s -> s.accept(this, arg));
        n.getArguments().forEach(a -> a.accept(this, arg));
        n.getAnonymousClassBody().ifPresent(body ->
        {
            nestingLevel++;
            body.forEach(member -> member.accept(this, arg));
            nestingLevel--;
        });
    }

    @Override
    public void visit(BinaryExpr n, Void arg)
    {
        if (isLogicalOperator(n.getOperator()) && isLogicalChainRoot(n))
            complexity += countLogicalSequences(n, null);
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
