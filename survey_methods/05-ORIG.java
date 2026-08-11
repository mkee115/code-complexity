class S05_ORIG {

/* ----------------------------------------------------------------------------------
 * ID: 05-ORIG
 * Function: Sums the decimal digits of an integer.
 * Complexities: CC 3 | Cognitive 4 | Nesting 1 | LOC 9 | FanOut 1
 * Isolating: baseline
 * ---------------------------------------------------------------------------------- */
public static int sd(int n) {
    if (n < 0) {
        return sd(-n);
    }
    if (n < 10) {
        return n;
    }
    return n % 10 + sd(n / 10);
}

    public static void main(String[] args) {
    }
}
