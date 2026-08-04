/*
ID         Method                 CC Cognitive   LOC  MaxNest  FanOut  Params    HalVol    HalEff AvgIdW
--------------------------------------------------------------------------------------------------------
01-ORIG    calc                    4         6    11        3       0       1     341.3   11263.6   1.00
01-V1      calc                    4         4     9        2       0       1     325.5   11252.5   1.00
01-V2      calc                    4         5    13        2       0       1     364.3   12596.1   1.00
01-V3      sumPositiveEvenValues   4         6    11        3       0       1     341.3   11263.6   1.18
02-ORIG    grade                   5        14    21        4       0       1     376.0    4512.4   1.00
02-V1      grade                   5         4    15        1       0       1     257.8    1890.8   1.00
02-V2      grade                   5         5    15        4       0       1     347.8    4174.0   1.00
02-V3      grade                   5         4     3        0       0       1     169.6    1357.1   1.00
02-V4      grade                   5        14    21        4       0       1     376.0    4512.4   1.00
02-V5      grade                   5        14    21        4       0       1     376.0    4512.4   1.00
03-ORIG    check                   6         2     8        1       5       1     338.6    4643.3   1.21
03-V1      check                   6         5    18        1       5       1     427.9    5760.7   1.25
03-V2      check                   4         1     3        0       3       1     125.1    1081.2   1.60
03-V2      hasMinLength            1         0     3        0       1       1      76.0     501.6   1.40
03-V2      hasLowerAndUpper        2         1     3        0       3       1     145.9    1605.4   1.64
03-V2      hasDigit                1         0     3        0       1       1      70.3     421.9   1.20
03-V3      check                   6         2     7        1       5       1     338.6    4643.3   1.21
04-ORIG    count                   7         4    10        2       2       1     375.0    6508.9   1.05
04-V1      count                   7         3    17        2       2       1     365.0    5601.3   1.07
04-V2      count                   3         3     9        2       3       1     277.3    4215.4   1.13
04-V3      countVowels             7         4    11        2       2       1     375.0    6508.9   1.25
05-ORIG    sd                      3         4     9        1       1       1     203.9    5352.4   1.00
05-V1      sd                      2         1     9        1       1       1     229.2    4126.5   1.00
05-V2      sd                      3         4     6        1       1       1     188.9    5618.9   1.00
06-ORIG    max                     4         6    11        3       0       1     413.7   11169.2   1.04
06-V1      max                     4         6    11        3       0       1     256.8    4364.9   1.07
06-V2      max                     2         2     7        1       2       1     224.7    3145.3   1.14
06-V2      rowMax                  3         3     9        2       0       1     194.5    3306.7   1.17
06-V3      max                     4         6    11        3       0       1     413.7   11169.2   1.04
07-ORIG    withdraw                5        11    23        3       1       2     549.7   10704.3   1.10
07-V1      withdraw                5         4    19        1       1       2     448.0    7093.5   1.13
07-V2      withdraw                5         4    17        1       2       2     444.6    6669.2   1.05
08-ORIG    dedupe                  5         8    15        3       4       1     620.6   14740.3   1.03
08-V1      dedupe                  3         3     9        2       2       1     282.0    5327.2   1.05
08-V2      dedupe                  1         0     3        0       0       1     126.7    1045.4   1.33
08-V3      removeDuplicates        5         8    15        3       4       1     620.6   14740.3   1.39
09-ORIG    words                   4         7    15        3       2       1     381.5    7248.0   1.06
09-V1      words                   3         3     9        2       2       1     213.6    2658.3   1.08
09-V2      words                   4         4    12        2       2       1     361.7    6871.5   1.05
09-V3      words                   4         7    15        3       2       1     381.5    7248.0   1.06
10-ORIG    price                   5        11    19        3       0       3     418.2    8402.8   1.00
10-V1      price                   5        11    19        3       0       3     418.2    8402.8   1.58
10-V2      price                   7         6    16        1       0       3     394.2    7919.9   1.00
10-V3      price                   5         4     4        0       0       3     252.6    3399.8   1.00
11-ORIG    sign                    3         5    13        2       0       1     220.4    4628.8   1.00
11-V1      sign                    3         3    11        2       0       1     211.8    4447.3   1.00
11-V2      sign                    3         2     3        0       0       1     108.4    1707.6   1.00
12-ORIG    leap                    4         9    17        3       0       1     325.5    5696.8   1.00
12-V1      leap                    3         2     3        0       0       1     136.2    1872.2   1.00
12-V2      leap                    3         2     9        1       0       1     188.9    1994.9   1.00
13-ORIG    rev                     2         1     7        1       2       1     239.7    3835.6   1.06
13-V1      rev                     1         0     3        0       2       1     100.0     666.7   1.25
13-V2      rev                     2         1     9        1       1       1     421.1   12250.4   1.07
14-ORIG    find                    4         6    11        3       0       2     317.3    7535.5   1.00
14-V1      find                    3         3     8        2       0       2     242.5    4850.0   1.00
14-V2      find                    4         4     9        2       0       2     301.2    7511.0   1.00
14-V3      find                    4         6    11        3       0       2     317.3    7535.5   1.00
15-ORIG    tally                   3         4    12        2       4       1     542.8   12892.5   1.06
15-V1      tally                   2         1     7        1       2       1     309.1    4851.0   1.14
15-V2      countByValue            3         4    12        2       4       1     542.8   12892.5   1.11
16-ORIG    merge                   6         7    27        2       0       2     840.0   57960.0   1.00
16-V1      merge                   4         5    16        2       1       2     795.0   46835.0   1.00
16-V2      merge                   1         0     7        0       2       2     385.4    8942.1   1.00
16-V3      merge                   6         7    27        2       0       2     840.0   57960.0   1.00
17-ORIG    sortIt                  4         6    13        3       1       1     544.7   19607.9   1.03
17-V1      sortIt                  4         6    11        3       2       1     460.7   14029.5   1.04
17-V1      swap                    1         0     5        0       0       3     179.3    3263.4   1.00
17-V2      sortIt                  4         6    16        3       1       1     569.8   19325.6   1.03
17-V3      sortIt                  1         0     5        0       2       1     148.7    1449.6   1.11
18-ORIG    roman                   4         8    16        3       3       1     519.8   15310.6   1.06
18-ORIG    value                   8         1    12        1       0       1     312.1    2313.3   1.00
18-V1      roman                   4         5    12        2       3       1     461.2   13145.6   1.07
18-V1      value                   8         1    12        1       0       1     312.1    2313.3   1.00
18-V2      roman                   3         4    14        2       3       1     421.1   10001.3   1.04
18-V2      value                   8         1    12        1       0       1     312.1    2313.3   1.00
19-ORIG    bs                      4         8    17        3       0       2     479.2   15981.9   1.00
19-V1      bs                      4         5    15        3       0       2     469.1   15645.4   1.00
19-V2      bs                      2         1     4        0       1       2     173.9    2347.9   1.10
20-ORIG    balanced                15        28    26        4       5       1     938.7   26937.3   1.11
20-V1      balanced                6        10    17        4       6       1     707.2   16786.6   1.25
20-V2      balanced                6         8    14        4       7       1     649.7   14422.7   1.19
20-V2      matches                 1         0     3        0       1       2     118.9    1159.7   1.29
20-V3      balanced                15        28    26        4       5       1     938.7   26937.3   1.11
*/



