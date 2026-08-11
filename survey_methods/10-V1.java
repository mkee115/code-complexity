import java.util.ArrayDeque;
import java.util.Deque;

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
