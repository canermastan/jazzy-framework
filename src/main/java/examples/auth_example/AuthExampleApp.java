package examples.auth_example;

import jazzyframework.core.Config;
import jazzyframework.core.Server;
import jazzyframework.routing.Router;
import jazzyframework.security.annotations.EnableJazzyAuth;
import jazzyframework.security.annotations.LoginMethod;

/**
 * Authentication Example Application
 * 
 * This example demonstrates how to use @EnableJazzyAuth annotation
 * to automatically enable authentication endpoints in your Jazzy application.
 * 
 * Features enabled:
 * - POST /api/auth/register - User registration
 * - POST /api/auth/login - User login  
 * - GET /api/auth/me - Get current user info
 * 
 * JWT authentication with email-based login
 */
@EnableJazzyAuth(
    userClass = User.class,
    repositoryClass = UserRepository.class,
    loginMethod = LoginMethod.EMAIL,
    jwtExpirationHours = 24,
    authBasePath = "/api/auth"
)
public class AuthExampleApp {
    
    public static void main(String[] args) {
        System.out.println("🚀 Starting Jazzy Auth Example Application...");
        
        Config config = new Config();
        config.setEnableMetrics(true);
        config.setServerPort(8080);
        
        Router router = new Router();
        
        // Configure routes
        configureRoutes(router);
        
        // Start server
        Server server = new Server(router, config);
        server.start(config.getServerPort());
        
        System.out.println("✅ Authentication endpoints available:");
        System.out.println("📝 POST /api/auth/register - Register new user");
        System.out.println("🔐 POST /api/auth/login - User login");
        System.out.println("👤 GET /api/auth/me - Get current user");
        System.out.println("🌐 Server running on http://localhost:" + config.getServerPort());
    }
    
    /**
     * Configure application routes
     */
    private static void configureRoutes(Router router) {
        // Example: Public welcome endpoint
        router.GET("/", "home", HomeController.class);
        
        // Example: Protected endpoint (requires authentication in SecurityConfig)
        router.GET("/api/protected", "protectedEndpoint", HomeController.class);
    }
} 