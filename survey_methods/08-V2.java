/* ----------------------------------------------------------------------------------
 * ID: 08-V2
 * Function: Removes duplicates from a list, keeping first appearance order.
 * Complexities: CC 1 | Cognitive 0 | Nesting 0 | LOC 3 | FanOut 2
 * Isolating: library knowledge, at the floor of every structural metric
 * ---------------------------------------------------------------------------------- */
// CHECK HERE idk i think this one may be too based on utilising java libraries instead of 
// the actual algorithm
import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.List;
class S08_V2 {

public static List<String> dedupe(List<String> in) {
    return new ArrayList<>(new LinkedHashSet<>(in));
}

    public static void main(String[] args) {
    }
}
