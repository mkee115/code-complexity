import java.util.ArrayDeque;
import java.util.Deque;

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
