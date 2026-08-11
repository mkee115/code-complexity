/* ----------------------------------------------------------------------------------
 * ID: 08-V3
 * Function: Removes duplicates from a list, keeping first appearance order.
 * Complexities: CC 5 | Cognitive 8 | Nesting 3 | LOC 15 | FanOut 5
 * Isolating: naming, on a structurally hard method. Pair with 01-V3 for the interaction
 *            between naming and structural difficulty
 * ---------------------------------------------------------------------------------- */
import java.util.ArrayList;
import java.util.List;
class S08_V3 {

public static List<String> removeDuplicates(List<String> source) {
    List<String> unique = new ArrayList<>();
    for (int sourceIndex = 0; sourceIndex < source.size(); sourceIndex++) {
        boolean alreadySeen = false;
        for (int uniqueIndex = 0; uniqueIndex < unique.size(); uniqueIndex++) {
            if (source.get(sourceIndex).equals(unique.get(uniqueIndex))) {
                alreadySeen = true;
            }
        }
        if (!alreadySeen) {
            unique.add(source.get(sourceIndex));
        }
    }
    return unique;
}

    public static void main(String[] args) {
    }
}
