/**
 * Checks whether a password meets the minimum security requirements.
 *
 * @param p the password to validate
 * @return true if the password is non-null, at least 8 characters long,
 *         contains at least one uppercase letter, one lowercase letter,
 *         and one digit; false otherwise
 */
public static boolean check(String p) {
    boolean ok = false;
    if (p != null && p.length() >= 8 && !p.equals(p.toLowerCase())
            && !p.equals(p.toUpperCase()) && p.matches(".*[0-9].*")) {
        ok = true;
    }
    return ok;
}

public static void main(String[] args) {    
    
}
