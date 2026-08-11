public static int roman(String s) {
    int total = 0;
    int highest = 0;
    for (int i = s.length() - 1; i >= 0; i--) {
        int v = value(s.charAt(i));
        if (v < highest) {
            total = total - v;
        } else {
            total = total + v;
            highest = v;
        }
    }
    return total;
}

private static int value(char c) {
    switch (c) {
        case 'I': return 1;
        case 'V': return 5;
        case 'X': return 10;
        case 'L': return 50;
        case 'C': return 100;
        case 'D': return 500;
        case 'M': return 1000;
        default: return 0;
    }
}
