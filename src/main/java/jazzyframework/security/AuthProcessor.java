package jazzyframework.security;

import jazzyframework.di.DIContainer;
import jazzyframework.routing.Router;
import jazzyframework.security.annotations.EnableJazzyAuth;
import jazzyframework.security.controller.DefaultAuthController;
import jazzyframework.security.jwt.JwtUtil;
import jazzyframework.security.validation.UserEntityValidator;
import jazzyframework.security.config.SecurityConfig;
import jazzyframework.data.BaseRepository;

import java.util.Set;
import java.util.logging.Logger;

/**
 * Processes @EnableJazzyAuth annotation and automatically registers authentication endpoints.
 * 
 * <p>This processor is responsible for:
 * <ul>
 *   <li>Scanning for @EnableJazzyAuth annotations on application classes</li>
 *   <li>Validating user entity classes for required authentication fields</li>
 *   <li>Creating and configuring JWT utilities</li>
 *   <li>Registering authentication endpoints (register, login, me)</li>
 *   <li>Setting up SecurityInterceptor when SecurityConfig is available</li>
 * </ul>
 * 
 * <p>The processor automatically integrates with the DI container to:
 * <ul>
 *   <li>Obtain user repository instances</li>
 *   <li>Register authentication controllers</li>
 *   <li>Configure security interceptors</li>
 * </ul>
 * 
 * @since 0.5.0
 * @author Caner Mastan
 */
public class AuthProcessor {
    
    private static final Logger logger = Logger.getLogger(AuthProcessor.class.getName());
    private final Router router;
    private final DIContainer diContainer;
    private JwtUtil jwtUtil; // Store for SecurityInterceptor
    
    /**
     * Creates a new AuthProcessor with the specified router and DI container.
     * 
     * @param router The router to register authentication endpoints
     * @param diContainer The DI container for dependency management
     */
    public AuthProcessor(Router router, DIContainer diContainer) {
        this.router = router;
        this.diContainer = diContainer;
    }
    
    /**
     * Scans for @EnableJazzyAuth annotation and configures authentication.
     * 
     * <p>This method performs the following steps:
     * <ol>
     *   <li>Scans all registered classes in the DI container</li>
     *   <li>Looks for classes annotated with @EnableJazzyAuth</li>
     *   <li>Configures authentication based on the annotation parameters</li>
     *   <li>Falls back to classpath scanning if needed</li>
     * </ol>
     */
    public void processAuthAnnotations() {
        try {
            // Get all registered classes from DI container
            Set<Class<?>> allClasses = diContainer.getAllRegisteredClasses();
            
            for (Class<?> clazz : allClasses) {
                if (clazz.isAnnotationPresent(EnableJazzyAuth.class)) {
                    EnableJazzyAuth authConfig = clazz.getAnnotation(EnableJazzyAuth.class);
                    configureAuthentication(authConfig);
                    logger.info("Authentication configured from @EnableJazzyAuth on " + clazz.getSimpleName());
                    return; // Only process first found annotation
                }
            }
            
            // Also scan all classes in classpath for @EnableJazzyAuth (fallback approach)
            scanClasspathForAuthAnnotation();
            
        } catch (Exception e) {
            logger.warning("Failed to process @EnableJazzyAuth annotations: " + e.getMessage());
            e.printStackTrace();
        }
    }
    
    /**
     * Scans classpath for @EnableJazzyAuth annotation using stack trace analysis.
     * This is a fallback method when the annotation is not found in DI container.
     */
    private void scanClasspathForAuthAnnotation() {
        try {
            // Get stack trace to find the main class
            StackTraceElement[] stackTrace = Thread.currentThread().getStackTrace();
            
            for (StackTraceElement element : stackTrace) {
                if ("main".equals(element.getMethodName())) {
                    try {
                        Class<?> mainClass = Class.forName(element.getClassName());
                        if (mainClass.isAnnotationPresent(EnableJazzyAuth.class)) {
                            EnableJazzyAuth authConfig = mainClass.getAnnotation(EnableJazzyAuth.class);
                            configureAuthentication(authConfig);
                            logger.info("Authentication configured from @EnableJazzyAuth on " + mainClass.getSimpleName());
                            return;
                        }
                    } catch (ClassNotFoundException e) {
                        // Continue scanning
                    }
                }
            }
            
            logger.fine("No @EnableJazzyAuth annotation found");
        } catch (Exception e) {
            logger.warning("Failed to scan classpath for @EnableJazzyAuth: " + e.getMessage());
        }
    }
    
