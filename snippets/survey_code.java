/*
 * Survey snippets: the 34 code variants shown to participants, labelled with
 * the survey IDs used in the questions (01-ORIG, 01-V1, ...). Measured by
 * SurveyAnalyser (run_survey.ps1). Summary of every method measured:
 *
 * ID           Method                       CC Cognitive   LOC  MaxNest  AvgNest  FanOut  Params    HalVol    HalEff AvgIdW  Comments  Javadoc  Recur
 * --------------------------------------------------------------------------------------------------------------------------------------------------
 * 01-ORIG      grade                         5        14    21        4     2.00       0       1     376.0    4512.4   1.00         0       no     no
 * 01-V1        grade                         5         5    15        1     0.59       0       1     347.8    4174.0   1.00         0       no     no
 * 01-V2        grade                         5        10     4        0     0.00       0       1     169.6    1357.1   1.00         0       no     no
 * 01-V3        grade                         5        14    21        4     2.00       0       1     376.0    4512.4   1.00         1      yes     no
 * 02-ORIG      check                         6         2     8        1     0.33       5       1     338.6    4643.3   1.21         0       no     no
 * 02-V1        check                         6         5    18        1     0.59       5       1     427.9    5760.7   1.25         0       no     no
 * 02-V2        check                         4         1     3        0     0.00       3       1     125.1    1081.2   1.60         0       no     no
 * 02-V2        hasMinLength                  1         0     3        0     0.00       1       1      76.0     501.6   1.40         0       no     no
 * 02-V2        hasLowerAndUpper              2         1     3        0     0.00       3       1     145.9    1605.4   1.64         0       no     no
 * 02-V2        hasDigit                      1         0     3        0     0.00       1       1      70.3     421.9   1.20         0       no     no
 * 02-V3        check                         6         2     8        1     0.33       5       1     338.6    4643.3   1.21         1      yes     no
 * 03-ORIG      sd                            3         3     9        1     0.50       1       1     203.9    5352.4   1.00         0       no    yes
 * 03-V1        sd                            2         1     9        1     0.38       1       1     229.2    4126.5   1.00         0       no     no
 * 03-V2        sd                            3         3     6        1     0.40       1       1     188.9    5618.9   1.00         0       no    yes
 * 04-ORIG      max                           4         6    11        3     1.20       0       1     413.7   11169.2   1.04         0       no     no
 * 04-V1        max                           2         1     7        1     0.33       2       1     224.7    3145.3   1.14         0       no     no
 * 04-V1        rowMax                        3         3     9        2     0.75       0       1     194.5    3306.7   1.17         0       no     no
 * 05-ORIG      dedupe                        5         8    15        3     1.29       4       1     620.6   14740.3   1.03         0       no     no
 * 05-V1        dedupe                        3         3     9        2     0.75       2       1     282.0    5327.2   1.05         0       no     no
 * 05-V2        dedupe                        1         0     3        0     0.00       0       1     126.7    1045.4   1.33         0       no     no
 * 05-V3        removeDuplicates              5         8    15        3     1.29       4       1     620.6   14740.3   1.39         0       no     no
 * 05-V4        dedupe                        5         8    15        3     1.29       4       1     620.6   14740.3   1.03         2      yes     no
 * 06-ORIG      tally                         3         4    12        2     1.00       4       1     542.8   12892.5   1.06         0       no     no
 * 06-V1        tally                         2         1     7        1     0.33       2       1     309.1    4851.0   1.14         0       no     no
 * 06-V2        countByValue                  3         4    12        2     1.00       4       1     542.8   12892.5   1.11         0       no     no
 * 07-ORIG      merge                         6         7    27        2     0.88       0       2     840.0   57960.0   1.00         0       no     no
 * 07-V1        merge                         4         5    16        2     0.67       1       2     795.0   46835.0   1.00         0       no     no
 * 07-V2        merge                         1         0     7        0     0.00       2       2     385.4    8942.1   1.00         0       no     no
 * 07-V3        merge                         6         7    27        2     0.88       0       2     840.0   57960.0   1.00         3       no     no
 * 08-ORIG      roman                         4         8    16        3     1.53       3       1     519.8   15310.6   1.06         0       no     no
 * 08-ORIG      value                         8         1    12        1     0.80       0       1     312.1    2313.3   1.00         0       no     no
 * 08-V1        roman                         4         5    12        2     1.00       3       1     461.2   13145.6   1.07         0       no     no
 * 08-V1        value                         8         1    12        1     0.80       0       1     312.1    2313.3   1.00         0       no     no
 * 08-V2        roman                         3         4    14        2     1.00       3       1     421.1   10001.3   1.04         0       no     no
 * 08-V2        value                         8         1    12        1     0.80       0       1     312.1    2313.3   1.00         0       no     no
 * 09-ORIG      bSearch                       4         8    17        3     1.44       0       2     479.2   15981.9   1.04         0       no     no
 * 09-V1        bSearch                       4         5    15        2     1.07       0       2     469.1   15645.4   1.04         0       no     no
 * 09-V2        bSearch                       2         1     4        0     0.00       1       2     173.9    2347.9   1.20         0       no     no
 * 10-ORIG      balanced                     15        28    26        4     2.44       5       1     938.7   26937.3   1.11         0       no     no
 * 10-V1        balanced                      6        10    17        3     1.53       6       1     707.2   16786.6   1.25         0       no     no
 * 10-V2        balanced                      6         8    14        3     1.29       7       1     649.7   14422.7   1.19         0       no     no
 * 10-V2        matches                       1         0     3        0     0.00       1       2     118.9    1159.7   1.29         0       no     no
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
 * Complexities: CC 5 | Cognitive 5 | Nesting 1 | LOC 15 | FanOut 0
 * Isolating: multiple exits, by flattening to an else-if chain but keeping one exit
 * ---------------------------------------------------------------------------------- */
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
 * ID: 01-V2
 * Function: Turns a numeric score into a letter grade.
 * Complexities: CC 5 | Cognitive 10 | Nesting 0 | LOC 4 | FanOut 0
 * Isolating: volume, by collapsing to a chained ternary at constant CC
 * ---------------------------------------------------------------------------------- */
