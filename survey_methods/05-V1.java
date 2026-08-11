class S05_V1 {

/* ----------------------------------------------------------------------------------
 * ID: 05-V1
 * Function: Sums the decimal digits of an integer.
 * Complexities: CC 2 | Cognitive 1 | Nesting 1 | LOC 9 | FanOut 1
 * Isolating: recursion, with LOC identical on both sides so size cannot explain a preference
 * ---------------------------------------------------------------------------------- */
public static int sd(int n) {
    int remaining = Math.abs(n);
    int total = 0;
    while (remaining > 0) {
        total = total + remaining % 10;
        remaining = remaining / 10;
    }
    return total;
}

    public static void main(String[] args) {
    }
}
