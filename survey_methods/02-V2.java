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
