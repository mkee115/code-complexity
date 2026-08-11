class S06_ORIG {

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

    public static void main(String[] args) {
    }
}
