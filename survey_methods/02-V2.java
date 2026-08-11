class S02_V2 {

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

    public static void main(String[] args) {
    }
}
