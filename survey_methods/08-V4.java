/**
 * Removes duplicate strings from a list, preserving the order of first appearance.
 *
 * @param in the input list, possibly containing duplicates
 * @return a new list containing only the first occurrence of each string
 */
public static List<String> dedupe(List<String> in) {
    List<String> out = new ArrayList<>();
    for (int i = 0; i < in.size(); i++) {
        boolean found = false;
        // check if the current element already exists in the output list
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

public static void main(String[] args) {
}