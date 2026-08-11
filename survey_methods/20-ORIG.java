/* ----------------------------------------------------------------------------------
 * ID: 20-ORIG
 * Function: Checks whether brackets in a string are balanced and correctly nested.
 * Complexities: CC 15 | Cognitive 28 | Nesting 4 | LOC 26 | FanOut 5
 * Isolating: baseline. The hardest item in the set and the only one above McCabe's
 *            threshold of 10, so it doubles as a probe for RQ3
 * ---------------------------------------------------------------------------------- */
// CHECK HERE i think this method is too complicated for the study, keen to scrap it all.
// unless you think that they can get read two of these and write about it within 2 mins?
import java.util.ArrayDeque;
import java.util.Deque;
class S20_ORIG {

public static boolean balanced(String s) {
    Deque<Character> st = new ArrayDeque<>();
    for (int i = 0; i < s.length(); i++) {
        char c = s.charAt(i);
        if (c == '(' || c == '[' || c == '{') {
            st.push(c);
        } else {
            if (c == ')' || c == ']' || c == '}') {
                if (st.isEmpty()) {
                    return false;
                }
                char o = st.pop();
                if (o == '(' && c != ')') {
                    return false;
                }
                if (o == '[' && c != ']') {
                    return false;
                }
                if (o == '{' && c != '}') {
                    return false;
                }
            }
        }
    }
    return st.isEmpty();
}

    public static void main(String[] args) {
    }
}
