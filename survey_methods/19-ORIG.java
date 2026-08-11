class S19_ORIG {

/* ----------------------------------------------------------------------------------
 * ID: 19-ORIG
 * Function: Binary searches a sorted array, returning an index or -1.
 * Complexities: CC 4 | Cognitive 8 | Nesting 3 | LOC 17 | FanOut 0
 * Isolating: baseline
 * ---------------------------------------------------------------------------------- */
// CHECK HERE prob shouldnt name it 'bs' for the study, love this method tho
public static int bSearch(int[] a, int t) {
    int lo = 0;
    int hi = a.length - 1;
    while (lo <= hi) {
        int mid = (lo + hi) / 2;
        if (a[mid] == t) {
            return mid;
        } else {
            if (a[mid] < t) {
                lo = mid + 1;
            } else {
                hi = mid - 1;
            }
        }
    }
    return -1;
}

    public static void main(String[] args) {
    }
}
