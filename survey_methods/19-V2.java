/* ----------------------------------------------------------------------------------
 * ID: 19-V2
 * Function: Binary searches a sorted array, returning an index or -1.
 * Complexities: CC 2 | Cognitive 1 | Nesting 0 | LOC 4 | FanOut 1
 * Isolating: control flow removal, traded for knowing what the library returns on a miss
 * ---------------------------------------------------------------------------------- */
// CHECK HERE i think this one is too reliant on java libraries again
import java.util.Arrays;
class S19_V2 {

public static int bSearch(int[] a, int t) {
    int i = Arrays.binarySearch(a, t);
    return i < 0 ? -1 : i;
}

    public static void main(String[] args) {
    }
}
