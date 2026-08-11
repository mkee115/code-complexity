class S03_ORIG {

/* ----------------------------------------------------------------------------------
 * ID: 03-ORIG
 * Function: Checks a password for length, mixed case and a digit.
 * Complexities: CC 6 | Cognitive 2 | Nesting 1 | LOC 8 | FanOut 5
 * Isolating: baseline
 * ---------------------------------------------------------------------------------- */
// CHECK HERE i think this method could be good to add comments too as a variant 
public static boolean check(String p) {
    boolean ok = false;
    if (p != null && p.length() >= 8 && !p.equals(p.toLowerCase())
            && !p.equals(p.toUpperCase()) && p.matches(".*[0-9].*")) {
        ok = true;
    }
    return ok;
}

    public static void main(String[] args) {
    }
}