/* ----------------------------------------------------------------------------------
 * ID: 01-ORIG
 * Function: Sums the positive even values in an array.
 * Complexities: CC 4 | Cognitive 6 | Nesting 3 | LOC 11 | FanOut 0
 * Isolating: baseline
 * ---------------------------------------------------------------------------------- */
public static int calc(int[] d) {
    int t = 0;
    for (int i = 0; i < d.length; i++) {
        if (d[i] > 0) {
            if (d[i] % 2 == 0) {
                t = t + d[i];
            }
        }
    }
    return t;
}


/* ----------------------------------------------------------------------------------
 * ID: 01-V1
 * Function: Sums the positive even values in an array.
 * Complexities: CC 4 | Cognitive 4 | Nesting 2 | LOC 9 | FanOut 0
 * Isolating: nesting, by merging the two conditions with &&
 * ---------------------------------------------------------------------------------- */
public static int calc(int[] d) {
    int t = 0;
    for (int i = 0; i < d.length; i++) {
        if (d[i] > 0 && d[i] % 2 == 0) {
            t = t + d[i];
        }
    }
    return t;
}


/* ----------------------------------------------------------------------------------
 * ID: 01-V2
 * Function: Sums the positive even values in an array.
 * Complexities: CC 4 | Cognitive 5 | Nesting 2 | LOC 13 | FanOut 0
 * Isolating: nesting, by inverting both conditions into guard clauses. LOC rises here,
 *            unlike 01-V1, which lets you separate depth from size
 * ---------------------------------------------------------------------------------- */
public static int calc(int[] d) {
    int t = 0;
    for (int i = 0; i < d.length; i++) {
        if (d[i] <= 0) {
            continue;
        }
        if (d[i] % 2 != 0) {
            continue;
        }
        t = t + d[i];
    }
    return t;
}


/* ----------------------------------------------------------------------------------
 * ID: 01-V3
 * Function: Sums the positive even values in an array.
 * Complexities: CC 4 | Cognitive 6 | Nesting 3 | LOC 11 | FanOut 0
 * Isolating: naming, structure identical to 01-ORIG
 * ---------------------------------------------------------------------------------- */
