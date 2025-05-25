package jazzyframework.data.annotations;

import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

/**
 * Annotation to indicate that a query method modifies the database.
 * 
 * <p>This annotation should be used with {@code @Query} for UPDATE, DELETE,
 * or INSERT operations. It tells the framework that the query will modify
 * the database state and should be executed accordingly.
 * 
 * <p>Examples:
 * <pre>
 * {@code @Query("UPDATE User u SET u.active = :active WHERE u.email = :email")}
 * {@code @Modifying}
 * int updateUserActiveStatus(String email, boolean active);
 * 
 * {@code @Query("DELETE FROM User u WHERE u.active = false")}
 * {@code @Modifying}
 * int deleteInactiveUsers();
 * </pre>
 * 
 * @since 0.3.0
 * @author Caner Mastan
 */
@Target(ElementType.METHOD)
@Retention(RetentionPolicy.RUNTIME)
public @interface Modifying {
    
    /**
     * Whether to clear the persistence context after executing the modifying query.
     * 
     * <p>If true, the persistence context will be cleared after the query execution,
     * which ensures that subsequent queries will see the updated state.
     * 
     * @return true to clear context, false otherwise
     */
    boolean clearAutomatically() default false;
    
    /**
     * Whether to flush the persistence context before executing the modifying query.
     * 
     * <p>If true, pending changes will be flushed to the database before
     * executing the modifying query.
     * 
     * @return true to flush before execution, false otherwise
     */
    boolean flushAutomatically() default false;
} 