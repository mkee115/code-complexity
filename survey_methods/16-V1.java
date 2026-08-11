class S16_V1 {

/* ----------------------------------------------------------------------------------
 * ID: 16-V1
 * Function: Merges two sorted arrays into one sorted array.
 * Complexities: CC 4 | Cognitive 5 | Nesting 2 | LOC 16 | FanOut 1
 * Isolating: branch count, by replacing the two tail loops with bulk copies
 * ---------------------------------------------------------------------------------- */
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

    public static void main(String[] args) {
    }
}