public static int sumPositiveEvenValues(int[] values) {
    int total = 0;
    for (int index = 0; index < values.length; index++) {
        if (values[index] > 0) {
            if (values[index] % 2 == 0) {
                total = total + values[index];
            }
        }
    }
    return total;
}


/* ----------------------------------------------------------------------------------
 * ID: 02-ORIG
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
 * ID: 02-V1
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
 * ID: 02-V2
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
 * ID: 02-V3
 * Function: Turns a numeric score into a letter grade.
 * Complexities: CC 5 | Cognitive 10 | Nesting 4 | LOC 3 | FanOut 0
 * Isolating: volume, by collapsing to a chained ternary at constant CC. Cognitive is
 *            10 under a strict reading of the nesting rule and 4 if a ternary chain is
 *            treated as flat, so measure it with your own extractor
 * ---------------------------------------------------------------------------------- */
public static String grade(int s) {
    return s >= 90 ? "A+" : s >= 80 ? "A" : s >= 65 ? "B" : s >= 50 ? "C" : "D";
}


/* ----------------------------------------------------------------------------------
 * ID: 02-V4
 * Function: Turns a numeric score into a letter grade.
 * Complexities: CC 5 | Cognitive 14 | Nesting 4 | LOC 21 | FanOut 0 | 4 comment lines
 * Isolating: comment quality, accurate summary. Code token for token identical to
 *            02-ORIG with a correct header comment stating the bands
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
 * ID: 02-V5
 * Function: Turns a numeric score into a letter grade.
 * Complexities: CC 5 | Cognitive 14 | Nesting 4 | LOC 21 | FanOut 0 | 8 comment lines
 * Isolating: comment quality, redundant noise. Code identical to 02-ORIG, every
 *            comment restates the syntax of the line below it and adds nothing.
 *            Pair against 02-V4 to separate comment presence from comment usefulness
 * ---------------------------------------------------------------------------------- */
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
 * ID: 03-ORIG
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
 * ID: 03-V1
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
 * ID: 03-V2
 * Function: Checks a password for length, mixed case and a digit.
 * Complexities: CC 4 | Cognitive 1 | Nesting 0 | LOC 3 | FanOut 4
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
 * ID: 03-V3
 * Function: Checks a password for length, mixed case and a digit.
 * Complexities: CC 6 | Cognitive 2 | Nesting 1 | LOC 7 | FanOut 5
 * Isolating: layout, identical tokens to 03-ORIG on one line instead of two
 * ---------------------------------------------------------------------------------- */
public static boolean check(String p) {
    boolean ok = false;
    if (p != null && p.length() >= 8 && !p.equals(p.toLowerCase()) && !p.equals(p.toUpperCase()) && p.matches(".*[0-9].*")) {
        ok = true;
    }
    return ok;
}


/* ----------------------------------------------------------------------------------
 * ID: 04-ORIG
 * Function: Counts the lower case vowels in a string.
 * Complexities: CC 7 | Cognitive 4 | Nesting 2 | LOC 10 | FanOut 2
 * Isolating: baseline
 * ---------------------------------------------------------------------------------- */
public static int count(String s) {
    int n = 0;
    for (int i = 0; i < s.length(); i++) {
        char c = s.charAt(i);
        if (c == 'a' || c == 'e' || c == 'i' || c == 'o' || c == 'u') {
            n++;
        }
    }
    return n;
}


/* ----------------------------------------------------------------------------------
 * ID: 04-V1
 * Function: Counts the lower case vowels in a string.
 * Complexities: CC 7 | Cognitive 3 | Nesting 2 | LOC 17 | FanOut 2
 * Isolating: construct type, a switch scoring the same CC as the || chain it replaces
 * ---------------------------------------------------------------------------------- */
public static int count(String s) {
    int n = 0;
    for (int i = 0; i < s.length(); i++) {
        switch (s.charAt(i)) {
            case 'a':
            case 'e':
            case 'i':
            case 'o':
            case 'u':
                n++;
                break;
            default:
                break;
        }
    }
    return n;
}


/* ----------------------------------------------------------------------------------
 * ID: 04-V2
 * Function: Counts the lower case vowels in a string.
 * Complexities: CC 3 | Cognitive 3 | Nesting 2 | LOC 9 | FanOut 3
 * Isolating: branch count, traded for implicit knowledge of what indexOf returns
 * ---------------------------------------------------------------------------------- */
public static int count(String s) {
    int n = 0;
    for (int i = 0; i < s.length(); i++) {
        if ("aeiou".indexOf(s.charAt(i)) >= 0) {
            n++;
        }
    }
    return n;
}


/* ----------------------------------------------------------------------------------
 * ID: 04-V3
 * Function: Counts the lower case vowels in a string.
 * Complexities: CC 7 | Cognitive 4 | Nesting 2 | LOC 11 | FanOut 2
 * Isolating: naming and layout, control flow identical to 04-ORIG
 * ---------------------------------------------------------------------------------- */
