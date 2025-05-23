package jazzyframework.di.annotations;

import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

/**
 * Indicates that a component should be given preference when multiple candidates
 * are qualified to autowire a single-valued dependency.
 * 
 * <p>Example usage:
 * <pre>
 * &#64;Component
 * &#64;Primary
 * public class DatabaseUserRepository implements UserRepository {
 *     // primary implementation
 * }
 * 
 * &#64;Component
 * public class InMemoryUserRepository implements UserRepository {
 *     // alternative implementation
 * }
 * 
 * // UserService will get DatabaseUserRepository injected (marked as @Primary)
 * public class UserService {
 *     public UserService(UserRepository repository) {
 *         // DatabaseUserRepository will be injected
 *     }
 * }
 * </pre>
 */
@Target(ElementType.TYPE)
@Retention(RetentionPolicy.RUNTIME)
public @interface Primary {
} 