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
