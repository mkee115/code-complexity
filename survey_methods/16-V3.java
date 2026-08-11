class S16_V3 {

/* ----------------------------------------------------------------------------------
 * ID: 16-V3
 * Function: Merges two sorted arrays into one sorted array.
 * Complexities: CC 6 | Cognitive 7 | Nesting 2 | LOC 27 | FanOut 0 | 3 comment lines
 * Isolating: comment quality, helpful inline on a long method. Code token for token
 *            identical to 16-ORIG. This is the largest method in the set, so it tests
 *            whether comments pay off more when there is more to hold in your head
 * ---------------------------------------------------------------------------------- */
// CHECK HERE love this one
public static int[] merge(int[] a, int[] b) {
    int[] out = new int[a.length + b.length];
    int i = 0;
    int j = 0;
    int k = 0;
    // take the smaller of the two front elements until one side runs out
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
    // exactly one of the next two loops runs, draining whatever is left over
    while (i < a.length) {
        out[k] = a[i];
        i++;
        k++;
    }
    // both sides are already sorted, so the leftovers can be copied straight across
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
