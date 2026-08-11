/* ----------------------------------------------------------------------------------
 * ID: 15-ORIG
 * Function: Counts how many times each string appears in a list.
 * Complexities: CC 3 | Cognitive 4 | Nesting 2 | LOC 12 | FanOut 4
 * Isolating: baseline
 * ---------------------------------------------------------------------------------- */
import java.util.HashMap;
import java.util.List;
import java.util.Map;
class S15_ORIG {

public static Map<String, Integer> tally(List<String> items) {
    Map<String, Integer> m = new HashMap<>();
    for (int i = 0; i < items.size(); i++) {
        String k = items.get(i);
        if (m.containsKey(k)) {
            m.put(k, m.get(k) + 1);
        } else {
            m.put(k, 1);
        }
    }
    return m;
}

    public static void main(String[] args) {
    }
}
