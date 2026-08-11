/* ----------------------------------------------------------------------------------
 * ID: 16-V2
 * Function: Merges two sorted arrays into one sorted array.
 * Complexities: CC 1 | Cognitive 0 | Nesting 0 | LOC 7 | FanOut 2
 * Isolating: control flow removal, at the cost of doing asymptotically more work
 * ---------------------------------------------------------------------------------- */
// CHECK HERE relies on java libaries too much i reckon
import java.util.Arrays;
class S16_V2 {

public static int[] merge(int[] a, int[] b) {
    int[] out = new int[a.length + b.length];
    System.arraycopy(a, 0, out, 0, a.length);
    System.arraycopy(b, 0, out, a.length, b.length);
    Arrays.sort(out);
    return out;
}

    public static void main(String[] args) {
    }
}
