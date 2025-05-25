package jazzyframework.data.annotations;

import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

/**
 * Annotation to define custom queries for repository methods.
 * 
 * <p>This annotation allows you to define custom HQL/JPQL or native SQL queries
 * for repository methods, similar to Spring Data JPA's @Query annotation.
 * 
 * <p>Examples:
 * <pre>
 * // HQL/JPQL Query
 * {@code @Query("SELECT u FROM User u WHERE u.email = :email AND u.active = true")}
 * Optional&lt;User&gt; findActiveUserByEmail(String email);
 * 
 * // Native SQL Query
 * {@code @Query(value = "SELECT * FROM users WHERE email = ?1", nativeQuery = true)}
 * Optional&lt;User&gt; findByEmailNative(String email);
 * 
 * // Count Query
 * {@code @Query("SELECT COUNT(u) FROM User u WHERE u.active = :active")}
 * long countActiveUsers(boolean active);
 * 
 * // Update Query
 * {@code @Query("UPDATE User u SET u.active = :active WHERE u.email = :email")}
 * {@code @Modifying}
 * int updateUserActiveStatus(String email, boolean active);
 * </pre>
 * 
 * @since 0.3.0
 * @author Caner Mastan
 */
@Target(ElementType.METHOD)
@Retention(RetentionPolicy.RUNTIME)
public @interface Query {
    
    /**
     * The query string to execute.
     * Can be HQL/JPQL (default) or native SQL (if nativeQuery = true).
     * 
     * <p>Parameter binding:
     * <ul>
     *   <li>Named parameters: {@code :paramName} (recommended)</li>
     *   <li>Positional parameters: {@code ?1, ?2, ...} (for native queries)</li>
     * </ul>
     * 
     * @return the query string
     */
    String value();
    
    /**
     * Whether the query is a native SQL query.
     * 
     * <p>If true, the query will be executed as native SQL.
     * If false (default), the query will be executed as HQL/JPQL.
     * 
     * @return true for native SQL, false for HQL/JPQL
     */
    boolean nativeQuery() default false;
    
    /**
     * The name of the named query to use.
     * If specified, the value() will be ignored and the named query will be used instead.
     * 
     * @return the named query name
     */
    String name() default "";
    
    /**
     * Query hints to be applied to the query.
     * These are JPA query hints that can be used to optimize query execution.
     * 
     * @return array of query hints
     */
    QueryHint[] hints() default {};
} 