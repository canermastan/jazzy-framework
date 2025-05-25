package jazzyframework.di.annotations;

import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

/**
 * Annotation to mark methods that should be called after dependency injection.
 * 
 * <p>Methods annotated with {@code @PostConstruct} are called automatically
 * by the DI container after all dependencies have been injected and the
 * object is fully constructed.
 * 
 * <p>This is useful for:
 * <ul>
 *   <li>Initializing resources that depend on injected dependencies</li>
 *   <li>Setting up configuration based on injected components</li>
 *   <li>Starting background processes or connections</li>
 *   <li>Validating the component's state after construction</li>
 * </ul>
 * 
 * <p>Requirements:
 * <ul>
 *   <li>The method must have no parameters</li>
 *   <li>The method must not be static</li>
 *   <li>The method may have any access modifier</li>
 *   <li>The method must not throw checked exceptions</li>
 * </ul>
 * 
 * <p>Example usage:
 * <pre>
 * &#64;Component
 * public class UserService {
 *     &#64;Inject
 *     private UserRepository userRepository;
 *     
 *     &#64;PostConstruct
 *     public void initialize() {
 *         // Perform initialization that requires injected dependencies
 *         if (userRepository.count() == 0) {
 *             createDefaultUsers();
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
public @interface PostConstruct {
} 