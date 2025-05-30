package jazzyframework.security.config;

import java.util.ArrayList;
import java.util.List;

/**
 * Security configuration for Jazzy Framework.
 * 
 * <p>Users extend this abstract class to define URL-based security rules for their applications.
 * The configuration supports three types of endpoint protection:
 * 
 * <ul>
 *   <li><b>Public endpoints</b> - No authentication required</li>
 *   <li><b>Secure endpoints</b> - JWT authentication required</li>
 *   <li><b>Admin endpoints</b> - JWT authentication + ADMIN role required</li>
 * </ul>
 * 
 * <h3>Usage Example:</h3>
 * <pre>{@code
 * @Component
 * public class MySecurityConfig extends SecurityConfig {
 *     
 *     @Override
 *     public void configure() {
 *         // Public endpoints (no auth needed)
 *         publicEndpoints("/", "/api/auth/**", "/static/**");
 *         
 *         // Secure endpoints (JWT required)
 *         requireAuth("/api/user/**", "/api/profile");
 *         
 *         // Admin endpoints (JWT + ADMIN role required)
 *         requireRole("ADMIN", "/api/admin/**");
 *     }
 * }
 * }</pre>
 * 
 * <h3>Wildcard Support:</h3>
 * <ul>
 *   <li><b>*</b> - Matches any single path segment (e.g., /user/* matches /user/123 but not /user/123/profile)</li>
 *   <li><b>**</b> - Matches any number of path segments (e.g., /api/** matches /api/auth/login and /api/user/profile/edit)</li>
 * </ul>
 * 
 * @since 0.5.0
 * @author Caner Mastan
 */
public abstract class SecurityConfig {
    
    private final List<String> publicEndpoints = new ArrayList<>();
    private final List<String> secureEndpoints = new ArrayList<>();
    private final List<String> adminEndpoints = new ArrayList<>();
    
    /**
     * Override this method to configure security rules
     */
    public abstract void configure();
    
    /**
     * Mark endpoints as public (no authentication required)
     * Supports wildcards: /api/public/**, /static/*
     */
    protected void publicEndpoints(String... patterns) {
        for (String pattern : patterns) {
            publicEndpoints.add(pattern);
        }
    }
    
    /**
     * Mark endpoints as secure (authentication required)
     * Supports wildcards: /api/secure/**, /user/*
     */
    protected void requireAuth(String... patterns) {
        for (String pattern : patterns) {
            secureEndpoints.add(pattern);
        }
    }
    
    /**
     * Mark endpoints as admin only (admin role required)
     * Supports wildcards: /api/admin/**, /admin/*
     */
    protected void requireRole(String role, String... patterns) {
        // For now, only support ADMIN role
        if ("ADMIN".equals(role)) {
            for (String pattern : patterns) {
                adminEndpoints.add(pattern);
            }
        }
    }
    
    /**
     * Check if endpoint is public
     */
    public boolean isPublic(String path) {
        return matchesAnyPattern(path, publicEndpoints);
    }
    
    /**
     * Check if endpoint requires authentication
     */
    public boolean requiresAuth(String path) {
        return matchesAnyPattern(path, secureEndpoints) || matchesAnyPattern(path, adminEndpoints);
    }
    
    /**
     * Check if endpoint requires admin role
     */
    public boolean requiresAdmin(String path) {
        return matchesAnyPattern(path, adminEndpoints);
    }
    
    /**
     * Get all public endpoints
     */
    public List<String> getPublicEndpoints() {
        return new ArrayList<>(publicEndpoints);
    }
    
    /**
     * Get all secure endpoints
     */
    public List<String> getSecureEndpoints() {
        return new ArrayList<>(secureEndpoints);
    }
    
    /**
     * Get all admin endpoints
     */
    public List<String> getAdminEndpoints() {
        return new ArrayList<>(adminEndpoints);
    }
    
    /**
     * Check if path matches any of the patterns
     * Supports simple wildcards: *, **
     */
    private boolean matchesAnyPattern(String path, List<String> patterns) {
        for (String pattern : patterns) {
            if (matchesPattern(path, pattern)) {
                return true;
            }
        }
        return false;
    }
    
    /**
     * Simple pattern matching with wildcard support
     * * matches any single path segment
     * ** matches any number of path segments
     */
    private boolean matchesPattern(String path, String pattern) {
        if (pattern.equals(path)) {
            return true;
        }
        
        if (pattern.endsWith("/**")) {
            String prefix = pattern.substring(0, pattern.length() - 3);
            return path.startsWith(prefix);
        }
        
        if (pattern.endsWith("/*")) {
            String prefix = pattern.substring(0, pattern.length() - 2);
            if (!path.startsWith(prefix)) {
                return false;
            }
            String remaining = path.substring(prefix.length());
            return !remaining.contains("/") || remaining.equals("/");
        }
        
        return false;
    }
} 