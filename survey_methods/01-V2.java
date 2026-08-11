public static String grade(int s) {
    String r;
    if (s >= 90) {
        r = "A+";
    } else if (s >= 80) {
        r = "A";
    } else if (s >= 65) {
        r = "B";
    } else if (s >= 50) {
        r = "C";
    } else {
        r = "D";
    }
    return r;
}
