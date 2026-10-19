/*
ID           Method                       CC Cognitive   LOC  MaxNest  FanOut  Params    HalVol    HalEff AvgIdW
----------------------------------------------------------------------------------------------------------------
01-ORIG      grade                         5        14    21        4       0       1     376.0    4512.4   1.00
01-V1        grade                         5         4    15        1       0       1     257.8    1890.8   1.00
01-V2        grade                         5         5    15        4       0       1     347.8    4174.0   1.00
01-V3        grade                         5         4     4        0       0       1     169.6    1357.1   1.00
01-V4        grade                         5        14    21        4       0       1     376.0    4512.4   1.00
01-V5        grade                         5        14    21        4       0       1     376.0    4512.4   1.00
02-ORIG      check                         6         2     8        1       5       1     338.6    4643.3   1.21
02-V1        check                         6         5    18        1       5       1     427.9    5760.7   1.25
02-V2        check                         4         1     3        0       3       1     125.1    1081.2   1.60
02-V2        hasMinLength                  1         0     3        0       1       1      76.0     501.6   1.40
02-V2        hasLowerAndUpper              2         1     3        0       3       1     145.9    1605.4   1.64
02-V2        hasDigit                      1         0     3        0       1       1      70.3     421.9   1.20
02-V3        check                         6         2     8        1       5       1     338.6    4643.3   1.21
03-ORIG      sd                            3         4     9        1       1       1     203.9    5352.4   1.00
03-V1        sd                            2         1     9        1       1       1     229.2    4126.5   1.00
03-V2        sd                            3         4     6        1       1       1     188.9    5618.9   1.00
04-ORIG      max                           4         6    11        3       0       1     413.7   11169.2   1.04
04-V1        max                           4         6    11        3       0       1     256.8    4364.9   1.07
04-V2        max                           2         2     7        1       2       1     224.7    3145.3   1.14
04-V2        rowMax                        3         3     9        2       0       1     194.5    3306.7   1.17
04-V3        max                           4         6    11        3       0       1     413.7   11169.2   1.04
05-ORIG      dedupe                        5         8    15        3       4       1     620.6   14740.3   1.03
05-V1        dedupe                        3         3     9        2       2       1     282.0    5327.2   1.05
05-V2        dedupe                        1         0     3        0       0       1     126.7    1045.4   1.33
05-V3        removeDuplicates              5         8    15        3       4       1     620.6   14740.3   1.39
05-V4        dedupe                        5         8    15        3       4       1     620.6   14740.3   1.03
06-ORIG      tally                         3         4    12        2       4       1     542.8   12892.5   1.06
06-V1        tally                         2         1     7        1       2       1     309.1    4851.0   1.14
06-V2        countByValue                  3         4    12        2       4       1     542.8   12892.5   1.11
07-ORIG      merge                         6         7    27        2       0       2     840.0   57960.0   1.00
07-V1        merge                         4         5    16        2       1       2     795.0   46835.0   1.00
07-V2        merge                         1         0     7        0       2       2     385.4    8942.1   1.00
07-V3        merge                         6         7    27        2       0       2     840.0   57960.0   1.00
08-ORIG      roman                         4         8    16        3       3       1     519.8   15310.6   1.06
08-ORIG      value                         8         1    12        1       0       1     312.1    2313.3   1.00
08-V1        roman                         4         5    12        2       3       1     461.2   13145.6   1.07
08-V1        value                         8         1    12        1       0       1     312.1    2313.3   1.00
08-V2        roman                         3         4    14        2       3       1     421.1   10001.3   1.04
08-V2        value                         8         1    12        1       0       1     312.1    2313.3   1.00
09-ORIG      bSearch                       4         8    17        3       0       2     479.2   15981.9   1.04
09-V1        bSearch                       4         5    15        3       0       2     469.1   15645.4   1.04
09-V2        bSearch                       2         1     4        0       1       2     173.9    2347.9   1.20
10-ORIG      balanced                     15        28    26        4       5       1     938.7   26937.3   1.11
10-V1        balanced                      6        10    17        4       6       1     707.2   16786.6   1.25
10-V2        balanced                      6         8    14        4       7       1     649.7   14422.7   1.19
10-V2        matches                       1         0     3        0       1       2     118.9    1159.7   1.29
10-V3        balanced                     15        28    26        4       5       1     938.7   26937.3   1.11
*/



/* ----------------------------------------------------------------------------------
 * ID: 01-ORIG
 * Function: Turns a numeric score into a letter grade.
 * Complexities: CC 5 | Cognitive 14 | Nesting 4 | LOC 21 | FanOut 0
 * Isolating: baseline
 * ---------------------------------------------------------------------------------- */