public static int countVowels(String text) {
    int vowelCount = 0;
    for (int position = 0; position < text.length(); position++) {
        char current = text.charAt(position);
        if (current == 'a' || current == 'e' || current == 'i'
                || current == 'o' || current == 'u') {
            vowelCount++;
        }
    }
    return vowelCount;
}


/* ----------------------------------------------------------------------------------
 * ID: 05-ORIG
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
 * ID: 05-V1
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
 * ID: 05-V2
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
 * ID: 06-ORIG
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
 * ID: 06-V1
 * Function: Finds the largest value in a 2D array.
 * Complexities: CC 4 | Cognitive 6 | Nesting 3 | LOC 11 | FanOut 0
 * Isolating: volume alone, since enhanced for loops move only Halstead vocabulary
 * ---------------------------------------------------------------------------------- */
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
 * ID: 06-V2
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
 * ID: 06-V3
 * Function: Finds the largest value in a 2D array.
 * Complexities: CC 4 | Cognitive 6 | Nesting 3 | LOC 11 | FanOut 0 | 3 comment lines
 * Isolating: comment quality, helpful inline. Code token for token identical to 06-ORIG,
 *            each comment explains why rather than what
 * ---------------------------------------------------------------------------------- */
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
 * ID: 07-ORIG
 * Function: Withdraws an amount from an account and returns a status word.
 * Complexities: CC 5 | Cognitive 11 | Nesting 3 | LOC 23 | FanOut 1
 * Isolating: baseline
 * ---------------------------------------------------------------------------------- */
class Account {
    double balance;
}

public static String withdraw(Account a, String amt) {
    String msg;
    if (a != null) {
        try {
            double v = Double.parseDouble(amt);
            if (v > 0) {
                if (a.balance >= v) {
                    a.balance = a.balance - v;
                    msg = "ok";
                } else {
                    msg = "insufficient";
                }
            } else {
                msg = "bad amount";
            }
        } catch (NumberFormatException e) {
            msg = "not a number";
        }
    } else {
        msg = "no account";
    }
    return msg;
}


/* ----------------------------------------------------------------------------------
 * ID: 07-V1
 * Function: Withdraws an amount from an account and returns a status word.
 * Complexities: CC 5 | Cognitive 4 | Nesting 1 | LOC 19 | FanOut 1
 * Isolating: nesting, held against constant CC. The strongest depth pair in the set
 * ---------------------------------------------------------------------------------- */
class Account {
    double balance;
}

public static String withdraw(Account a, String amt) {
    if (a == null) {
        return "no account";
    }
    double v;
    try {
        v = Double.parseDouble(amt);
    } catch (NumberFormatException e) {
        return "not a number";
    }
    if (v <= 0) {
        return "bad amount";
    }
    if (a.balance < v) {
        return "insufficient";
    }
    a.balance = a.balance - v;
    return "ok";
}


/* ----------------------------------------------------------------------------------
 * ID: 07-V2
 * Function: Withdraws an amount from an account and returns a status word.
 * Complexities: CC 5 | Cognitive 4 | Nesting 1 | LOC 17 | FanOut 2
 * Isolating: exception handling swapped for a regex. Pair against 07-V1, not the original.
 *            Diverges from the original only on exponent notation such as 1e3
 * ---------------------------------------------------------------------------------- */
class Account {
    double balance;
}

public static String withdraw(Account a, String amt) {
    if (a == null) {
        return "no account";
    }
    if (!amt.matches("-?\\d+(\\.\\d+)?")) {
        return "not a number";
    }
    double v = Double.parseDouble(amt);
    if (v <= 0) {
        return "bad amount";
    }
    if (a.balance < v) {
        return "insufficient";
    }
    a.balance = a.balance - v;
    return "ok";
}


/* ----------------------------------------------------------------------------------
 * ID: 08-ORIG
 * Function: Removes duplicates from a list, keeping first appearance order.
 * Complexities: CC 5 | Cognitive 8 | Nesting 3 | LOC 15 | FanOut 5
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
 * ID: 08-V1
 * Function: Removes duplicates from a list, keeping first appearance order.
 * Complexities: CC 3 | Cognitive 3 | Nesting 2 | LOC 9 | FanOut 3
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
 * ID: 08-V2
 * Function: Removes duplicates from a list, keeping first appearance order.
 * Complexities: CC 1 | Cognitive 0 | Nesting 0 | LOC 3 | FanOut 2
 * Isolating: library knowledge, at the floor of every structural metric
 * ---------------------------------------------------------------------------------- */
import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.List;

public static List<String> dedupe(List<String> in) {
    return new ArrayList<>(new LinkedHashSet<>(in));
}


