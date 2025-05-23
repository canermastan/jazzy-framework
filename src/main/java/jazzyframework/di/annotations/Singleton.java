package jazzyframework.di.annotations;

import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

/**
 * Indicates that a component should be instantiated as a singleton.
 * Only one instance of the component will be created and shared across the application.
 * This is the default behavior for most components.
 * 
 * <p>Example usage:
 * <pre>
 * &#64;Component
 * &#64;Singleton
 * public class ConfigService {
 *     // Only one instance will be created
 * }
 * </pre>
 */
@Target(ElementType.TYPE)
@Retention(RetentionPolicy.RUNTIME)
public @interface Singleton {
} 