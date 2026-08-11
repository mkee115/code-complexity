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