/* ----------------------------------------------------------------------------------
 * ID: 08-V3
 * Function: Removes duplicates from a list, keeping first appearance order.
 * Complexities: CC 5 | Cognitive 8 | Nesting 3 | LOC 15 | FanOut 5
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
 * ID: 09-ORIG
 * Function: Counts space separated words in a string.
 * Complexities: CC 4 | Cognitive 7 | Nesting 3 | LOC 15 | FanOut 2
 * Isolating: baseline
 * ---------------------------------------------------------------------------------- */
public static int words(String t) {
    int c = 0;
    boolean in = false;
    for (int i = 0; i < t.length(); i++) {
        if (t.charAt(i) != ' ') {
            if (!in) {
                c++;
                in = true;
            }
        } else {
            in = false;
        }
    }
    return c;
}


/* ----------------------------------------------------------------------------------
 * ID: 09-V1
 * Function: Counts space separated words in a string.
 * Complexities: CC 3 | Cognitive 3 | Nesting 2 | LOC 9 | FanOut 3
 * Isolating: branch count and nesting, at the cost of knowing how split treats empty pieces
 * ---------------------------------------------------------------------------------- */
public static int words(String t) {
    int c = 0;
    for (String part : t.split(" ")) {
        if (!part.isEmpty()) {
            c++;
        }
    }
    return c;
}


/* ----------------------------------------------------------------------------------
 * ID: 09-V2
 * Function: Counts space separated words in a string.
 * Complexities: CC 4 | Cognitive 4 | Nesting 2 | LOC 12 | FanOut 2
 * Isolating: nesting, with the algorithm and CC both held fixed
 * ---------------------------------------------------------------------------------- */
public static int words(String t) {
    int c = 0;
    boolean in = false;
    for (int i = 0; i < t.length(); i++) {
        boolean space = t.charAt(i) == ' ';
        if (!space && !in) {
            c++;
        }
        in = !space;
    }
    return c;
}


/* ----------------------------------------------------------------------------------
 * ID: 09-V3
 * Function: Counts space separated words in a string.
 * Complexities: CC 4 | Cognitive 7 | Nesting 3 | LOC 15 | FanOut 2 | 4 comment lines
 * Isolating: comment quality, actively misleading. Code token for token identical to
 *            09-ORIG. Every comment is wrong: c holds words not spaces, in is true
 *            inside a word not after one, nothing skips punctuation, and the last
 *            comment describes the wrong event. Pair against 09-ORIG to measure the
 *            cost of a wrong comment against no comment at all
 * ---------------------------------------------------------------------------------- */
public static int words(String t) {
    // number of spaces seen so far
    int c = 0;
    // true when the previous character was a space
    boolean in = false;
    for (int i = 0; i < t.length(); i++) {
        // skip over any punctuation
        if (t.charAt(i) != ' ') {
            if (!in) {
                c++;
                in = true;
            }
        } else {
            // we have reached the end of the string
            in = false;
        }
    }
    return c;
}


/* ----------------------------------------------------------------------------------
 * ID: 10-ORIG
 * Function: Prices an order after quantity and membership discounts.
 * Complexities: CC 5 | Cognitive 11 | Nesting 3 | LOC 19 | FanOut 0
 * Isolating: baseline
 * ---------------------------------------------------------------------------------- */
public static double price(double p, int q, boolean m) {
    double r = p * q;
    if (q > 100) {
        if (m) {
            r = r * 0.75;
        } else {
            r = r * 0.85;
        }
    } else {
        if (q > 10) {
            if (m) {
                r = r * 0.9;
            } else {
                r = r * 0.95;
            }
        }
    }
    return r;
}


/* ----------------------------------------------------------------------------------
 * ID: 10-V1
 * Function: Prices an order after quantity and membership discounts.
 * Complexities: CC 5 | Cognitive 11 | Nesting 3 | LOC 19 | FanOut 0
 * Isolating: magic numbers and naming, with every listed metric held constant
 * ---------------------------------------------------------------------------------- */
private static final double MEMBER_BULK_RATE = 0.75;
private static final double STANDARD_BULK_RATE = 0.85;
private static final double MEMBER_VOLUME_RATE = 0.90;
private static final double STANDARD_VOLUME_RATE = 0.95;
private static final int BULK_THRESHOLD = 100;
private static final int VOLUME_THRESHOLD = 10;

public static double price(double unitPrice, int quantity, boolean isMember) {
    double total = unitPrice * quantity;
    if (quantity > BULK_THRESHOLD) {
        if (isMember) {
            total = total * MEMBER_BULK_RATE;
        } else {
            total = total * STANDARD_BULK_RATE;
        }
    } else {
        if (quantity > VOLUME_THRESHOLD) {
            if (isMember) {
                total = total * MEMBER_VOLUME_RATE;
            } else {
                total = total * STANDARD_VOLUME_RATE;
            }
        }
    }
    return total;
}


