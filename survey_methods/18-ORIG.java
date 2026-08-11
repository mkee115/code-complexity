class S18_ORIG {

/* ----------------------------------------------------------------------------------
 * ID: 18-ORIG
 * Function: Converts a Roman numeral to an integer.
 * Complexities: CC 4 | Cognitive 8 | Nesting 3 | LOC 16 | FanOut 3
 *               Helper value: CC 8, LOC 12, held constant across all three variants
 * Isolating: baseline
 * ---------------------------------------------------------------------------------- */
// CHECK HERE love this method
public static int roman(String s) {
    int total = 0;
    for (int i = 0; i < s.length(); i++) {
        int v = value(s.charAt(i));
        if (i + 1 < s.length()) {
            if (v < value(s.charAt(i + 1))) {
                total = total - v;
            } else {
                total = total + v;
            }
        } else {
            total = total + v;
        }
    }
    return total;
}

private static int value(char c) {
    switch (c) {
        case 'I': return 1;
        case 'V': return 5;
        case 'X': return 10;
        case 'L': return 50;
        case 'C': return 100;
        case 'D': return 500;
        case 'M': return 1000;
        default: return 0;
    }
}

    public static void main(String[] args) {
    }
}
