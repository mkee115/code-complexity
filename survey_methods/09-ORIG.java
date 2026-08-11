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
