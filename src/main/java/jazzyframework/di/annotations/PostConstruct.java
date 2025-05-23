package jazzyframework.di.annotations;

import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

/**
 * Indicates that a method should be called after dependency injection is complete.
 * The annotated method will be invoked after the object has been constructed and
 * all dependencies have been injected.
 * 
 * <p>The method must be public, have no parameters, and return void.
 * 
 * <p>Example usage:
 * <pre>
 * &#64;Component
 * public class UserService {
 *     private UserRepository userRepository;
 *     
 *     public UserService(UserRepository userRepository) {
 *         this.userRepository = userRepository;
 *     }
 *     
 *     &#64;PostConstruct
 *     public void initialize() {
 *         // Initialization code here
 *         System.out.println("UserService initialized!");
 *         // Load default data, connect to external services, etc.
 *     }
 * }
 * </pre>
 */
@Target(ElementType.METHOD)
@Retention(RetentionPolicy.RUNTIME)
public @interface PostConstruct {
} 