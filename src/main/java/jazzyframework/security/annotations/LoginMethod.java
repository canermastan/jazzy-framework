package jazzyframework.security.annotations;

/**
 * Defines the authentication method for user login
 */
public enum LoginMethod {
    /**
     * Users login with email address only
     */
    EMAIL,
    
    /**
     * Users login with username only  
     */
    USERNAME,
    
    /**
     * Users can login with either email or username
     */
    BOTH
} 