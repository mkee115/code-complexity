public static boolean check(String p) {
    boolean ok = false;
    if (p != null && p.length() >= 8 && !p.equals(p.toLowerCase())
            && !p.equals(p.toUpperCase()) && p.matches(".*[0-9].*")) {
        ok = true;
    }
    return ok;
}