public static String grade(int s) {
    String r;
    if (s >= 50) {
        if (s >= 65) {
            if (s >= 80) {
                if (s >= 90) {
                    r = "A+";
                } else {
                    r = "A";
                }
            } else {
                r = "B";
            }
        } else {
            r = "C";
        }
    } else {
        r = "D";
    }
    return r;
}


/* ----------------------------------------------------------------------------------
 * ID: 01-V1
 * Function: Turns a numeric score into a letter grade.
 * Complexities: CC 5 | Cognitive 4 | Nesting 1 | LOC 15 | FanOut 0
 * Isolating: nesting, by using guard clauses that return early
 * ---------------------------------------------------------------------------------- */
public static String grade(int s) {
    if (s < 50) {
        return "D";
    }
    if (s < 65) {
        return "C";
    }
    if (s < 80) {
        return "B";
    }
    if (s < 90) {
        return "A";
    }
    return "A+";
}


/* ----------------------------------------------------------------------------------
 * ID: 01-V2
 * Function: Turns a numeric score into a letter grade.
 * Complexities: CC 5 | Cognitive 5 | Nesting 4 | LOC 15 | FanOut 0
 * Isolating: multiple exits, by flattening to an else-if chain but keeping one exit
 * ---------------------------------------------------------------------------------- */
// CHECK HERE i think this one is too similar to one above ^ , prob should keep one delete
// the other. i dont have a preference on which
public static String grade(int s) {
    String r;
    if (s >= 90) {
        r = "A+";
    } else if (s >= 80) {
        r = "A";
    } else if (s >= 65) {
        r = "B";
    } else if (s >= 50) {
        r = "C";
    } else {
        r = "D";
    }
    return r;
}


/* ----------------------------------------------------------------------------------
 * ID: 01-V3
 * Function: Turns a numeric score into a letter grade.
 * Complexities: CC 5 | Cognitive 4 | Nesting 0 | LOC 4 | FanOut 0
 * Isolating: volume, by collapsing to a chained ternary at constant CC. Cognitive is
 *            10 under a strict reading of the nesting rule and 4 if a ternary chain is
 *            treated as flat, so measure it with your own extractor
 * ---------------------------------------------------------------------------------- */
public static String grade(int s) {
    return s >= 90 ? "A+" : s >= 80 ? "A" :
            s >= 65 ? "B" : s >= 50 ? "C" : "D";
}


/* ----------------------------------------------------------------------------------
 * ID: 01-V4
 * Function: Turns a numeric score into a letter grade.
 * Complexities: CC 5 | Cognitive 14 | Nesting 4 | LOC 21 | FanOut 0 | 4 comment lines
 * Isolating: comment quality, accurate summary. Code token for token identical to
 *            01-ORIG with a correct header comment stating the bands
 * ---------------------------------------------------------------------------------- */
/**
 * Converts a raw exam mark into a letter grade.
 * Bands: 90 and above A+, 80 to 89 A, 65 to 79 B, 50 to 64 C, below 50 D.
 */
public static String grade(int s) {
    String r;
    if (s >= 50) {
        if (s >= 65) {
            if (s >= 80) {
                if (s >= 90) {
                    r = "A+";
                } else {
                    r = "A";
                }
            } else {
                r = "B";
            }
        } else {
            r = "C";
        }
    } else {
        r = "D";
    }
    return r;
}


/* ----------------------------------------------------------------------------------
 * ID: 01-V5
 * Function: Turns a numeric score into a letter grade.
 * Complexities: CC 5 | Cognitive 14 | Nesting 4 | LOC 21 | FanOut 0 | 8 comment lines
 * Isolating: comment quality, redundant noise. Code identical to 01-ORIG, every
 *            comment restates the syntax of the line below it and adds nothing.
 *            Pair against 01-V4 to separate comment presence from comment usefulness
 * ---------------------------------------------------------------------------------- */
// CHECK HERE i dont like this one or the one above ^ bc i think this method is too
// comprehensible to have comments. i think we get the comment results from other
// methods
public static String grade(int s) {
    // declare the result variable
    String r;
    // check whether s is at least 50
    if (s >= 50) {
        // check whether s is at least 65
        if (s >= 65) {
            // check whether s is at least 80
            if (s >= 80) {
                // check whether s is at least 90
                if (s >= 90) {
                    // set r to A+
                    r = "A+";
                } else {
                    // set r to A
                    r = "A";
                }
            } else {
                r = "B";
            }
        } else {
            r = "C";
        }
    } else {
        r = "D";
    }
    // return the result
    return r;
}


/* ----------------------------------------------------------------------------------
 * ID: 02-ORIG
 * Function: Checks a password for length, mixed case and a digit.
 * Complexities: CC 6 | Cognitive 2 | Nesting 1 | LOC 8 | FanOut 5
 * Isolating: baseline
 * ---------------------------------------------------------------------------------- */