    /**
     * Configures authentication based on @EnableJazzyAuth annotation parameters.
     * 
     * <p>This method:
     * <ul>
     *   <li>Validates the user entity class</li>
     *   <li>Creates JWT utility with specified configuration</li>
     *   <li>Obtains user repository from DI container</li>
     *   <li>Creates and registers authentication controller</li>
     *   <li>Registers authentication endpoints</li>
     *   <li>Sets up security interceptor if SecurityConfig exists</li>
     * </ul>
     * 
     * @param config The @EnableJazzyAuth annotation configuration
     * @throws RuntimeException if authentication configuration fails
     */
    private void configureAuthentication(EnableJazzyAuth config) {
        try {
            // Validate user class
            UserEntityValidator.validateUserClass(config.userClass(), config.loginMethod());
            
            // Create JWT utility
            jwtUtil = new JwtUtil(config.jwtSecret(), config.jwtExpirationHours());
            
            // Get user repository from DI container
            BaseRepository<Object, Long> userRepository = getUserRepository(config.repositoryClass());
            
            // Create auth controller
            DefaultAuthController authController = new DefaultAuthController(
                config.userClass(),
                config.loginMethod(),
                jwtUtil,
                userRepository
            );
            
            // Register auth controller in DI container
            diContainer.registerInstance(DefaultAuthController.class, authController);
            
            // Register auth endpoints
            String basePath = config.authBasePath();
            router.POST(basePath + "/register", "register", DefaultAuthController.class);
            router.POST(basePath + "/login", "login", DefaultAuthController.class);
            router.GET(basePath + "/me", "getCurrentUser", DefaultAuthController.class);
            
            logger.info("Authentication endpoints registered:");
            logger.info("  POST " + basePath + "/register");
            logger.info("  POST " + basePath + "/login");
            logger.info("  GET " + basePath + "/me");
            logger.info("Using repository: " + config.repositoryClass().getSimpleName());
            
            // Set up SecurityInterceptor if SecurityConfig exists
            setupSecurityInterceptor();
            
        } catch (Exception e) {
            throw new RuntimeException("Failed to configure authentication", e);
        }
    }
    
    /**
     * Sets up SecurityInterceptor if a SecurityConfig implementation is found in the DI container.
     * 
     * <p>This method scans for classes extending SecurityConfig and creates a SecurityInterceptor
     * instance to handle URL-based security rules.
     */
    private void setupSecurityInterceptor() {
        try {
            // Look for SecurityConfig in DI container
            Set<Class<?>> allClasses = diContainer.getAllRegisteredClasses();
            
            for (Class<?> clazz : allClasses) {
                if (SecurityConfig.class.isAssignableFrom(clazz) && !SecurityConfig.class.equals(clazz)) {
                    SecurityConfig securityConfig = (SecurityConfig) diContainer.getBean(clazz);
                    SecurityInterceptor interceptor = new SecurityInterceptor(securityConfig, jwtUtil);
                    
                    // Register interceptor in DI container for Router to use
                    diContainer.registerInstance(SecurityInterceptor.class, interceptor);
                    
                    logger.info("SecurityInterceptor configured with: " + clazz.getSimpleName());
                    return;
                }
            }
            
            logger.fine("No SecurityConfig found, authentication endpoints only");
        } catch (Exception e) {
            logger.warning("Failed to setup SecurityInterceptor: " + e.getMessage());
        }
    }
    
    /**
     * Gets the user repository from the DI container.
     * 
     * @param repositoryClass The repository class to obtain
     * @return The repository instance cast to BaseRepository
     * @throws RuntimeException if the repository cannot be found or is invalid
     */
    @SuppressWarnings("unchecked")
    private BaseRepository<Object, Long> getUserRepository(Class<?> repositoryClass) {
        try {
            // Get the repository from DI container
            Object repository = diContainer.getBean(repositoryClass);
            if (repository instanceof BaseRepository) {
                return (BaseRepository<Object, Long>) repository;
            } else {
                throw new IllegalArgumentException("Repository class must extend BaseRepository: " + repositoryClass.getSimpleName());
            }
        } catch (Exception e) {
            throw new RuntimeException("Failed to get user repository: " + repositoryClass.getSimpleName() + 
                                     ". Make sure it's registered in DI container.", e);
        }
    }
} 