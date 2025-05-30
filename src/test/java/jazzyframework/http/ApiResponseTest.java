package jazzyframework.http;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.BeforeEach;

import java.util.*;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Test suite for ApiResponse class functionality.
 * Tests response creation, metadata handling, and pagination support.
 */
class ApiResponseTest {

    private List<Object> testData;
    private Map<String, Object> testMetadata;
    
    @BeforeEach
    void setUp() {
        testData = Arrays.asList("item1", "item2", "item3");
        testMetadata = new HashMap<>();
        testMetadata.put("key1", "value1");
        testMetadata.put("key2", 42);
    }
    
    @Test
    @DisplayName("Should create success response correctly")
    void shouldCreateSuccessResponse() {
        ApiResponse response = ApiResponse.success("Operation completed", testData);
        
        assertTrue(response.isSuccess());
        assertEquals("Operation completed", response.getMessage());
        assertEquals(testData, response.getData());
        assertNotNull(response.getTimestamp());
        assertNotNull(response.getMetadata());
    }
    
    @Test
    @DisplayName("Should create error response correctly")
    void shouldCreateErrorResponse() {
        ApiResponse response = ApiResponse.error("Operation failed", null);
        
        assertFalse(response.isSuccess());
        assertEquals("Operation failed", response.getMessage());
        assertNull(response.getData());
        assertNotNull(response.getTimestamp());
        assertNotNull(response.getMetadata());
    }
    
    @Test
    @DisplayName("Should create success response with custom metadata")
    void shouldCreateSuccessResponseWithMetadata() {
        ApiResponse response = ApiResponse.success("Operation completed", testData);
        response.withMetadata("key1", "value1");
        response.withMetadata("key2", 42);
        
        assertTrue(response.isSuccess());
        assertEquals("Operation completed", response.getMessage());
        assertEquals(testData, response.getData());
        assertEquals("value1", response.getMetadata().get("key1"));
        assertEquals(42, response.getMetadata().get("key2"));
        assertNotNull(response.getTimestamp());
    }
    
    @Test
    @DisplayName("Should create error response with custom metadata")
    void shouldCreateErrorResponseWithMetadata() {
        ApiResponse response = ApiResponse.error("Operation failed", null);
        response.withMetadata("errorCode", 500);
        response.withMetadata("details", "Internal server error");
        
        assertFalse(response.isSuccess());
        assertEquals("Operation failed", response.getMessage());
        assertNull(response.getData());
        assertEquals(500, response.getMetadata().get("errorCode"));
        assertEquals("Internal server error", response.getMetadata().get("details"));
        assertNotNull(response.getTimestamp());
    }
    
    @Test
    @DisplayName("Should create response with pagination metadata")
    void shouldCreateResponseWithPagination() {
        List<Object> pageData = Arrays.asList("item1", "item2");
        
        ApiResponse response = ApiResponse.success("Data retrieved successfully", pageData);
        response.withPagination(1, 2, 10L, 5);
        
        assertTrue(response.isSuccess());
        assertEquals("Data retrieved successfully", response.getMessage());
        assertEquals(pageData, response.getData());
        
        Map<String, Object> metadata = response.getMetadata();
        assertNotNull(metadata);
        assertTrue(metadata.containsKey("pagination"));
        
        @SuppressWarnings("unchecked")
        Map<String, Object> pagination = (Map<String, Object>) metadata.get("pagination");
        assertEquals(1, pagination.get("page"));
        assertEquals(2, pagination.get("size"));
        assertEquals(10L, pagination.get("total"));
        assertEquals(5, pagination.get("totalPages"));
    }
    
    @Test
    @DisplayName("Should handle method chaining correctly")
    void shouldHandleMethodChainingCorrectly() {
        ApiResponse response = ApiResponse.success("Success", testData)
            .withPagination(0, 10, 100L, 10)
            .withMetadata("source", "test")
            .withMetadata("version", "1.0");
        
        assertTrue(response.isSuccess());
        assertEquals("Success", response.getMessage());
        assertEquals(testData, response.getData());
        
        Map<String, Object> metadata = response.getMetadata();
        assertTrue(metadata.containsKey("pagination"));
        assertEquals("test", metadata.get("source"));
        assertEquals("1.0", metadata.get("version"));
    }
    
    @Test
    @DisplayName("Should handle empty data correctly")
    void shouldHandleEmptyDataCorrectly() {
        ApiResponse response = ApiResponse.success("No data found", Collections.emptyList());
        
        assertTrue(response.isSuccess());
        assertEquals("No data found", response.getMessage());
        assertTrue(((List<?>) response.getData()).isEmpty());
    }
    
    @Test
    @DisplayName("Should handle null data correctly")
    void shouldHandleNullDataCorrectly() {
        ApiResponse response = ApiResponse.success("Success", null);
        
        assertTrue(response.isSuccess());
        assertEquals("Success", response.getMessage());
        assertNull(response.getData());
    }
    
    @Test
    @DisplayName("Should create response without data using overloaded method")
    void shouldCreateResponseWithoutData() {
        ApiResponse successResponse = ApiResponse.success("Operation completed");
        ApiResponse errorResponse = ApiResponse.error("Operation failed");
        
        assertTrue(successResponse.isSuccess());
        assertEquals("Operation completed", successResponse.getMessage());
        assertNull(successResponse.getData());
        
        assertFalse(errorResponse.isSuccess());
        assertEquals("Operation failed", errorResponse.getMessage());
        assertNull(errorResponse.getData());
    }
    
    @Test
    @DisplayName("Should preserve timestamp immutability")
    void shouldPreserveTimestampImmutability() {
        ApiResponse response1 = ApiResponse.success("Test", null);
        
        try {
            Thread.sleep(1);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
        
        ApiResponse response2 = ApiResponse.success("Test", null);
        
        assertNotEquals(response1.getTimestamp(), response2.getTimestamp());
    }
    
    @Test
    @DisplayName("Should allow metadata modification")
    void shouldAllowMetadataModification() {
        ApiResponse response = ApiResponse.success("Test", null);
        
        response.withMetadata("initial", "value");
        assertEquals("value", response.getMetadata().get("initial"));
        
        response.withMetadata("initial", "modified");
        assertEquals("modified", response.getMetadata().get("initial"));
    }
    
    @Test
    @DisplayName("Should create factory method responses consistently")
    void shouldCreateFactoryMethodResponsesConsistently() {
        ApiResponse response1 = ApiResponse.success("Test message");
        ApiResponse response2 = ApiResponse.success("Test message", null);
        
        assertEquals(response1.isSuccess(), response2.isSuccess());
        assertEquals(response1.getMessage(), response2.getMessage());
        assertEquals(response1.getData(), response2.getData());
        
        ApiResponse errorResponse1 = ApiResponse.error("Error message");
        ApiResponse errorResponse2 = ApiResponse.error("Error message", null);
        
        assertEquals(errorResponse1.isSuccess(), errorResponse2.isSuccess());
        assertEquals(errorResponse1.getMessage(), errorResponse2.getMessage());
        assertEquals(errorResponse1.getData(), errorResponse2.getData());
    }
    
    @Test
    @DisplayName("Should handle constructor properly")
    void shouldHandleConstructorProperly() {
        ApiResponse response = new ApiResponse(true, "Test message", testData);
        
        assertTrue(response.isSuccess());
        assertEquals("Test message", response.getMessage());
        assertEquals(testData, response.getData());
        assertNotNull(response.getTimestamp());
        assertNotNull(response.getMetadata());
        assertTrue(response.getMetadata().isEmpty());
    }
} 