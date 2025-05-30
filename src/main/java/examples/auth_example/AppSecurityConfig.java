package examples.auth_example;

import jazzyframework.di.annotations.Component;
import jazzyframework.security.config.SecurityConfig;

/**
 * Security configuration for the Authentication Example Application.
 * 
 * <p>This configuration demonstrates how to set up URL-based security rules
 * for a typical web application with authentication endpoints.
 * 
 * <h3>Security Rules:</h3>
 * <ul>
 *   <li><b>Public endpoints:</b> Home page and authentication endpoints</li>
 *   <li><b>Secure endpoints:</b> Protected resources requiring JWT token</li>
 *   <li><b>Admin endpoints:</b> Administrative functions requiring ADMIN role</li>
 * </ul>
 * 
 * <p>The {@code @Component} annotation ensures this configuration is automatically
 * discovered and used by the Jazzy Framework's security system.
 * 
 * @author Caner Mastan
 * @see SecurityConfig
 */
@Component
public class AppSecurityConfig extends SecurityConfig {
    
    /**
     * Configures security rules for the application.
     * 
     * <p>This method defines which endpoints are public, which require authentication,
     * and which require admin privileges. The configuration uses wildcards to
     * efficiently cover multiple related endpoints.
     */
    @Override
    public void configure() {
        // Define public endpoints (no authentication required)
        publicEndpoints(
            "/",                    // Home page - welcome message
            "/api/auth/**"          // All auth endpoints (register, login, me)
        );
        
        // Define secure endpoints (authentication required)
        requireAuth(
            "/api/protected",       // Example protected endpoint
            "/api/user/**"          // User-specific endpoints (profile, settings, etc.)
        );
        
        // Define admin endpoints (admin role required)
        requireRole("ADMIN", 
            "/api/admin/**"         // Administrative endpoints (user management, etc.)
        );
    }
} 