public static String grade(int s) {
    String r;
    if (s >= 50) {
        if (s >= 65) {
            if (s >= 80) {
                if (s >= 90) {
                    r = "A+";
                } else {
                    r = "A";
                }
            } else {
                r = "B";
            }
        } else {
            r = "C";
        }
    } else {
        r = "D";
    }
    return r;
}
