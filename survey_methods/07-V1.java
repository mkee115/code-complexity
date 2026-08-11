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
