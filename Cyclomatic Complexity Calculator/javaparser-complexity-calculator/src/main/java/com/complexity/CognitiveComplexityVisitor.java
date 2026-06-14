package com.complexity;

import com.github.javaparser.ast.expr.*;
import com.github.javaparser.ast.stmt.*;
import com.github.javaparser.ast.visitor.VoidVisitorAdapter;

/**
 * Computes SonarSource cognitive complexity for a single method.
 *
 * Rules (from G. Ann Campbell, "Cognitive Complexity", SonarSource 2023):
 *   - Structural increments (if, else-if, loops, switch, catch, ternary):
 *       +1 + current nesting level.  Each such construct also raises the
 *       nesting level for its body by 1.
 *   - else (plain): flat +1, no nesting penalty.
 *   - Logical-operator sequences (&&, ||): flat +1 per contiguous run of
 *       the same operator — "a && b && c" scores 1, not 2.
 *   - Lambdas / anonymous-class bodies: raise nesting by 1 but score nothing.
 *
 * counter[0] = accumulated score
 * counter[1] = current nesting depth
 */
public class CognitiveComplexityVisitor extends VoidVisitorAdapter<int[]>
{
    // ------------------------------------------------------------------ if/else

    @Override
    public void visit(IfStmt n, int[] counter)
    {
        counter[0] += 1 + counter[1];
        counter[1]++;
        n.getCondition().accept(this, counter);
        n.getThenStmt().accept(this, counter);
        counter[1]--;

        n.getElseStmt().ifPresent(elseStmt -> {
            if (elseStmt instanceof IfStmt) {
                visitElseIf((IfStmt) elseStmt, counter);
            } else {
                counter[0] += 1;        // plain else: flat +1, no nesting penalty
                counter[1]++;
                elseStmt.accept(this, counter);
                counter[1]--;
            }
        });
    }

    /** Handles "else if" chains at the same nesting level as the opening "if". */
    private void visitElseIf(IfStmt n, int[] counter)
    {
        counter[0] += 1 + counter[1];
        counter[1]++;
        n.getCondition().accept(this, counter);
        n.getThenStmt().accept(this, counter);
        counter[1]--;

        n.getElseStmt().ifPresent(elseStmt -> {
            if (elseStmt instanceof IfStmt) {
                visitElseIf((IfStmt) elseStmt, counter);
            } else {
                counter[0] += 1;
                counter[1]++;
                elseStmt.accept(this, counter);
                counter[1]--;
            }
        });
    }

    // ------------------------------------------------------------------ loops

    @Override
    public void visit(ForStmt n, int[] counter)
    {
        counter[0] += 1 + counter[1];
        counter[1]++;
        super.visit(n, counter);
        counter[1]--;
    }

    @Override
    public void visit(ForEachStmt n, int[] counter)
    {
        counter[0] += 1 + counter[1];
        counter[1]++;
        super.visit(n, counter);
        counter[1]--;
    }

    @Override
    public void visit(WhileStmt n, int[] counter)
    {
        counter[0] += 1 + counter[1];
        counter[1]++;
        super.visit(n, counter);
        counter[1]--;
    }

    @Override
    public void visit(DoStmt n, int[] counter)
    {
        counter[0] += 1 + counter[1];
        counter[1]++;
        super.visit(n, counter);
        counter[1]--;
    }

    // ------------------------------------------------------------------ switch

    @Override
    public void visit(SwitchStmt n, int[] counter)
    {
        counter[0] += 1 + counter[1];   // whole switch counts once, not per case
        counter[1]++;
        super.visit(n, counter);
        counter[1]--;
    }

    @Override
    public void visit(SwitchExpr n, int[] counter)
    {
        counter[0] += 1 + counter[1];
        counter[1]++;
        super.visit(n, counter);
        counter[1]--;
    }

    // ------------------------------------------------------------------ catch

    @Override
    public void visit(CatchClause n, int[] counter)
    {
        counter[0] += 1 + counter[1];
        counter[1]++;
        super.visit(n, counter);
        counter[1]--;
    }

    // ------------------------------------------------------------------ ternary

    @Override
    public void visit(ConditionalExpr n, int[] counter)
    {
        counter[0] += 1 + counter[1];   // penalised for nesting, but doesn't add to it
        super.visit(n, counter);
    }

    // ------------------------------------------------------------------ logical operators

    @Override
    public void visit(BinaryExpr n, int[] counter)
    {
        BinaryExpr.Operator op = n.getOperator();
        if (op == BinaryExpr.Operator.AND || op == BinaryExpr.Operator.OR) {
            // Count once per contiguous run of the same operator.
            // "a && b && c" → 1;  "a && b || c" → 2.
            boolean partOfSameRun = n.getParentNode()
                    .filter(p -> p instanceof BinaryExpr)
                    .map(p -> ((BinaryExpr) p).getOperator() == op)
                    .orElse(false);
            if (!partOfSameRun) {
                counter[0]++;   // flat +1, no nesting penalty
            }
        }
        super.visit(n, counter);
    }

    // ------------------------------------------------------------------ lambdas / anon classes

    @Override
    public void visit(LambdaExpr n, int[] counter)
    {
        counter[1]++;
        super.visit(n, counter);
        counter[1]--;
    }

    @Override
    public void visit(ObjectCreationExpr n, int[] counter)
    {
        if (n.getAnonymousClassBody().isPresent()) {
            counter[1]++;
            super.visit(n, counter);
            counter[1]--;
        } else {
            super.visit(n, counter);
        }
    }
}
