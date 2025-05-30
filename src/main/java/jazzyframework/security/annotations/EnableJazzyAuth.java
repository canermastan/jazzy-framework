package jazzyframework.security.annotations;

import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

/**
 * Enables Jazzy Framework Authentication System
 * 
 * Usage:
 * @EnableJazzyAuth(
 *     userClass = User.class, 
 *     repositoryClass = UserRepository.class,
 *     loginMethod = LoginMethod.EMAIL
 * )
 * public class MyApp {
 *     public static void main(String[] args) {
 *         Jazzy.run(MyApp.class, args);
 *     }
 * }
 */
@Target(ElementType.TYPE)
@Retention(RetentionPolicy.RUNTIME)
public @interface EnableJazzyAuth {
    
    /**
     * User entity class that contains authentication fields
     * Must have: email or username, password fields
     */
    Class<?> userClass();
    
    /**
     * User repository class that extends BaseRepository
     * Must be a repository interface for the user entity
     */
    Class<?> repositoryClass();
    
    /**
     * Login method - EMAIL, USERNAME, or BOTH
     */
    LoginMethod loginMethod() default LoginMethod.EMAIL;
    
    /**
     * JWT secret key (optional - defaults to random key)
     */
    String jwtSecret() default "";
    
    /**
     * JWT expiration in hours (default: 24 hours)
     */
    int jwtExpirationHours() default 24;
    
    /**
     * Enable admin endpoints (/api/admin/**)
     */
    boolean enableAdminEndpoints() default false;
    
    /**
     * Base path for auth endpoints (default: /api/auth)
     */
    String authBasePath() default "/api/auth";
} 