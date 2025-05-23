package jazzyframework.di.annotations;

import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

/**
 * Indicates that a method should be called before the component is removed from the container.
 * The annotated method will be invoked when the container is being disposed or the
 * component is being removed.
 * 
 * <p>The method must be public, have no parameters, and return void.
 * 
 * <p>Example usage:
 * <pre>
 * &#64;Component
 * public class DatabaseService {
 *     private Connection connection;
 *     
 *     &#64;PostConstruct
 *     public void connect() {
 *         connection = DriverManager.getConnection("...");
 *     }
 *     
 *     &#64;PreDestroy
 *     public void disconnect() {
 *         // Cleanup code here
 *         if (connection != null) {
 *             connection.close();
 *         }
 *         System.out.println("DatabaseService cleaned up!");
 *     }
 * }
 * </pre>
 */
@Target(ElementType.METHOD)
@Retention(RetentionPolicy.RUNTIME)
public @interface PreDestroy {
} 