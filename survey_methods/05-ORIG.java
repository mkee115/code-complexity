import java.util.ArrayList;
import java.util.List;

public static List<String> dedupe(List<String> in) {
    List<String> out = new ArrayList<>();
    for (int i = 0; i < in.size(); i++) {
        boolean found = false;
        for (int j = 0; j < out.size(); j++) {
            if (in.get(i).equals(out.get(j))) {
                found = true;
            }
        }
        if (!found) {
            out.add(in.get(i));
        }
    }
    return out;
}
