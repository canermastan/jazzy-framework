package jazzyframework.http;

import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.HashMap;
import java.util.Map;

/**
 * Standard API response wrapper for CRUD operations.
 * 
 * <p>This class provides a consistent response format across all CRUD endpoints.
 * It includes success status, message, data, and additional metadata like timestamp
 * and pagination information when applicable.
 * 
 * <p>Example JSON output:
 * <pre>
 * {
 *   "success": true,
 *   "message": "Users retrieved successfully",
 *   "data": [...],
 *   "timestamp": "2023-12-07T10:30:00",
 *   "pagination": {
 *     "page": 1,
 *     "size": 20,
 *     "total": 150,
 *     "totalPages": 8
 *   }
 * }
 * </pre>
 * 
 * @since 0.4.0
 * @author Caner Mastan
 */
public class ApiResponse {
    private boolean success;
    private String message;
    private Object data;
    private String timestamp;
    private Map<String, Object> metadata;
    
    /**
     * Default constructor.
     */
    public ApiResponse() {
        this.timestamp = LocalDateTime.now().format(DateTimeFormatter.ISO_LOCAL_DATE_TIME);
        this.metadata = new HashMap<>();
    }
    
    /**
     * Constructor with basic parameters.
     * 
     * @param success whether the operation was successful
     * @param message descriptive message
     * @param data the response data
     */
    public ApiResponse(boolean success, String message, Object data) {
        this();
        this.success = success;
        this.message = message;
        this.data = data;
    }
    
    /**
     * Creates a successful response.
     * 
     * @param message success message
     * @param data response data
     * @return ApiResponse instance
     */
    public static ApiResponse success(String message, Object data) {
        return new ApiResponse(true, message, data);
    }
    
    /**
     * Creates a successful response without data.
     * 
     * @param message success message
     * @return ApiResponse instance
     */
    public static ApiResponse success(String message) {
        return new ApiResponse(true, message, null);
    }
    
    /**
     * Creates an error response.
     * 
     * @param message error message
     * @param data error details (optional)
     * @return ApiResponse instance
     */
    public static ApiResponse error(String message, Object data) {
        return new ApiResponse(false, message, data);
    }
    
    /**
     * Creates an error response without data.
     * 
     * @param message error message
     * @return ApiResponse instance
     */
    public static ApiResponse error(String message) {
        return new ApiResponse(false, message, null);
    }
    
    /**
     * Adds pagination metadata to the response.
     * 
     * @param page current page number
     * @param size page size
     * @param total total number of items
     * @param totalPages total number of pages
     * @return this ApiResponse instance for method chaining
     */
    public ApiResponse withPagination(int page, int size, long total, int totalPages) {
        Map<String, Object> pagination = new HashMap<>();
        pagination.put("page", page);
        pagination.put("size", size);
        pagination.put("total", total);
        pagination.put("totalPages", totalPages);
        this.metadata.put("pagination", pagination);
        return this;
    }
    
    /**
     * Adds custom metadata to the response.
     * 
     * @param key metadata key
     * @param value metadata value
     * @return this ApiResponse instance for method chaining
     */
    public ApiResponse withMetadata(String key, Object value) {
        this.metadata.put(key, value);
        return this;
    }
    
    // Getters and setters
    
    public boolean isSuccess() {
        return success;
    }
    
    public void setSuccess(boolean success) {
        this.success = success;
    }
    
    public String getMessage() {
        return message;
    }
    
    public void setMessage(String message) {
        this.message = message;
    }
    
    public Object getData() {
        return data;
    }
    
    public void setData(Object data) {
        this.data = data;
    }
    
    public String getTimestamp() {
        return timestamp;
    }
    
    public void setTimestamp(String timestamp) {
        this.timestamp = timestamp;
    }
    
    public Map<String, Object> getMetadata() {
        return metadata;
    }
    
    public void setMetadata(Map<String, Object> metadata) {
        this.metadata = metadata;
    }
} 