// CHECK HERE i think this method could be good to add comments too as a variant
public static boolean check(String p) {
    boolean ok = false;
    if (p != null && p.length() >= 8 && !p.equals(p.toLowerCase())
            && !p.equals(p.toUpperCase()) && p.matches(".*[0-9].*")) {
        ok = true;
    }
    return ok;
}


/* ----------------------------------------------------------------------------------
 * ID: 02-V1
 * Function: Checks a password for length, mixed case and a digit.
 * Complexities: CC 6 | Cognitive 5 | Nesting 1 | LOC 18 | FanOut 5
 * Isolating: cognitive complexity against CC, held equal at 6 while cognitive moves 2 to 5
 * ---------------------------------------------------------------------------------- */
public static boolean check(String p) {
    if (p == null) {
        return false;
    }
    if (p.length() < 8) {
        return false;
    }
    if (p.equals(p.toLowerCase())) {
        return false;
    }
    if (p.equals(p.toUpperCase())) {
        return false;
    }
    if (!p.matches(".*[0-9].*")) {
        return false;
    }
    return true;
}


/* ----------------------------------------------------------------------------------
 * ID: 02-V2
 * Function: Checks a password for length, mixed case and a digit.
 * Complexities: CC 4 | Cognitive 1 | Nesting 0 | LOC 3 | FanOut 3
 *               Helpers: CC 1, 2, 1 and LOC 3, 3, 3. Block totals CC 8, LOC 12
 * Isolating: extraction into named helpers
 * ---------------------------------------------------------------------------------- */
// CHECK HERE is it fine to make helper methods? just wanted to make sure since our study is
// about method complexity and not class complexity
public static boolean check(String p) {
    return p != null && hasMinLength(p) && hasLowerAndUpper(p) && hasDigit(p);
}

private static boolean hasMinLength(String p) {
    return p.length() >= 8;
}

private static boolean hasLowerAndUpper(String p) {
    return !p.equals(p.toLowerCase()) && !p.equals(p.toUpperCase());
}

private static boolean hasDigit(String p) {
    return p.matches(".*[0-9].*");
}


/* ----------------------------------------------------------------------------------
 * ID: 02-V3
 * Function: Checks a password for length, mixed case and a digit.
 * Complexities: CC 6 | Cognitive 2 | Nesting 1 | LOC 8 | FanOut 5
 * Isolating: comment quality, Javadoc header. Code token for token identical to 02-ORIG
 * ---------------------------------------------------------------------------------- */
/**
 * Checks whether a password meets the minimum security requirements.
 *
 * @param p the password to validate
 * @return true if the password is non-null, at least 8 characters long,
 *         contains at least one uppercase letter, one lowercase letter,
 *         and one digit; false otherwise
 */
public static boolean check(String p) {
    boolean ok = false;
    if (p != null && p.length() >= 8 && !p.equals(p.toLowerCase())
            && !p.equals(p.toUpperCase()) && p.matches(".*[0-9].*")) {
        ok = true;
    }
    return ok;
}


/* ----------------------------------------------------------------------------------
 * ID: 03-ORIG
 * Function: Sums the decimal digits of an integer.
 * Complexities: CC 3 | Cognitive 4 | Nesting 1 | LOC 9 | FanOut 1
 * Isolating: baseline
 * ---------------------------------------------------------------------------------- */
public static int sd(int n) {
    if (n < 0) {
        return sd(-n);
    }
    if (n < 10) {
        return n;
    }
    return n % 10 + sd(n / 10);
}


/* ----------------------------------------------------------------------------------
 * ID: 03-V1
 * Function: Sums the decimal digits of an integer.
 * Complexities: CC 2 | Cognitive 1 | Nesting 1 | LOC 9 | FanOut 1
 * Isolating: recursion, with LOC identical on both sides so size cannot explain a preference
 * ---------------------------------------------------------------------------------- */
public static int sd(int n) {
    int remaining = Math.abs(n);
    int total = 0;
    while (remaining > 0) {
        total = total + remaining % 10;
        remaining = remaining / 10;
    }
    return total;
}


/* ----------------------------------------------------------------------------------
 * ID: 03-V2
 * Function: Sums the decimal digits of an integer.
 * Complexities: CC 3 | Cognitive 4 | Nesting 1 | LOC 6 | FanOut 1
 * Isolating: volume, with recursion and both control flow metrics held constant
 * ---------------------------------------------------------------------------------- */
public static int sd(int n) {
    if (n < 0) {
        return sd(-n);
    }
    return n < 10 ? n : n % 10 + sd(n / 10);
}