public static String grade(int s) {
    return s >= 90 ? "A+" : s >= 80 ? "A" :
            s >= 65 ? "B" : s >= 50 ? "C" : "D";
}


/* ----------------------------------------------------------------------------------
 * ID: 01-V3
 * Function: Turns a numeric score into a letter grade.
 * Complexities: CC 5 | Cognitive 14 | Nesting 4 | LOC 21 | FanOut 0 | 1 comment
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
 * ID: 02-ORIG
 * Function: Checks a password for length, mixed case and a digit.
 * Complexities: CC 6 | Cognitive 2 | Nesting 1 | LOC 8 | FanOut 5
 * Isolating: baseline
 * ---------------------------------------------------------------------------------- */
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
 * Complexities: CC 6 | Cognitive 2 | Nesting 1 | LOC 8 | FanOut 5 | 1 comment
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
 * Complexities: CC 3 | Cognitive 3 | Nesting 1 | LOC 9 | FanOut 1
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
 * Complexities: CC 3 | Cognitive 3 | Nesting 1 | LOC 6 | FanOut 1
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
 * Complexities: CC 2 | Cognitive 1 | Nesting 1 | LOC 7 | FanOut 2
 *               Helper rowMax: CC 3, Cognitive 3, Nesting 2, LOC 9. Block totals CC 5, LOC 16
 * Isolating: extraction, where summed CC exceeds the original but no method is as deep
 * ---------------------------------------------------------------------------------- */
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
 * ID: 05-ORIG
 * Function: Removes duplicates from a list, keeping first appearance order.
 * Complexities: CC 5 | Cognitive 8 | Nesting 3 | LOC 15 | FanOut 4
 * Isolating: baseline
 * ---------------------------------------------------------------------------------- */
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
 * Isolating: naming, on a structurally hard method
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
 * Complexities: CC 5 | Cognitive 8 | Nesting 3 | LOC 15 | FanOut 4 | 2 comments
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
 * Complexities: CC 6 | Cognitive 7 | Nesting 2 | LOC 27 | FanOut 0 | 3 comments
 * Isolating: comment quality, helpful inline on a long method. Code token for token
 *            identical to 07-ORIG. This is the largest method in the set, so it tests
 *            whether comments pay off more when there is more to hold in your head
 * ---------------------------------------------------------------------------------- */
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
 * Complexities: CC 4 | Cognitive 5 | Nesting 2 | LOC 15 | FanOut 0
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
 * Complexities: CC 6 | Cognitive 10 | Nesting 3 | LOC 17 | FanOut 6
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
 * Complexities: CC 6 | Cognitive 8 | Nesting 3 | LOC 14 | FanOut 7
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
