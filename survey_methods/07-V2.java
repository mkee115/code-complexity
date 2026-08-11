import java.util.Arrays;

public static int[] merge(int[] a, int[] b) {
    int[] out = new int[a.length + b.length];
    System.arraycopy(a, 0, out, 0, a.length);
    System.arraycopy(b, 0, out, a.length, b.length);
    Arrays.sort(out);
    return out;
}
