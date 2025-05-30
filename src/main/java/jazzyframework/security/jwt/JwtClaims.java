package jazzyframework.security.jwt;

/**
 * JWT Claims data structure
 */
public class JwtClaims {
    
    private final String userId;
    private final String email;
    private final String[] roles;
    
    public JwtClaims(String userId, String email, String[] roles) {
        this.userId = userId;
        this.email = email;
        this.roles = roles != null ? roles : new String[0];
    }
    
    public String getUserId() {
        return userId;
    }
    
    public String getEmail() {
        return email;
    }
    
    public String[] getRoles() {
        return roles;
    }
    
    public boolean hasRole(String role) {
        if (roles == null) return false;
        for (String userRole : roles) {
            if (role.equals(userRole)) {
                return true;
            }
        }
        return false;
    }
    
    @Override
    public String toString() {
        return "JwtClaims{userId='" + userId + "', email='" + email + "', roles=" + java.util.Arrays.toString(roles) + "}";
    }
} 