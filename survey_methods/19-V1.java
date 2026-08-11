class S19_V1 {

/* ----------------------------------------------------------------------------------
 * ID: 19-V1
 * Function: Binary searches a sorted array, returning an index or -1.
 * Complexities: CC 4 | Cognitive 5 | Nesting 2 | LOC 15 | FanOut 0
 * Isolating: nesting, by folding the inner if into an else-if at constant CC
 * ---------------------------------------------------------------------------------- */
public static int bSearch(int[] a, int t) {
    int lo = 0;
    int hi = a.length - 1;
    while (lo <= hi) {
        int mid = (lo + hi) / 2;
        if (a[mid] == t) {
            return mid;
        } else if (a[mid] < t) {
            lo = mid + 1;
        } else {
            hi = mid - 1;
        }
    }
    return -1;
}

    public static void main(String[] args) {
    }
}
