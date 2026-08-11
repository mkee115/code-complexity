/* ----------------------------------------------------------------------------------
 * ID: 20-V2
 * Function: Checks whether brackets in a string are balanced and correctly nested.
 * Complexities: CC 6 | Cognitive 8 | Nesting 3 | LOC 14 | FanOut 6
 *               Helper matches: CC 1, LOC 3. Block totals CC 7, LOC 17
 * Isolating: extraction, with the pair test moved behind a name and guarded by short circuiting
 * ---------------------------------------------------------------------------------- */
import java.util.ArrayDeque;
import java.util.Deque;
class S20_V2 {

public static boolean balanced(String s) {
    Deque<Character> st = new ArrayDeque<>();
    for (int i = 0; i < s.length(); i++) {
        char c = s.charAt(i);
        if ("([{".indexOf(c) >= 0) {
            st.push(c);
        } else if (")]}".indexOf(c) >= 0) {
            if (st.isEmpty() || !matches(st.pop(), c)) {
                return false;
            }
        }
    }
    return st.isEmpty();
}

private static boolean matches(char open, char close) {
    return "([{".indexOf(open) == ")]}".indexOf(close);
}

    public static void main(String[] args) {
    }
}
