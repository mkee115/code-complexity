import java.util.ArrayList;
import java.util.List;

public static List<String> dedupe(List<String> in) {
    List<String> out = new ArrayList<>();
    for (String s : in) {
        if (!out.contains(s)) {
            out.add(s);
        }
    }
    return out;
}
