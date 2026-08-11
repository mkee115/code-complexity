public static int sd(int n) {
    if (n < 0) {
        return sd(-n);
    }
    if (n < 10) {
        return n;
    }
    return n % 10 + sd(n / 10);
}
