package jazzyframework.data;

import jazzyframework.data.annotations.Crud;
import jazzyframework.di.DIContainer;
import jazzyframework.di.annotations.Component;
import jazzyframework.http.ApiResponse;
import jazzyframework.http.Request;
import jazzyframework.http.Response;
import jazzyframework.routing.Router;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.DisplayName;
import org.mockito.Mock;
import org.mockito.MockitoAnnotations;

import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import java.util.*;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

/**
 * Simplified test suite for CrudProcessor functionality.
 * Tests @Crud annotation processing and endpoint registration logic.
 */
class CrudProcessorTest {

    @Mock
    private Router mockRouter;
    
    @Mock
    private DIContainer mockDIContainer;
    
    private CrudProcessor crudProcessor;
    
    // Test entity for CRUD operations
    @Entity
    static class TestEntity {
        @Id
        private Long id;
        private String name;
        private String description;
        
        public TestEntity() {}
        
        public TestEntity(Long id, String name, String description) {
            this.id = id;
            this.name = name;
            this.description = description;
        }
        
        // Getters and setters
        public Long getId() { return id; }
        public void setId(Long id) { this.id = id; }
        public String getName() { return name; }
        public void setName(String name) { this.name = name; }
        public String getDescription() { return description; }
        public void setDescription(String description) { this.description = description; }
    }
    
    // Test controller with @Crud annotation
    @Component
    @Crud(
        entity = TestEntity.class,
        endpoint = "/api/test",
        enablePagination = true,
        enableSearch = true,
        searchableFields = {"name", "description"},
        enableBatchOperations = true,
        enableCount = true,
        enableExists = true
    )
    static class TestController {
        
        // Override findAll method
        public Response findAll(Request request) {
            return Response.json(ApiResponse.success("Custom findAll", Collections.emptyList()));
        }
    }
    
    // Test controller without @Crud annotation
    @Component
    static class NonCrudController {
        public Response getSomething(Request request) {
            return Response.json(ApiResponse.success("Something", null));
        }
    }
    
    @BeforeEach
    void setUp() {
        MockitoAnnotations.openMocks(this);
        crudProcessor = new CrudProcessor(mockRouter, mockDIContainer);
    }
    
    @Test
    @DisplayName("Should detect @Crud annotation correctly")
    void shouldDetectCrudAnnotation() {
        // Test that @Crud annotation is properly detected
        assertTrue(TestController.class.isAnnotationPresent(Crud.class));
        assertFalse(NonCrudController.class.isAnnotationPresent(Crud.class));
    }
    
    @Test
    @DisplayName("Should extract @Crud configuration values correctly")
    void shouldExtractCrudConfiguration() {
        Crud config = TestController.class.getAnnotation(Crud.class);
        
        // Verify configuration values
        assertEquals(TestEntity.class, config.entity());
        assertEquals("/api/test", config.endpoint());
        assertTrue(config.enablePagination());
        assertTrue(config.enableSearch());
        assertTrue(config.enableBatchOperations());
        assertTrue(config.enableCount());
        assertTrue(config.enableExists());
        assertArrayEquals(new String[]{"name", "description"}, config.searchableFields());
    }
    
    @Test
    @DisplayName("Should detect method overrides using reflection")
    void shouldDetectMethodOverrides() {
        // Test method override detection
        boolean hasOverride = false;
        try {
            TestController.class.getDeclaredMethod("findAll", Request.class);
            hasOverride = true;
        } catch (NoSuchMethodException e) {
            // Method not found
        }
        
        assertTrue(hasOverride, "TestController should have findAll method override");
        
        // Test that non-CRUD controller methods are not confused
        boolean hasNonCrudMethod = false;
        try {
            NonCrudController.class.getDeclaredMethod("getSomething", Request.class);
            hasNonCrudMethod = true;
        } catch (NoSuchMethodException e) {
            // Method not found
        }
        
        assertTrue(hasNonCrudMethod, "NonCrudController should have its own methods");
    }
    
