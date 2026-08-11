public static int sd(int n) {
    int remaining = Math.abs(n);
    int total = 0;
    while (remaining > 0) {
        total = total + remaining % 10;
        remaining = remaining / 10;
    }
    return total;
}
