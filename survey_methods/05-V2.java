class S05_V2 {

/* ----------------------------------------------------------------------------------
 * ID: 05-V2
 * Function: Sums the decimal digits of an integer.
 * Complexities: CC 3 | Cognitive 4 | Nesting 1 | LOC 6 | FanOut 1
 * Isolating: volume, with recursion and both control flow metrics held constant
 * ---------------------------------------------------------------------------------- */
public static int sd(int n) {
    if (n < 0) {
        return sd(-n);
    }
    return n < 10 ? n : n % 10 + sd(n / 10);
}

    public static void main(String[] args) {
    }
}
