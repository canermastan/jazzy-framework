package jazzyframework.di.annotations;

import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

/**
 * Indicates that a component should be instantiated as a prototype.
 * A new instance of the component will be created every time it is requested.
 * 
 * <p>Example usage:
 * <pre>
 * &#64;Component
 * &#64;Prototype
 * public class RequestProcessor {
 *     // New instance created for each injection
 * }
 * </pre>
 */
@Target(ElementType.TYPE)
@Retention(RetentionPolicy.RUNTIME)
public @interface Prototype {
} 