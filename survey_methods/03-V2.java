class S03_V2 {

/* ----------------------------------------------------------------------------------
 * ID: 03-V2
 * Function: Checks a password for length, mixed case and a digit.
 * Complexities: CC 4 | Cognitive 1 | Nesting 0 | LOC 3 | FanOut 4
 *               Helpers: CC 1, 2, 1 and LOC 3, 3, 3. Block totals CC 8, LOC 12
 * Isolating: extraction into named helpers
 * ---------------------------------------------------------------------------------- */
// CHECK HERE is it fine to make helper methods? just wanted to make sure since our study is
// about method complexity and not class complexity
public static boolean check(String p) {
    return p != null && hasMinLength(p) && hasLowerAndUpper(p) && hasDigit(p);
}

private static boolean hasMinLength(String p) {
    return p.length() >= 8;
}

private static boolean hasLowerAndUpper(String p) {
    return !p.equals(p.toLowerCase()) && !p.equals(p.toUpperCase());
}

private static boolean hasDigit(String p) {
    return p.matches(".*[0-9].*");
}

    public static void main(String[] args) {
    }
}
