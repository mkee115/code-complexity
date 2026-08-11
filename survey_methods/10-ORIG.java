import java.util.ArrayDeque;
import java.util.Deque;

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