/* ----------------------------------------------------------------------------------
 * ID: 10-V2
 * Function: Prices an order after quantity and membership discounts.
 * Complexities: CC 7 | Cognitive 6 | Nesting 1 | LOC 16 | FanOut 0
 * Isolating: metric disagreement, CC rises while cognitive and nesting both fall
 * ---------------------------------------------------------------------------------- */
public static double price(double p, int q, boolean m) {
    double r = p * q;
    if (q > 100 && m) {
        return r * 0.75;
    }
    if (q > 100) {
        return r * 0.85;
    }
    if (q > 10 && m) {
        return r * 0.9;
    }
    if (q > 10) {
        return r * 0.95;
    }
    return r;
}


/* ----------------------------------------------------------------------------------
 * ID: 10-V3
 * Function: Prices an order after quantity and membership discounts.
 * Complexities: CC 5 | Cognitive 8 | Nesting 3 | LOC 4 | FanOut 0
 * Isolating: volume, by collapsing the decision into one nested ternary at constant CC.
 *            Cognitive is implementation dependent, see 02-V3
 * ---------------------------------------------------------------------------------- */
public static double price(double p, int q, boolean m) {
    double rate = q > 100 ? (m ? 0.75 : 0.85) : q > 10 ? (m ? 0.9 : 0.95) : 1.0;
    return p * q * rate;
}


/* ----------------------------------------------------------------------------------
 * ID: 11-ORIG
 * Function: Returns -1, 0 or 1 for the sign of a number.
 * Complexities: CC 3 | Cognitive 5 | Nesting 2 | LOC 13 | FanOut 0
 * Isolating: baseline
 * ---------------------------------------------------------------------------------- */
public static int sign(int n) {
    int r;
    if (n > 0) {
        r = 1;
    } else {
        if (n < 0) {
            r = -1;
        } else {
            r = 0;
        }
    }
    return r;
}


/* ----------------------------------------------------------------------------------
 * ID: 11-V1
 * Function: Returns -1, 0 or 1 for the sign of a number.
 * Complexities: CC 3 | Cognitive 3 | Nesting 1 | LOC 11 | FanOut 0
 * Isolating: nesting, by folding the inner if into an else-if
 * ---------------------------------------------------------------------------------- */
public static int sign(int n) {
    int r;
    if (n > 0) {
        r = 1;
    } else if (n < 0) {
        r = -1;
    } else {
        r = 0;
    }
    return r;
}


/* ----------------------------------------------------------------------------------
 * ID: 11-V2
 * Function: Returns -1, 0 or 1 for the sign of a number.
 * Complexities: CC 3 | Cognitive 3 | Nesting 2 | LOC 3 | FanOut 0
 * Isolating: volume, by collapsing to a chained ternary at constant CC
 * ---------------------------------------------------------------------------------- */
public static int sign(int n) {
    return n > 0 ? 1 : n < 0 ? -1 : 0;
}


/* ----------------------------------------------------------------------------------
 * ID: 12-ORIG
 * Function: Decides whether a year is a leap year.
 * Complexities: CC 4 | Cognitive 9 | Nesting 3 | LOC 17 | FanOut 0
 * Isolating: baseline
 * ---------------------------------------------------------------------------------- */
public static boolean leap(int y) {
    boolean r;
    if (y % 4 == 0) {
        if (y % 100 == 0) {
            if (y % 400 == 0) {
                r = true;
            } else {
                r = false;
            }
        } else {
            r = true;
        }
    } else {
        r = false;
    }
    return r;
}


/* ----------------------------------------------------------------------------------
 * ID: 12-V1
 * Function: Decides whether a year is a leap year.
 * Complexities: CC 3 | Cognitive 2 | Nesting 0 | LOC 3 | FanOut 0
 * Isolating: branch count, by turning the whole decision into one boolean expression
 * ---------------------------------------------------------------------------------- */
public static boolean leap(int y) {
    return y % 4 == 0 && (y % 100 != 0 || y % 400 == 0);
}


/* ----------------------------------------------------------------------------------
 * ID: 12-V2
 * Function: Decides whether a year is a leap year.
 * Complexities: CC 3 | Cognitive 2 | Nesting 1 | LOC 9 | FanOut 0
 * Isolating: nesting, by reordering the rules into guard clauses
 * ---------------------------------------------------------------------------------- */
public static boolean leap(int y) {
    if (y % 400 == 0) {
        return true;
    }
    if (y % 100 == 0) {
        return false;
    }
    return y % 4 == 0;
}


/* ----------------------------------------------------------------------------------
 * ID: 13-ORIG
 * Function: Reverses a string.
 * Complexities: CC 2 | Cognitive 1 | Nesting 1 | LOC 7 | FanOut 1
 * Isolating: baseline
 * ---------------------------------------------------------------------------------- */
