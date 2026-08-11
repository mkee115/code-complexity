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