/* ----------------------------------------------------------------------------------
 * ID: 04-ORIG
 * Function: Finds the largest value in a 2D array.
 * Complexities: CC 4 | Cognitive 6 | Nesting 3 | LOC 11 | FanOut 0
 * Isolating: baseline
 * ---------------------------------------------------------------------------------- */
public static int max(int[][] g) {
    int m = Integer.MIN_VALUE;
    for (int i = 0; i < g.length; i++) {
        for (int j = 0; j < g[i].length; j++) {
            if (g[i][j] > m) {
                m = g[i][j];
            }
        }
    }
    return m;
}


/* ----------------------------------------------------------------------------------
 * ID: 04-V1
 * Function: Finds the largest value in a 2D array.
 * Complexities: CC 4 | Cognitive 6 | Nesting 3 | LOC 11 | FanOut 0
 * Isolating: volume alone, since enhanced for loops move only Halstead vocabulary
 * ---------------------------------------------------------------------------------- */
// CHECK HERE too similar to original, i think using other java features is not good for this
// study, since it will make students think the complexity is higher
public static int max(int[][] g) {
    int m = Integer.MIN_VALUE;
    for (int[] row : g) {
        for (int cell : row) {
            if (cell > m) {
                m = cell;
            }
        }
    }
    return m;
}


/* ----------------------------------------------------------------------------------
 * ID: 04-V2
 * Function: Finds the largest value in a 2D array.
 * Complexities: CC 2 | Cognitive 2 | Nesting 1 | LOC 7 | FanOut 2
 *               Helper rowMax: CC 3, Cognitive 3, Nesting 2, LOC 9. Block totals CC 5, LOC 16
 * Isolating: extraction, where summed CC exceeds the original but no method is as deep
 * ---------------------------------------------------------------------------------- */
// CHECK HERE as written before, idk if we should use helper methods. also i dont think
// we should use a helper method for this method if we are including them, it makes it
// sm more complicated i reckon
public static int max(int[][] g) {
    int m = Integer.MIN_VALUE;
    for (int[] row : g) {
        m = Math.max(m, rowMax(row));
    }
    return m;
}

private static int rowMax(int[] row) {
    int m = Integer.MIN_VALUE;
    for (int cell : row) {
        if (cell > m) {
            m = cell;
        }
    }
    return m;
}


/* ----------------------------------------------------------------------------------
 * ID: 04-V3
 * Function: Finds the largest value in a 2D array.
 * Complexities: CC 4 | Cognitive 6 | Nesting 3 | LOC 11 | FanOut 0 | 3 comment lines
 * Isolating: comment quality, helpful inline. Code token for token identical to 04-ORIG,
 *            each comment explains why rather than what
 * ---------------------------------------------------------------------------------- */
// CHECK HERE i like having comments in this one, although i think the comments should be
// more comprehensible (also bc a lot of compsci students are international, may not
// have english as first language)
public static int max(int[][] g) {
    // start below every possible value so the first cell always wins
    int m = Integer.MIN_VALUE;
    for (int i = 0; i < g.length; i++) {
        // rows may have different lengths, so bound on this row
        for (int j = 0; j < g[i].length; j++) {
            if (g[i][j] > m) {
                // keep the running best
                m = g[i][j];
            }
        }
    }
    return m;
}


/* ----------------------------------------------------------------------------------
 * ID: 05-ORIG
 * Function: Removes duplicates from a list, keeping first appearance order.
 * Complexities: CC 5 | Cognitive 8 | Nesting 3 | LOC 15 | FanOut 4
 * Isolating: baseline
 * ---------------------------------------------------------------------------------- */
// CHECK HERE love this method (like including variants), def keep, also could be good
// candidate for comments
import java.util.ArrayList;
import java.util.List;

public static List<String> dedupe(List<String> in) {
    List<String> out = new ArrayList<>();
    for (int i = 0; i < in.size(); i++) {
        boolean found = false;
        for (int j = 0; j < out.size(); j++) {
            if (in.get(i).equals(out.get(j))) {
                found = true;
            }
        }
        if (!found) {
            out.add(in.get(i));
        }
    }
    return out;
}


/* ----------------------------------------------------------------------------------
 * ID: 05-V1
 * Function: Removes duplicates from a list, keeping first appearance order.
 * Complexities: CC 3 | Cognitive 3 | Nesting 2 | LOC 9 | FanOut 2
 * Isolating: branch count and nesting together, algorithm unchanged
 * ---------------------------------------------------------------------------------- */
import java.util.ArrayList;
import java.util.List;

public static List<String> dedupe(List<String> in) {
    List<String> out = new ArrayList<>();
    for (String s : in) {
        if (!out.contains(s)) {
            out.add(s);
        }
    }
    return out;
}


