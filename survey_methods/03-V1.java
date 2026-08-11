class S03_V1 {

/* ----------------------------------------------------------------------------------
 * ID: 03-V1
 * Function: Checks a password for length, mixed case and a digit.
 * Complexities: CC 6 | Cognitive 5 | Nesting 1 | LOC 18 | FanOut 5
 * Isolating: cognitive complexity against CC, held equal at 6 while cognitive moves 2 to 5
 * ---------------------------------------------------------------------------------- */
public static boolean check(String p) {
    if (p == null) {
        return false;
    }
    if (p.length() < 8) {
        return false;
    }
    if (p.equals(p.toLowerCase())) {
        return false;
    }
    if (p.equals(p.toUpperCase())) {
        return false;
    }
    if (!p.matches(".*[0-9].*")) {
        return false;
    }
    return true;
}

    public static void main(String[] args) {
    }
}
