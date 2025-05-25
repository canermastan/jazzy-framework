package jazzyframework.di.annotations;

import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

/**
 * Annotation to mark methods that should be called before component destruction.
 * 
 * <p>Methods annotated with {@code @PreDestroy} are called automatically
 * by the DI container when the application is shutting down or the component
 * is being removed from the container.
 * 
 * <p>This is useful for:
 * <ul>
 *   <li>Closing database connections and resources</li>
 *   <li>Stopping background threads or scheduled tasks</li>
 *   <li>Releasing file handles or network connections</li>
 *   <li>Persisting state or flushing caches</li>
 *   <li>Cleaning up temporary files or directories</li>
 * </ul>
 * 
 * <p>Requirements:
 * <ul>
 *   <li>The method must have no parameters</li>
 *   <li>The method must not be static</li>
 *   <li>The method may have any access modifier</li>
 *   <li>The method should not throw checked exceptions</li>
 * </ul>
 * 
 * <p>Example usage:
 * <pre>
 * &#64;Component
 * public class DatabaseService {
 *     private Connection connection;
 *     
 *     &#64;PostConstruct
 *     public void connect() {
 *         this.connection = DriverManager.getConnection(...);
 *     }
 *     
 *     &#64;PreDestroy
 *     public void disconnect() {
 *         if (connection != null) {
 *             try {
 *                 connection.close();
 *             } catch (SQLException e) {
 *                 logger.warning("Error closing connection: " + e.getMessage());
 *             }
 *         }
 *     }
 * }
 * </pre>
 * 
 * @since 0.2
 * @author Caner Mastan
 */
@Target(ElementType.METHOD)
@Retention(RetentionPolicy.RUNTIME)
public @interface PreDestroy {
} 