/* ----------------------------------------------------------------------------------
 * ID: 05-V2
 * Function: Removes duplicates from a list, keeping first appearance order.
 * Complexities: CC 1 | Cognitive 0 | Nesting 0 | LOC 3 | FanOut 0
 * Isolating: library knowledge, at the floor of every structural metric
 * ---------------------------------------------------------------------------------- */
// CHECK HERE idk i think this one may be too based on utilising java libraries instead of
// the actual algorithm
import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.List;

public static List<String> dedupe(List<String> in) {
    return new ArrayList<>(new LinkedHashSet<>(in));
}


/* ----------------------------------------------------------------------------------
 * ID: 05-V3
 * Function: Removes duplicates from a list, keeping first appearance order.
 * Complexities: CC 5 | Cognitive 8 | Nesting 3 | LOC 15 | FanOut 4
 * Isolating: naming, on a structurally hard method. Pair with 01-V3 for the interaction
 *            between naming and structural difficulty
 * ---------------------------------------------------------------------------------- */
import java.util.ArrayList;
import java.util.List;

public static List<String> removeDuplicates(List<String> source) {
    List<String> unique = new ArrayList<>();
    for (int sourceIndex = 0; sourceIndex < source.size(); sourceIndex++) {
        boolean alreadySeen = false;
        for (int uniqueIndex = 0; uniqueIndex < unique.size(); uniqueIndex++) {
            if (source.get(sourceIndex).equals(unique.get(uniqueIndex))) {
                alreadySeen = true;
            }
        }
        if (!alreadySeen) {
            unique.add(source.get(sourceIndex));
        }
    }
    return unique;
}


/* ----------------------------------------------------------------------------------
 * ID: 05-V4
 * Function: Removes duplicates from a list, keeping first appearance order.
 * Complexities: CC 5 | Cognitive 8 | Nesting 3 | LOC 15 | FanOut 4
 * Isolating: comments. Code token for token identical to 05-ORIG with a Javadoc
 *            header and one inline comment
 * ---------------------------------------------------------------------------------- */
import java.util.ArrayList;
import java.util.List;

/**
 * Removes duplicate strings from a list, preserving the order of first appearance.
 *
 * @param in the input list, possibly containing duplicates
 * @return a new list containing only the first occurrence of each string
 */
public static List<String> dedupe(List<String> in) {
    List<String> out = new ArrayList<>();
    for (int i = 0; i < in.size(); i++) {
        boolean found = false;
        // check if the current element already exists in the output list
        for (int j = 0; j < out.size(); j++) {
            if (in.get(i).equals(out.get(j))) {
                found = true;
            }
        }
        if (!found) {
            out.add(in.get(i));
        }
    }
    return out;
}



/* ----------------------------------------------------------------------------------
 * ID: 06-ORIG
 * Function: Counts how many times each string appears in a list.
 * Complexities: CC 3 | Cognitive 4 | Nesting 2 | LOC 12 | FanOut 4
 * Isolating: baseline
 * ---------------------------------------------------------------------------------- */
import java.util.HashMap;
import java.util.List;
import java.util.Map;

public static Map<String, Integer> tally(List<String> items) {
    Map<String, Integer> m = new HashMap<>();
    for (int i = 0; i < items.size(); i++) {
        String k = items.get(i);
        if (m.containsKey(k)) {
            m.put(k, m.get(k) + 1);
        } else {
            m.put(k, 1);
        }
    }
    return m;
}


/* ----------------------------------------------------------------------------------
 * ID: 06-V1
 * Function: Counts how many times each string appears in a list.
 * Complexities: CC 2 | Cognitive 1 | Nesting 1 | LOC 7 | FanOut 2
 * Isolating: branch count, by replacing the presence test with a default lookup
 * ---------------------------------------------------------------------------------- */
import java.util.HashMap;
import java.util.List;
import java.util.Map;

public static Map<String, Integer> tally(List<String> items) {
    Map<String, Integer> m = new HashMap<>();
    for (String k : items) {
        m.put(k, m.getOrDefault(k, 0) + 1);
    }
    return m;
}


/* ----------------------------------------------------------------------------------
 * ID: 06-V2
 * Function: Counts how many times each string appears in a list.
 * Complexities: CC 3 | Cognitive 4 | Nesting 2 | LOC 12 | FanOut 4
 * Isolating: naming, structure identical to 06-ORIG
 * ---------------------------------------------------------------------------------- */
// CHECK HERE rlly like this variant
import java.util.HashMap;
import java.util.List;
import java.util.Map;

public static Map<String, Integer> countByValue(List<String> items) {
    Map<String, Integer> counts = new HashMap<>();
    for (int index = 0; index < items.size(); index++) {
        String key = items.get(index);
        if (counts.containsKey(key)) {
            counts.put(key, counts.get(key) + 1);
        } else {
            counts.put(key, 1);
        }
    }
    return counts;
}