public static String rev(String s) {
    String r = "";
    for (int i = s.length() - 1; i >= 0; i--) {
        r = r + s.charAt(i);
    }
    return r;
}


/* ----------------------------------------------------------------------------------
 * ID: 13-V1
 * Function: Reverses a string.
 * Complexities: CC 1 | Cognitive 0 | Nesting 0 | LOC 3 | FanOut 3
 * Isolating: control flow removal, traded entirely for library knowledge
 * ---------------------------------------------------------------------------------- */
public static String rev(String s) {
    return new StringBuilder(s).reverse().toString();
}


/* ----------------------------------------------------------------------------------
 * ID: 13-V2
 * Function: Reverses a string.
 * Complexities: CC 2 | Cognitive 1 | Nesting 1 | LOC 9 | FanOut 2
 * Isolating: volume, since in-place swapping moves only Halstead terms and LOC
 * ---------------------------------------------------------------------------------- */
public static String rev(String s) {
    char[] c = s.toCharArray();
    for (int i = 0; i < c.length / 2; i++) {
        char t = c[i];
        c[i] = c[c.length - 1 - i];
        c[c.length - 1 - i] = t;
    }
    return new String(c);
}


/* ----------------------------------------------------------------------------------
 * ID: 14-ORIG
 * Function: Returns the index of the first match in an array, or -1.
 * Complexities: CC 4 | Cognitive 6 | Nesting 3 | LOC 11 | FanOut 0
 * Isolating: baseline
 * ---------------------------------------------------------------------------------- */
public static int find(int[] a, int t) {
    int idx = -1;
    for (int i = 0; i < a.length; i++) {
        if (a[i] == t) {
            if (idx == -1) {
                idx = i;
            }
        }
    }
    return idx;
}


/* ----------------------------------------------------------------------------------
 * ID: 14-V1
 * Function: Returns the index of the first match in an array, or -1.
 * Complexities: CC 3 | Cognitive 3 | Nesting 2 | LOC 8 | FanOut 0
 * Isolating: branch count and nesting, by returning as soon as the match is found
 * ---------------------------------------------------------------------------------- */
public static int find(int[] a, int t) {
    for (int i = 0; i < a.length; i++) {
        if (a[i] == t) {
            return i;
        }
    }
    return -1;
}


/* ----------------------------------------------------------------------------------
 * ID: 14-V2
 * Function: Returns the index of the first match in an array, or -1.
 * Complexities: CC 4 | Cognitive 4 | Nesting 2 | LOC 9 | FanOut 0
 * Isolating: nesting only, with CC and the single exit point both held
 * ---------------------------------------------------------------------------------- */
public static int find(int[] a, int t) {
    int idx = -1;
    for (int i = 0; i < a.length; i++) {
        if (a[i] == t && idx == -1) {
            idx = i;
        }
    }
    return idx;
}


/* ----------------------------------------------------------------------------------
 * ID: 14-V3
 * Function: Returns the index of the first match in an array, or -1.
 * Complexities: CC 4 | Cognitive 6 | Nesting 3 | LOC 11 | FanOut 0 | 6 comment lines
 * Isolating: comment quality, line by line restatement. Code token for token identical
 *            to 14-ORIG. Each comment translates the line below it into English and
 *            explains nothing, on an easier method than 02-V5 so you can test whether
 *            comment noise costs more or less as structure gets harder
 * ---------------------------------------------------------------------------------- */
public static int find(int[] a, int t) {
    // set idx to minus one
    int idx = -1;
    // loop i from zero up to the length of a
    for (int i = 0; i < a.length; i++) {
        // if the element at i equals t
        if (a[i] == t) {
            // if idx is still minus one
            if (idx == -1) {
                // set idx to i
                idx = i;
            }
        }
    }
    // return idx
    return idx;
}


/* ----------------------------------------------------------------------------------
 * ID: 15-ORIG
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
 * ID: 15-V1
 * Function: Counts how many times each string appears in a list.
 * Complexities: CC 2 | Cognitive 1 | Nesting 1 | LOC 7 | FanOut 3
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
 * ID: 15-V2
 * Function: Counts how many times each string appears in a list.
 * Complexities: CC 3 | Cognitive 4 | Nesting 2 | LOC 12 | FanOut 4
 * Isolating: naming, structure identical to 15-ORIG
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
 * ID: 16-ORIG
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
 * ID: 16-V1
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
 * ID: 16-V2
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
 * ID: 16-V3
 * Function: Merges two sorted arrays into one sorted array.
 * Complexities: CC 6 | Cognitive 7 | Nesting 2 | LOC 27 | FanOut 0 | 3 comment lines
 * Isolating: comment quality, helpful inline on a long method. Code token for token
 *            identical to 16-ORIG. This is the largest method in the set, so it tests
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
 * ID: 17-ORIG
 * Function: Returns a sorted copy of an array.
 * Complexities: CC 4 | Cognitive 6 | Nesting 3 | LOC 13 | FanOut 1
 * Isolating: baseline
 * ---------------------------------------------------------------------------------- */
