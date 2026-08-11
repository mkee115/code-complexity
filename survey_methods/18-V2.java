class S18_V2 {

/* ----------------------------------------------------------------------------------
 * ID: 18-V2
 * Function: Converts a Roman numeral to an integer.
 * Complexities: CC 3 | Cognitive 4 | Nesting 2 | LOC 14 | FanOut 3
 * Isolating: branch count, by scanning right to left against a running maximum
 * ---------------------------------------------------------------------------------- */
// CHECK HERE i think unless we also want to test having a reversed loop instead of a
// forward loop, we should leave this one out bc itll probably increase cognitive 
// complexity. but if we do want to test that, this is a good variant. idk if i explained
// that well, ask me ab it if it doesnt
public static int roman(String s) {
    int total = 0;
    int highest = 0;
    for (int i = s.length() - 1; i >= 0; i--) {
        int v = value(s.charAt(i));
        if (v < highest) {
            total = total - v;
        } else {
            total = total + v;
            highest = v;
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
