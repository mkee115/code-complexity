/* ----------------------------------------------------------------------------------
 * ID: 20-V3
 * Function: Checks whether brackets in a string are balanced and correctly nested.
 * Complexities: CC 15 | Cognitive 28 | Nesting 4 | LOC 26 | FanOut 5 | 6 comment lines
 * Isolating: comment quality, accurate summary plus signposts, on the hardest method in
 *            the set. Code token for token identical to 20-ORIG. Pair against 20-ORIG to
 *            ask whether a good comment is worth more than a large structural improvement,
 *            since 20-V1 halves CC on the same method
 * ---------------------------------------------------------------------------------- */
import java.util.ArrayDeque;
import java.util.Deque;
class S20_V3 {

/**
 * Returns true when every bracket is closed by one of its own kind, in the right order.
 * Characters that are not brackets are ignored.
 */
public static boolean balanced(String s) {
    Deque<Character> st = new ArrayDeque<>();
    for (int i = 0; i < s.length(); i++) {
        char c = s.charAt(i);
        // an opener is remembered until its partner shows up
        if (c == '(' || c == '[' || c == '{') {
            st.push(c);
        } else {
            if (c == ')' || c == ']' || c == '}') {
                if (st.isEmpty()) {
                    return false;
                }
                // a closer has to match the most recent unclosed opener
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
