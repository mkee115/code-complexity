/* ----------------------------------------------------------------------------------
 * ID: 15-V1
 * Function: Counts how many times each string appears in a list.
 * Complexities: CC 2 | Cognitive 1 | Nesting 1 | LOC 7 | FanOut 3
 * Isolating: branch count, by replacing the presence test with a default lookup
 * ---------------------------------------------------------------------------------- */
import java.util.HashMap;
import java.util.List;
import java.util.Map;
class S15_V1 {

public static Map<String, Integer> tally(List<String> items) {
    Map<String, Integer> m = new HashMap<>();
    for (String k : items) {
        m.put(k, m.getOrDefault(k, 0) + 1);
    }
    return m;
}

    public static void main(String[] args) {
    }
}
