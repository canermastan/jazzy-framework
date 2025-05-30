package jazzyframework.security;

import jazzyframework.http.Request;
import jazzyframework.http.Response;
import jazzyframework.http.JSON;
import jazzyframework.security.config.SecurityConfig;
import jazzyframework.security.jwt.JwtUtil;
import jazzyframework.security.jwt.JwtClaims;

import java.util.logging.Logger;

/**
 * Security interceptor that validates JWT tokens based on SecurityConfig rules.
 * 
 * <p>This interceptor automatically checks incoming requests against the configured
 * security rules and validates JWT tokens for protected endpoints.
 * 
 * <p>The interceptor works by:
 * <ul>
 *   <li>Checking if the requested endpoint is explicitly marked as public</li>
 *   <li>Validating JWT tokens for secure endpoints</li>
 *   <li>Verifying user roles for admin-only endpoints</li>
 *   <li>Returning appropriate HTTP status codes (401, 403) for security violations</li>
 * </ul>
 * 
 * @since 0.5.0
 * @author Caner Mastan
 */
public class SecurityInterceptor {
    
    private static final Logger logger = Logger.getLogger(SecurityInterceptor.class.getName());
    private final SecurityConfig securityConfig;
    private final JwtUtil jwtUtil;
    
    /**
     * Creates a new SecurityInterceptor with the specified configuration.
     * 
     * @param securityConfig The security configuration defining endpoint rules
     * @param jwtUtil The JWT utility for token validation
     */
    public SecurityInterceptor(SecurityConfig securityConfig, JwtUtil jwtUtil) {
        this.securityConfig = securityConfig;
        this.jwtUtil = jwtUtil;
        
        // Initialize security config
        this.securityConfig.configure();
        
        logger.info("Security interceptor initialized");
        logger.info("Public endpoints: " + securityConfig.getPublicEndpoints());
        logger.info("Secure endpoints: " + securityConfig.getSecureEndpoints());
        logger.info("Admin endpoints: " + securityConfig.getAdminEndpoints());
    }
    
    /**
     * Intercepts an incoming request and applies security rules.
     * 
     * @param request The HTTP request to check
     * @return null if the request should proceed, or a Response if it should be blocked
     */
    public Response intercept(Request request) {
        String path = request.getPath();
        String method = request.getMethod();
        
        logger.fine("Security check for: " + method + " " + path);
        
        // Check if endpoint is explicitly public
        if (securityConfig.isPublic(path)) {
            logger.fine("Public endpoint, allowing access");
            return null; // Allow request to proceed
        }
        
        // Check if endpoint requires authentication
        if (securityConfig.requiresAuth(path)) {
            logger.fine("Secure endpoint, checking JWT token");
            
            // Validate JWT token
            JwtClaims claims = validateToken(request);
            if (claims == null) {
                logger.info("Authentication failed for: " + method + " " + path);
                return Response.json(JSON.of("error", "Authentication required")).status(401);
            }
            
            // Check admin role if required
            if (securityConfig.requiresAdmin(path)) {
                if (!claims.hasRole("ADMIN")) {
                    logger.info("Admin access denied for user " + claims.getUserId() + " on: " + path);
                    return Response.json(JSON.of("error", "Admin access required")).status(403);
                }
            }
            
            logger.fine("Authentication successful for user: " + claims.getUserId());
        }
        
        return null; // Allow request to proceed
    }
    
    /**
     * Validates JWT token from the Authorization header.
     * 
     * @param request The HTTP request containing the Authorization header
     * @return JwtClaims if token is valid, null otherwise
     */
    private JwtClaims validateToken(Request request) {
        try {
            String authHeader = request.header("Authorization");
            if (authHeader == null || !authHeader.startsWith("Bearer ")) {
                return null;
            }
            
            String token = authHeader.substring(7);
            return jwtUtil.validateToken(token);
            
        } catch (Exception e) {
            logger.fine("JWT validation failed: " + e.getMessage());
            return null;
        }
    }
} 