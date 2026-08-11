class S02_V3 {

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

    public static void main(String[] args) {
    }
}
