class S16_ORIG {

/* ----------------------------------------------------------------------------------
 * ID: 16-ORIG
 * Function: Merges two sorted arrays into one sorted array.
 * Complexities: CC 6 | Cognitive 7 | Nesting 2 | LOC 27 | FanOut 0
 * Isolating: baseline
 * ---------------------------------------------------------------------------------- */
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

    public static void main(String[] args) {
    }
}