/* ----------------------------------------------------------------------------------
 * ID: 07-ORIG
 * Function: Merges two sorted arrays into one sorted array.
 * Complexities: CC 6 | Cognitive 7 | Nesting 2 | LOC 27 | FanOut 0
 * Isolating: baseline
 * ---------------------------------------------------------------------------------- */
public static int[] merge(int[] a, int[] b) {
    int[] out = new int[a.length + b.length];
    int i = 0;
    int j = 0;
    int k = 0;
    while (i < a.length && j < b.length) {
        if (a[i] <= b[j]) {
            out[k] = a[i];
            i++;
        } else {
            out[k] = b[j];
            j++;
        }
        k++;
    }
    while (i < a.length) {
        out[k] = a[i];
        i++;
        k++;
    }
    while (j < b.length) {
        out[k] = b[j];
        j++;
        k++;
    }
    return out;
}


/* ----------------------------------------------------------------------------------
 * ID: 07-V1
 * Function: Merges two sorted arrays into one sorted array.
 * Complexities: CC 4 | Cognitive 5 | Nesting 2 | LOC 16 | FanOut 1
 * Isolating: branch count, by replacing the two tail loops with bulk copies
 * ---------------------------------------------------------------------------------- */
// CHECK HERE i like this variant but im wary about the use of System.arraycopy, since
// it may be too complex for our audience
public static int[] merge(int[] a, int[] b) {
    int[] out = new int[a.length + b.length];
    int i = 0;
    int j = 0;
    int k = 0;
    while (i < a.length && j < b.length) {
        if (a[i] <= b[j]) {
            out[k++] = a[i++];
        } else {
            out[k++] = b[j++];
        }
    }
    System.arraycopy(a, i, out, k, a.length - i);
    System.arraycopy(b, j, out, k + a.length - i, b.length - j);
    return out;
}


/* ----------------------------------------------------------------------------------
 * ID: 07-V2
 * Function: Merges two sorted arrays into one sorted array.
 * Complexities: CC 1 | Cognitive 0 | Nesting 0 | LOC 7 | FanOut 2
 * Isolating: control flow removal, at the cost of doing asymptotically more work
 * ---------------------------------------------------------------------------------- */
// CHECK HERE relies on java libaries too much i reckon
import java.util.Arrays;

public static int[] merge(int[] a, int[] b) {
    int[] out = new int[a.length + b.length];
    System.arraycopy(a, 0, out, 0, a.length);
    System.arraycopy(b, 0, out, a.length, b.length);
    Arrays.sort(out);
    return out;
}


/* ----------------------------------------------------------------------------------
 * ID: 07-V3
 * Function: Merges two sorted arrays into one sorted array.
 * Complexities: CC 6 | Cognitive 7 | Nesting 2 | LOC 27 | FanOut 0 | 3 comment lines
 * Isolating: comment quality, helpful inline on a long method. Code token for token
 *            identical to 07-ORIG. This is the largest method in the set, so it tests
 *            whether comments pay off more when there is more to hold in your head
 * ---------------------------------------------------------------------------------- */
// CHECK HERE love this one
public static int[] merge(int[] a, int[] b) {
    int[] out = new int[a.length + b.length];
    int i = 0;
    int j = 0;
    int k = 0;
    // take the smaller of the two front elements until one side runs out
    while (i < a.length && j < b.length) {
        if (a[i] <= b[j]) {
            out[k] = a[i];
            i++;
        } else {
            out[k] = b[j];
            j++;
        }
        k++;
    }
    // exactly one of the next two loops runs, draining whatever is left over
    while (i < a.length) {
        out[k] = a[i];
        i++;
        k++;
    }
    // both sides are already sorted, so the leftovers can be copied straight across
    while (j < b.length) {
        out[k] = b[j];
        j++;
        k++;
    }
    return out;
}


/* ----------------------------------------------------------------------------------
 * ID: 08-ORIG
 * Function: Converts a Roman numeral to an integer.
 * Complexities: CC 4 | Cognitive 8 | Nesting 3 | LOC 16 | FanOut 3
 *               Helper value: CC 8, LOC 12, held constant across all three variants
 * Isolating: baseline
 * ---------------------------------------------------------------------------------- */
// CHECK HERE love this method
public static int roman(String s) {
    int total = 0;
    for (int i = 0; i < s.length(); i++) {
        int v = value(s.charAt(i));
        if (i + 1 < s.length()) {
            if (v < value(s.charAt(i + 1))) {
                total = total - v;
            } else {
                total = total + v;
            }
        } else {
            total = total + v;
        }
    }
    return total;
}

