import java.util.HashMap;
import java.util.List;
import java.util.Map;

public static Map<String, Integer> tally(List<String> items) {
    Map<String, Integer> m = new HashMap<>();
    for (String k : items) {
        m.put(k, m.getOrDefault(k, 0) + 1);
    }
    return m;
}
