class S02_ORIG {

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

    public static void main(String[] args) {
    }
}
