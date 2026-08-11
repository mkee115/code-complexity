/* ----------------------------------------------------------------------------------
 * ID: 08-ORIG
 * Function: Removes duplicates from a list, keeping first appearance order.
 * Complexities: CC 5 | Cognitive 8 | Nesting 3 | LOC 15 | FanOut 5
 * Isolating: baseline
 * ---------------------------------------------------------------------------------- */
import java.util.ArrayList;
import java.util.List;
class S08_ORIG {

public static List<String> dedupe(List<String> in) {
    List<String> out = new ArrayList<>();
    for (int i = 0; i < in.size(); i++) {
        boolean found = false;
        for (int j = 0; j < out.size(); j++) {
            if (in.get(i).equals(out.get(j))) {
                found = true;
            }
        }
        if (!found) {
            out.add(in.get(i));
        }
    }
    return out;
}

    public static void main(String[] args) {
    }
}