private static int value(char c) {
    switch (c) {
        case 'I': return 1;
        case 'V': return 5;
        case 'X': return 10;
        case 'L': return 50;
        case 'C': return 100;
        case 'D': return 500;
        case 'M': return 1000;
        default: return 0;
    }
}


/* ----------------------------------------------------------------------------------
 * ID: 08-V1
 * Function: Converts a Roman numeral to an integer.
 * Complexities: CC 4 | Cognitive 5 | Nesting 2 | LOC 12 | FanOut 3
 * Isolating: nesting, by merging the bounds check into the comparison with &&
 * ---------------------------------------------------------------------------------- */
// CHECK HERE love this bc it reduces cognitive by a lot but not cc
public static int roman(String s) {
    int total = 0;
    for (int i = 0; i < s.length(); i++) {
        int v = value(s.charAt(i));
        if (i + 1 < s.length() && v < value(s.charAt(i + 1))) {
            total = total - v;
        } else {
            total = total + v;
        }
    }
    return total;
}

private static int value(char c) {
    switch (c) {
        case 'I': return 1;
        case 'V': return 5;
        case 'X': return 10;
        case 'L': return 50;
        case 'C': return 100;
        case 'D': return 500;
        case 'M': return 1000;
        default: return 0;
    }
}


/* ----------------------------------------------------------------------------------
 * ID: 08-V2
 * Function: Converts a Roman numeral to an integer.
 * Complexities: CC 3 | Cognitive 4 | Nesting 2 | LOC 14 | FanOut 3
 * Isolating: branch count, by scanning right to left against a running maximum
 * ---------------------------------------------------------------------------------- */
// CHECK HERE i think unless we also want to test having a reversed loop instead of a
// forward loop, we should leave this one out bc itll probably increase cognitive
// complexity. but if we do want to test that, this is a good variant. idk if i explained
// that well, ask me ab it if it doesnt
public static int roman(String s) {
    int total = 0;
    int highest = 0;
    for (int i = s.length() - 1; i >= 0; i--) {
        int v = value(s.charAt(i));
        if (v < highest) {
            total = total - v;
        } else {
            total = total + v;
            highest = v;
        }
    }
    return total;
}

private static int value(char c) {
    switch (c) {
        case 'I': return 1;
        case 'V': return 5;
        case 'X': return 10;
        case 'L': return 50;
        case 'C': return 100;
        case 'D': return 500;
        case 'M': return 1000;
        default: return 0;
    }
}


/* ----------------------------------------------------------------------------------
 * ID: 09-ORIG
 * Function: Binary searches a sorted array, returning an index or -1.
 * Complexities: CC 4 | Cognitive 8 | Nesting 3 | LOC 17 | FanOut 0
 * Isolating: baseline
 * ---------------------------------------------------------------------------------- */
// CHECK HERE prob shouldnt name it 'bs' for the study, love this method tho
public static int bSearch(int[] a, int t) {
    int lo = 0;
    int hi = a.length - 1;
    while (lo <= hi) {
        int mid = (lo + hi) / 2;
        if (a[mid] == t) {
            return mid;
        } else {
            if (a[mid] < t) {
                lo = mid + 1;
            } else {
                hi = mid - 1;
            }
        }
    }
    return -1;
}


/* ----------------------------------------------------------------------------------
 * ID: 09-V1
 * Function: Binary searches a sorted array, returning an index or -1.
 * Complexities: CC 4 | Cognitive 5 | Nesting 3 | LOC 15 | FanOut 0
 * Isolating: nesting, by folding the inner if into an else-if at constant CC
 * ---------------------------------------------------------------------------------- */
public static int bSearch(int[] a, int t) {
    int lo = 0;
    int hi = a.length - 1;
    while (lo <= hi) {
        int mid = (lo + hi) / 2;
        if (a[mid] == t) {
            return mid;
        } else if (a[mid] < t) {
            lo = mid + 1;
        } else {
            hi = mid - 1;
        }
    }
    return -1;
}


/* ----------------------------------------------------------------------------------
 * ID: 09-V2
 * Function: Binary searches a sorted array, returning an index or -1.
 * Complexities: CC 2 | Cognitive 1 | Nesting 0 | LOC 4 | FanOut 1
 * Isolating: control flow removal, traded for knowing what the library returns on a miss
 * ---------------------------------------------------------------------------------- */
// CHECK HERE i think this one is too reliant on java libraries again
import java.util.Arrays;

public static int bSearch(int[] a, int t) {
    int i = Arrays.binarySearch(a, t);
    return i < 0 ? -1 : i;
}


