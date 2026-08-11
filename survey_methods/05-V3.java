import java.util.ArrayList;
import java.util.List;

public static List<String> removeDuplicates(List<String> source) {
    List<String> unique = new ArrayList<>();
    for (int sourceIndex = 0; sourceIndex < source.size(); sourceIndex++) {
        boolean alreadySeen = false;
        for (int uniqueIndex = 0; uniqueIndex < unique.size(); uniqueIndex++) {
            if (source.get(sourceIndex).equals(unique.get(uniqueIndex))) {
                alreadySeen = true;
            }
        }
        if (!alreadySeen) {
            unique.add(source.get(sourceIndex));
        }
    }
    return unique;
}
