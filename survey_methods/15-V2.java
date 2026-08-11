/* ----------------------------------------------------------------------------------
 * ID: 15-V2
 * Function: Counts how many times each string appears in a list.
 * Complexities: CC 3 | Cognitive 4 | Nesting 2 | LOC 12 | FanOut 4
 * Isolating: naming, structure identical to 15-ORIG
 * ---------------------------------------------------------------------------------- */
// CHECK HERE rlly like this variant 
import java.util.HashMap;
import java.util.List;
import java.util.Map;
class S15_V2 {

public static Map<String, Integer> countByValue(List<String> items) {
    Map<String, Integer> counts = new HashMap<>();
    for (int index = 0; index < items.size(); index++) {
        String key = items.get(index);
        if (counts.containsKey(key)) {
            counts.put(key, counts.get(key) + 1);
        } else {
            counts.put(key, 1);
        }
    }
    return counts;
}

    public static void main(String[] args) {
    }
}