/* ----------------------------------------------------------------------------------
 * ID: 10-ORIG
 * Function: Checks whether brackets in a string are balanced and correctly nested.
 * Complexities: CC 15 | Cognitive 28 | Nesting 4 | LOC 26 | FanOut 5
 * Isolating: baseline. The hardest item in the set and the only one above McCabe's
 *            threshold of 10, so it doubles as a probe for RQ3
 * ---------------------------------------------------------------------------------- */
// CHECK HERE i think this method is too complicated for the study, keen to scrap it all.
// unless you think that they can get read two of these and write about it within 2 mins?
import java.util.ArrayDeque;
import java.util.Deque;

public static boolean balanced(String s) {
    Deque<Character> st = new ArrayDeque<>();
    for (int i = 0; i < s.length(); i++) {
        char c = s.charAt(i);
        if (c == '(' || c == '[' || c == '{') {
            st.push(c);
        } else {
            if (c == ')' || c == ']' || c == '}') {
                if (st.isEmpty()) {
                    return false;
                }
                char o = st.pop();
                if (o == '(' && c != ')') {
                    return false;
                }
                if (o == '[' && c != ']') {
                    return false;
                }
                if (o == '{' && c != '}') {
                    return false;
                }
            }
        }
    }
    return st.isEmpty();
}


/* ----------------------------------------------------------------------------------
 * ID: 10-V1
 * Function: Checks whether brackets in a string are balanced and correctly nested.
 * Complexities: CC 6 | Cognitive 10 | Nesting 4 | LOC 17 | FanOut 6
 * Isolating: branch count, by replacing nine character comparisons with position lookups
 * ---------------------------------------------------------------------------------- */
import java.util.ArrayDeque;
import java.util.Deque;

public static boolean balanced(String s) {
    Deque<Character> st = new ArrayDeque<>();
    for (int i = 0; i < s.length(); i++) {
        char c = s.charAt(i);
        if ("([{".indexOf(c) >= 0) {
            st.push(c);
        } else if (")]}".indexOf(c) >= 0) {
            if (st.isEmpty()) {
                return false;
            }
            if ("([{".indexOf(st.pop()) != ")]}".indexOf(c)) {
                return false;
            }
        }
    }
    return st.isEmpty();
}


/* ----------------------------------------------------------------------------------
 * ID: 10-V2
 * Function: Checks whether brackets in a string are balanced and correctly nested.
 * Complexities: CC 6 | Cognitive 8 | Nesting 4 | LOC 14 | FanOut 7
 *               Helper matches: CC 1, LOC 3. Block totals CC 7, LOC 17
 * Isolating: extraction, with the pair test moved behind a name and guarded by short circuiting
 * ---------------------------------------------------------------------------------- */
import java.util.ArrayDeque;
import java.util.Deque;

public static boolean balanced(String s) {
    Deque<Character> st = new ArrayDeque<>();
    for (int i = 0; i < s.length(); i++) {
        char c = s.charAt(i);
        if ("([{".indexOf(c) >= 0) {
            st.push(c);
        } else if (")]}".indexOf(c) >= 0) {
            if (st.isEmpty() || !matches(st.pop(), c)) {
                return false;
            }
        }
    }
    return st.isEmpty();
}

private static boolean matches(char open, char close) {
    return "([{".indexOf(open) == ")]}".indexOf(close);
}


/* ----------------------------------------------------------------------------------
 * ID: 10-V3
 * Function: Checks whether brackets in a string are balanced and correctly nested.
 * Complexities: CC 15 | Cognitive 28 | Nesting 4 | LOC 26 | FanOut 5 | 6 comment lines
 * Isolating: comment quality, accurate summary plus signposts, on the hardest method in
 *            the set. Code token for token identical to 10-ORIG. Pair against 10-ORIG to
 *            ask whether a good comment is worth more than a large structural improvement,
 *            since 10-V1 halves CC on the same method
 * ---------------------------------------------------------------------------------- */
import java.util.ArrayDeque;
import java.util.Deque;

/**
 * Returns true when every bracket is closed by one of its own kind, in the right order.
 * Characters that are not brackets are ignored.
 */
public static boolean balanced(String s) {
    Deque<Character> st = new ArrayDeque<>();
    for (int i = 0; i < s.length(); i++) {
        char c = s.charAt(i);
        // an opener is remembered until its partner shows up
        if (c == '(' || c == '[' || c == '{') {
            st.push(c);
        } else {
            if (c == ')' || c == ']' || c == '}') {
                if (st.isEmpty()) {
                    return false;
                }
                // a closer has to match the most recent unclosed opener
                char o = st.pop();
                if (o == '(' && c != ')') {
                    return false;
                }
                if (o == '[' && c != ']') {
                    return false;
                }
                if (o == '{' && c != '}') {
                    return false;
                }
            }
        }
    }
    return st.isEmpty();
}

