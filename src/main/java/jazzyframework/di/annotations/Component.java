package jazzyframework.di.annotations;

import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

/**
 * Indicates that a class is a component and should be managed by the DI container.
 * Components are automatically detected and registered when package scanning is enabled.
 * 
 * <p>Example usage:
 * <pre>
 * &#64;Component
 * public class UserService {
 *     // implementation
 * }
 * </pre>
 */
@Target(ElementType.TYPE)
@Retention(RetentionPolicy.RUNTIME)
public @interface Component {
    
    /**
     * The name of the component.
     * If not specified, the simple class name will be used.
     * 
     * @return the component name
     */
    String value() default "";
} 