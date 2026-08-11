class S06_V2 {

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

    public static void main(String[] args) {
    }
}
