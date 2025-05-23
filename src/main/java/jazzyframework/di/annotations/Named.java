package jazzyframework.di.annotations;

import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

/**
 * Indicates that a component should be registered with a specific name.
 * Useful when you have multiple implementations of the same interface.
 * 
 * <p>Example usage:
 * <pre>
 * &#64;Component
 * &#64;Named("emailService")
 * public class EmailNotificationService implements NotificationService {
 *     // implementation
 * }
 * 
 * &#64;Component
 * &#64;Named("smsService")
 * public class SmsNotificationService implements NotificationService {
 *     // implementation
 * }
 * 
 * // In consumer class:
 * public UserService(&#64;Named("emailService") NotificationService notificationService) {
 *     // will inject EmailNotificationService
 * }
 * </pre>
 */
@Target({ElementType.TYPE, ElementType.PARAMETER, ElementType.FIELD})
@Retention(RetentionPolicy.RUNTIME)
public @interface Named {
    
    /**
     * The name of the component.
     * 
     * @return the component name
     */
    String value();
} 