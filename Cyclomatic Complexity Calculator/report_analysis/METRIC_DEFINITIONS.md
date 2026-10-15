# Metric definitions: how each metric can be calculated, and what this project does

For the four key metrics this sets out:
- the published definition;
- the main ways tools differ from it;
- the choice this project made, and why.

The same calculator classes (`javaparser-complexity-calculator`) measure both the corpus and the survey snippets, so every measurement in the report follows these rules.

General rules:
- **Unit of measurement:** each method or constructor. Each lambda, and each method of a local or anonymous class, counts as part of the method that contains it.
- **Parsing:** JavaParser (3.25.10) at the newest language level, so modern syntax (records, switch expressions, text blocks) is understood.

---

## 1. Cyclomatic Complexity (CC)

**Published definition** (McCabe, 1976): the number of linearly independent paths through a method's control-flow graph, `E − N + 2`. For a single method this equals **1 + the number of decision points**, which is how every practical tool computes it.

**Where tools differ:**

| Construct | Option A | Option B | This project | Why |
|---|---|---|---|---|
| `&&`, `\|\|` | Count once per `if` (McCabe's original, "strict") | +1 per operator, as each short-circuit is a hidden branch (Myers, 1977, "extended CC") | **+1 per operator** | Matches SonarQube, PMD, Checkstyle's default and Lizard, so values match what developers see in their tools. `if (a && b)` has the same paths as two nested ifs. |
| `switch` | +1 per `case` label | +1 per `switch` | **+1 per non-default case label** | Each label is a separate path; this is the classic definition and the common tool default. `default` is the fall-through path, so it adds nothing. |
| `case A, B ->` (Java 14+) | +1 per arm | +1 per label | **+1 per label** | Equivalent to `case A: case B:`, which counts 2, so the newer syntax gives the same value as the older one. |
| `else` | | never counted | not counted | Not a decision; it is the other outcome of the `if`. |
| `else if` | | +1 (it is another `if`) | +1 | Universal. |
| ternary `?:` | usually +1 | | +1 | A decision in expression form. |
| `catch` | usually +1 | | +1 | An alternative path. |
| `try`, `finally`, `throw`, `return` | not counted by most tools | | not counted | `finally` always runs; early exits do not add independent paths in the counting rule. |
| Loops (`for`, for-each, `while`, `do`) | +1 each | | +1 each | Universal. |

## 2. Cognitive Complexity (CogC)

**Published definition:** G. A. Campbell, *Cognitive Complexity: A new way of measuring understandability*, SonarSource (2018), summarised in Campbell (2018, TechDebt). This project follows the specification's rules:

| Rule | Specification | This project |
|---|---|---|
| `if`, ternary, `switch`, loops, `catch` | +1, plus the current nesting level ("nesting penalty") | same |
| `else if`, `else` | +1, no nesting penalty, because a chain reads linearly | same |
| `switch` | +1 for the whole switch, **not per case** (it reads as one decision); this is a deliberate difference from CC | same |
| Logical operators | +1 per **sequence** of like operators: `a && b && c` = +1, `a && b \|\| c` = +2 | same |
| Structures that increase the nesting level | `if`/`else if`/`else`, ternary, `switch`, loops, `catch`, lambdas, nested methods/classes | same (lambdas, local classes and anonymous classes included) |
| Labelled `break` / `continue` | +1 | same |
| Recursion | +1 for each method in a recursion cycle (once per method, not per call) | +1 once if the method calls itself directly (see below) |

**Ternary chains:** a ternary nested in another ternary is penalised for its nesting, so `a ? x : b ? y : c ? z : d ? w : v` scores 1 + 2 + 3 + 4 = 10. That is the specification's rule. (A version of this calculator used before 15 Oct 2026 did not increase nesting for ternaries, which scored the same chain 4.)

**Recursion detection:** JavaParser builds a syntax tree but does not resolve which method a call refers to. That would need a full type solver with every project's dependencies, which is impractical across 1,800+ repositories. Instead, a call is treated as a recursive self-call only when all of these hold:
- it has the method's name;
- it has no receiver, or the receiver is `this` or the method's own class name. So `Math.max(...)` inside a method called `max` is **not** recursion;
- its argument count fits the method's parameter list (allowing for varargs);
- it is in the method's own body, not in a method of a nested class.

**What this misses:** indirect recursion (`a` calls `b`, which calls `a`) and a same-named overload with the same argument count. Both are rare. (A version used before 15 Oct 2026 matched calls on name alone and added +1 per call.)

## 3. Lines of code (LOC)

**Common definitions:** physical lines (everything), non-blank lines, **non-blank non-comment lines (NBNC, also called SLOC)**, or logical statements.

**This project:**
- **What counts:** NBNC lines, i.e. the distinct source lines holding at least one code token.
- **Range:** from the first token of the method (annotations and signature) to its closing brace.
- **What's excluded:** comment lines, blank lines, the method's Javadoc and imports.

`loc_physical` (the raw line span) is also recorded.

**Why NBNC:** it is the most common "size of code" measure, and it is not affected by commenting or blank-line style. That matters here because several survey variants differ only in their comments.

## 4. Maximum nesting depth (MaxNest)

**Common definitions:** there is no single standard. Tools count:
- nested blocks;
- nested control structures;
- nested `if`s only (Checkstyle's NestedIfDepth).

**This project:**
- **The rule:** for each statement, count the enclosing control structures (`if`, loops, `switch` case, `catch`) between it and the method. MaxNest is the largest such count; `avg_nesting` is the mean over all statements.
- **`else if`:** not counted as a level deeper than the `if` it continues. A 5-branch else-if chain is one level, the same as a single `if`/`else`.
- **Why:** this matches how Cognitive Complexity treats else-if (Campbell's rule that chains read linearly), so the two metrics count nesting the same way. It also matches how a reader sees an else-if chain.
- **The parser quirk:** JavaParser stores `else if` as an `if` inside the previous `if`'s else branch. A version of this calculator used before 15 Oct 2026 counted that internal link, so a 4-branch else-if chain scored 4. The current version does not.
- **What's not counted:** lambdas, `try` and `synchronized` blocks don't add a level, because they don't branch the control flow.

---

## Other recorded measurements (not key metrics)

| Column | Definition |
|---|---|
| `comment_count`, `comment_words` | Comments inside the method, plus the method's own header comment (Javadoc, or a comment directly above the signature). (Before 15 Oct 2026, the header comment was not counted.) |
| `has_javadoc` | 1 if the method has a Javadoc header. |
| `recursive` | 1 if the method calls itself directly (rule above). |
| Halstead volume, difficulty, effort | Operands = identifiers and literals; operators = keywords, operators and separators. V = N log2 n, D = (n1/2)(N2/n2), E = D·V. |
| `fan_out` | Number of distinct method names called. |
| `param_count`, `return_count` | Declared parameters; `return` statements. |
| Identifier measures | All identifier tokens, split on camelCase and underscores. Average words per identifier, share of identifiers that are short abbreviations (≤ 3 characters, not a common word), single-letter identifiers, longest identifier. |
| Line length | Rightmost column per line (indentation included); maximum and mean. |

## Corpus columns added in the October 2026 harvest

| Column | Purpose |
|---|---|
| `kind` | `method` or `constructor`. Constructors are now included; filter on this to compare with method-only figures. |
| `has_body` | 0 for abstract and interface methods with no body. These have CC 1 by definition, so including them inflates the share of trivial methods. |
| `nested_in_method` | 1 for methods of local or anonymous classes declared inside another method. Their code is also counted in the enclosing method, so exclude them to avoid counting it twice. |
| `is_generated` | 1 if the file is under a `*generated*` folder, starts with a generator marker ("auto-generated", "generated by", "do not edit", ...), or the method or class is annotated `@Generated`. The most extreme outliers in the corpus are generated parsers and lexers. |
| `body_hash` | Fingerprint of the method's code without comments or whitespace, for finding duplicate methods across repositories. |
| `file_path`, `start_line` | Where the method is, so any row can be traced back to its source. |
| Repo `contributors` | Number of contributors, including commit authors without a GitHub account (−1 when GitHub declines to list them). |
| Repo `head_sha` | The exact commit measured, so the snapshot can be reproduced. |
| Repo `default_branch`, `open_issues`, `license`, `archived`, `is_fork`, `topics` | Repository metadata from the search result (no extra API calls). |
