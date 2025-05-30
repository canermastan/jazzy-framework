package jazzyframework.data.annotations;

import jazzyframework.http.ApiResponse;
import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

/**
 * Annotation for automatically generating CRUD endpoints and operations.
 * 
 * <p>This annotation can be placed on controller classes to automatically generate
 * standard CRUD operations (Create, Read, Update, Delete) along with additional
 * useful endpoints for the specified entity.
 * 
 * <p>Generated endpoints:
 * <ul>
 *   <li>GET /endpoint - findAll (with pagination support)</li>
 *   <li>GET /endpoint/{id} - findById</li>
 *   <li>POST /endpoint - create</li>
 *   <li>PUT /endpoint/{id} - update</li>
 *   <li>DELETE /endpoint/{id} - delete</li>
 *   <li>POST /endpoint/batch - createBatch (if enabled)</li>
 *   <li>PUT /endpoint/batch - updateBatch (if enabled)</li>
 *   <li>DELETE /endpoint/batch - deleteBatch (if enabled)</li>
 *   <li>GET /endpoint/search - search (if enabled)</li>
 *   <li>GET /endpoint/count - count (if enabled)</li>
 *   <li>GET /endpoint/exists/{id} - exists (if enabled)</li>
 * </ul>
 * 
 * <p>Example usage:
 * <pre>
 * {@code
 * @Component
 * @Crud(
 *     entity = User.class,
 *     endpoint = "/api/users",
 *     enablePagination = true,
 *     enableBatchOperations = true,
 *     enableSearch = true
 * )
 * public class UserController {
 *     // Custom methods can be added alongside auto-generated ones
 * }
 * }
 * </pre>
 * 
 * @since 0.4.0
 * @author Caner Mastan
 */
@Target(ElementType.TYPE)
@Retention(RetentionPolicy.RUNTIME)
public @interface Crud {
    
    /**
     * The entity class that this CRUD controller manages.
     * 
     * @return the entity class
     */
    Class<?> entity();
    
    /**
     * The base endpoint path for CRUD operations.
     * 
     * @return the endpoint path (e.g., "/api/users")
     */
    String endpoint();
    
    /**
     * The name of the path parameter used for entity ID.
     * 
     * @return the ID parameter name (default: "id")
     */
    String idParam() default "id";
    
    /**
     * Custom response wrapper class to use instead of the default ApiResponse.
     * The wrapper class must have a constructor that accepts (boolean success, String message, Object data).
     * 
     * @return the response wrapper class
     */
    Class<? extends ApiResponse> responseWrapper() default ApiResponse.class;
    
    // === PAGINATION SETTINGS ===
    
    /**
     * Whether to enable pagination for findAll operations.
     * 
     * @return true to enable pagination
     */
    boolean enablePagination() default false;
    
    /**
     * Default page size when pagination is enabled.
     * 
     * @return the default page size
     */
    int defaultPageSize() default 20;
    
    /**
     * Maximum allowed page size to prevent performance issues.
     * 
     * @return the maximum page size
     */
    int maxPageSize() default 100;
    
    // === BATCH OPERATIONS ===
    
    /**
     * Whether to enable batch operations (createBatch, updateBatch, deleteBatch).
     * 
     * @return true to enable batch operations
     */
    boolean enableBatchOperations() default false;
    
    /**
     * Maximum number of entities allowed in a single batch operation.
     * 
     * @return the maximum batch size
     */
    int maxBatchSize() default 50;
    
    // === SEARCH & QUERY OPERATIONS ===
    
    /**
     * Whether to enable search endpoint with query parameters.
     * 
     * @return true to enable search operations
     */
    boolean enableSearch() default false;
    
    /**
     * Fields that can be searched/filtered in search operations.
     * If empty, all fields are searchable.
     * 
     * @return array of searchable field names
     */
    String[] searchableFields() default {};
    
    // === UTILITY OPERATIONS ===
    
    /**
     * Whether to enable count endpoint for getting total entity count.
     * 
     * @return true to enable count operation
     */
    boolean enableCount() default false;
    
    /**
     * Whether to enable exists endpoint for checking entity existence.
     * 
     * @return true to enable exists operation
     */
    boolean enableExists() default false;
    
    // === DELETION SETTINGS ===
    
    /**
     * Whether to use soft delete instead of hard delete.
     * 
     * @return true for soft delete
     */
    boolean softDelete() default false;
    
    /**
     * Field name used for soft delete timestamp.
     * 
     * @return the soft delete field name
     */
    String softDeleteField() default "deletedAt";
    
    // === VALIDATION & SECURITY ===
    
    /**
     * Whether to enable input validation on create/update operations.
     * 
     * @return true to enable validation
     */
    boolean enableValidation() default true;
    
    /**
     * Fields to exclude from response (e.g., passwords, sensitive data).
     * 
     * @return array of field names to exclude
     */
    String[] excludeFields() default {};
    
    /**
     * Whether to enable audit logging for CRUD operations.
     * 
     * @return true to enable audit logging
     */
    boolean enableAuditLog() default false;
} 