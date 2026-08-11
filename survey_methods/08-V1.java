/* ----------------------------------------------------------------------------------
 * ID: 08-V1
 * Function: Removes duplicates from a list, keeping first appearance order.
 * Complexities: CC 3 | Cognitive 3 | Nesting 2 | LOC 9 | FanOut 3
 * Isolating: branch count and nesting together, algorithm unchanged
 * ---------------------------------------------------------------------------------- */
import java.util.ArrayList;
import java.util.List;
class S08_V1 {

public static List<String> dedupe(List<String> in) {
    List<String> out = new ArrayList<>();
    for (String s : in) {
        if (!out.contains(s)) {
            out.add(s);
        }
    }
    return out;
}

    public static void main(String[] args) {
    }
}