    @Test
    @DisplayName("Should handle controllers without @Crud annotation gracefully")
    void shouldHandleNonCrudControllersGracefully() {
        // This should not throw any exceptions
        assertDoesNotThrow(() -> {
            crudProcessor.processController(NonCrudController.class);
        }, "Processing non-CRUD controller should not throw exceptions");
        
        // Verify no interactions with router for non-CRUD controllers
        verifyNoInteractions(mockRouter);
    }
    
    @Test
    @DisplayName("Should validate annotation parameter constraints")
    void shouldValidateAnnotationParameters() {
        Crud config = TestController.class.getAnnotation(Crud.class);
        
        // Validate required parameters
        assertNotNull(config.entity(), "Entity class should not be null");
        assertNotNull(config.endpoint(), "Endpoint should not be null");
        assertFalse(config.endpoint().trim().isEmpty(), "Endpoint should not be empty");
        
        // Validate numeric constraints
        assertTrue(config.defaultPageSize() > 0, "Default page size should be positive");
        assertTrue(config.maxPageSize() > 0, "Max page size should be positive");
        assertTrue(config.maxBatchSize() > 0, "Max batch size should be positive");
        assertTrue(config.maxPageSize() >= config.defaultPageSize(), 
            "Max page size should be >= default page size");
    }
    
    @Test
    @DisplayName("Should create proper endpoint paths")
    void shouldCreateProperEndpointPaths() {
        Crud config = TestController.class.getAnnotation(Crud.class);
        
        String endpoint = config.endpoint();
        assertNotNull(endpoint);
        assertTrue(endpoint.startsWith("/"), "Endpoint should start with /");
        assertFalse(endpoint.endsWith("/"), "Endpoint should not end with / for consistency");
    }
    
    @Test
    @DisplayName("Should handle boolean feature flags correctly")
    void shouldHandleBooleanFeatureFlags() {
        Crud config = TestController.class.getAnnotation(Crud.class);
        
        // All features enabled in TestController
        assertTrue(config.enablePagination());
        assertTrue(config.enableSearch());
        assertTrue(config.enableBatchOperations());
        assertTrue(config.enableCount());
        assertTrue(config.enableExists());
        
        // Default values for optional features
        assertFalse(config.softDelete()); // Default is false
        assertTrue(config.enableValidation()); // Default is true
        assertFalse(config.enableAuditLog()); // Default is false
    }
    
    @Test
    @DisplayName("Should handle array properties correctly")
    void shouldHandleArrayProperties() {
        Crud config = TestController.class.getAnnotation(Crud.class);
        
        // Search fields
        String[] searchFields = config.searchableFields();
        assertNotNull(searchFields);
        assertEquals(2, searchFields.length);
        assertTrue(Arrays.asList(searchFields).contains("name"));
        assertTrue(Arrays.asList(searchFields).contains("description"));
        
        // Exclude fields (should be empty by default)
        String[] excludeFields = config.excludeFields();
        assertNotNull(excludeFields);
        assertEquals(0, excludeFields.length);
    }
    
    @Test
    @DisplayName("Should provide proper default values")
    void shouldProvideProperDefaultValues() {
        // Create a minimal controller to test defaults
        @Crud(entity = TestEntity.class, endpoint = "/api/minimal")
        class MinimalController {}
        
        Crud config = MinimalController.class.getAnnotation(Crud.class);
        
        // Test default values
        assertEquals("id", config.idParam());
        assertEquals(20, config.defaultPageSize());
        assertEquals(100, config.maxPageSize());
        assertEquals(50, config.maxBatchSize());
        assertEquals("deletedAt", config.softDeleteField());
        assertEquals(ApiResponse.class, config.responseWrapper());
        
        // Test default boolean values
        assertFalse(config.enablePagination());
        assertFalse(config.enableSearch());
        assertFalse(config.enableBatchOperations());
        assertFalse(config.enableCount());
        assertFalse(config.enableExists());
        assertFalse(config.softDelete());
        assertTrue(config.enableValidation());
        assertFalse(config.enableAuditLog());
    }
} 