public static int[] sortIt(int[] input) {
    int[] a = input.clone();
    for (int i = 0; i < a.length; i++) {
        for (int j = 0; j < a.length - 1; j++) {
            if (a[j] > a[j + 1]) {
                int t = a[j];
                a[j] = a[j + 1];
                a[j + 1] = t;
            }
        }
    }
    return a;
}


/* ----------------------------------------------------------------------------------
 * ID: 17-V1
 * Function: Returns a sorted copy of an array.
 * Complexities: CC 4 | Cognitive 6 | Nesting 3 | LOC 11 | FanOut 2
 *               Helper swap: CC 1, LOC 5. Block totals CC 5, LOC 16
 * Isolating: volume, since extracting the swap leaves all three control flow metrics untouched
 * ---------------------------------------------------------------------------------- */
public static int[] sortIt(int[] input) {
    int[] a = input.clone();
    for (int i = 0; i < a.length; i++) {
        for (int j = 0; j < a.length - 1; j++) {
            if (a[j] > a[j + 1]) {
                swap(a, j, j + 1);
            }
        }
    }
    return a;
}

private static void swap(int[] a, int x, int y) {
    int t = a[x];
    a[x] = a[y];
    a[y] = t;
}


/* ----------------------------------------------------------------------------------
 * ID: 17-V2
 * Function: Returns a sorted copy of an array.
 * Complexities: CC 4 | Cognitive 6 | Nesting 3 | LOC 16 | FanOut 1
 * Isolating: loop idiom, a flag driven while replacing the outer counted loop at equal metrics
 * ---------------------------------------------------------------------------------- */
public static int[] sortIt(int[] input) {
    int[] a = input.clone();
    boolean swapped = true;
    while (swapped) {
        swapped = false;
        for (int j = 0; j < a.length - 1; j++) {
            if (a[j] > a[j + 1]) {
                int t = a[j];
                a[j] = a[j + 1];
                a[j + 1] = t;
                swapped = true;
            }
        }
    }
    return a;
}


/* ----------------------------------------------------------------------------------
 * ID: 17-V3
 * Function: Returns a sorted copy of an array.
 * Complexities: CC 1 | Cognitive 0 | Nesting 0 | LOC 5 | FanOut 2
 * Isolating: control flow removal, at the floor of every structural metric
 * ---------------------------------------------------------------------------------- */
import java.util.Arrays;

public static int[] sortIt(int[] input) {
    int[] a = input.clone();
    Arrays.sort(a);
    return a;
}


/* ----------------------------------------------------------------------------------
 * ID: 18-ORIG
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
 * ID: 18-V1
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
 * ID: 18-V2
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
 * ID: 19-ORIG
 * Function: Binary searches a sorted array, returning an index or -1.
 * Complexities: CC 4 | Cognitive 8 | Nesting 3 | LOC 17 | FanOut 0
 * Isolating: baseline
 * ---------------------------------------------------------------------------------- */
public static int bs(int[] a, int t) {
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
 * ID: 19-V1
 * Function: Binary searches a sorted array, returning an index or -1.
 * Complexities: CC 4 | Cognitive 5 | Nesting 2 | LOC 15 | FanOut 0
 * Isolating: nesting, by folding the inner if into an else-if at constant CC
 * ---------------------------------------------------------------------------------- */
public static int bs(int[] a, int t) {
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
 * ID: 19-V2
 * Function: Binary searches a sorted array, returning an index or -1.
 * Complexities: CC 2 | Cognitive 1 | Nesting 0 | LOC 4 | FanOut 1
 * Isolating: control flow removal, traded for knowing what the library returns on a miss
 * ---------------------------------------------------------------------------------- */
import java.util.Arrays;

public static int bs(int[] a, int t) {
    int i = Arrays.binarySearch(a, t);
    return i < 0 ? -1 : i;
}


/* ----------------------------------------------------------------------------------
 * ID: 20-ORIG
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
 * ID: 20-V1
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
 * ID: 20-V2
 * Function: Checks whether brackets in a string are balanced and correctly nested.
 * Complexities: CC 6 | Cognitive 8 | Nesting 3 | LOC 14 | FanOut 6
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
 * ID: 20-V3
 * Function: Checks whether brackets in a string are balanced and correctly nested.
 * Complexities: CC 15 | Cognitive 28 | Nesting 4 | LOC 26 | FanOut 5 | 6 comment lines
 * Isolating: comment quality, accurate summary plus signposts, on the hardest method in
 *            the set. Code token for token identical to 20-ORIG. Pair against 20-ORIG to
 *            ask whether a good comment is worth more than a large structural improvement,
 *            since 20-V1 halves CC on the same method
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