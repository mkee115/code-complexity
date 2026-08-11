public static int sd(int n) {
    if (n < 0) {
        return sd(-n);
    }
    return n < 10 ? n : n % 10 + sd(n / 10);
}
