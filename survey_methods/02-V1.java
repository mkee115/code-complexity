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
