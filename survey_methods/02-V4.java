class S02_V4 {

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

    public static void main(String[] args) {
    }
}
