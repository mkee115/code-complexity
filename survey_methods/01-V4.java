/**
 * Converts a raw exam mark into a letter grade.
 * Bands: 90 and above A+, 80 to 89 A, 65 to 79 B, 50 to 64 C, below 50 D.
 */
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
