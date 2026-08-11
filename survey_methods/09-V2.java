import java.util.Arrays;

public static int bSearch(int[] a, int t) {
    int i = Arrays.binarySearch(a, t);
    return i < 0 ? -1 : i;
}
