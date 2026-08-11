import java.util.HashMap;
import java.util.List;
import java.util.Map;

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
