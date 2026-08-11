/* ----------------------------------------------------------------------------------
 * ID: 20-V1
 * Function: Checks whether brackets in a string are balanced and correctly nested.
 * Complexities: CC 6 | Cognitive 10 | Nesting 3 | LOC 17 | FanOut 6
 * Isolating: branch count, by replacing nine character comparisons with position lookups
 * ---------------------------------------------------------------------------------- */
import java.util.ArrayDeque;
import java.util.Deque;
class S20_V1 {

public static boolean balanced(String s) {
    Deque<Character> st = new ArrayDeque<>();
    for (int i = 0; i < s.length(); i++) {
        char c = s.charAt(i);
        if ("([{".indexOf(c) >= 0) {
            st.push(c);
        } else if (")]}".indexOf(c) >= 0) {
            if (st.isEmpty()) {
                return false;
            }
            if ("([{".indexOf(st.pop()) != ")]}".indexOf(c)) {
                return false;
            }
        }
    }
    return st.isEmpty();
}

    public static void main(String[] args) {
    }
}
