package jazzyframework.data;

import jazzyframework.data.annotations.Crud;
import jazzyframework.data.annotations.CrudOverride;
import jazzyframework.di.DIContainer;
import jazzyframework.di.annotations.Component;
import jazzyframework.http.ApiResponse;
import jazzyframework.http.Request;
import jazzyframework.http.Response;
import jazzyframework.routing.Router;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.DisplayName;

import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import java.lang.reflect.Constructor;
import java.util.*;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Integration tests for @Crud annotation functionality.
 * Tests the complete CRUD annotation workflow focusing on annotation processing.
 */
class CrudAnnotationIntegrationTest {

    private Router router;
    private DIContainer diContainer;
    private CrudProcessor crudProcessor;
    
    // Test entity
    @Entity
    static class TestProduct {
        @Id
        private Long id;
        private String name;
        private String description;
        private Double price;
        private Integer stock;
        
        public TestProduct() {}
        
        public TestProduct(Long id, String name, String description, Double price, Integer stock) {
            this.id = id;
            this.name = name;
            this.description = description;
            this.price = price;
            this.stock = stock;
        }
        
        // Getters and setters
        public Long getId() { return id; }
        public void setId(Long id) { this.id = id; }
        public String getName() { return name; }
        public void setName(String name) { this.name = name; }
        public String getDescription() { return description; }
        public void setDescription(String description) { this.description = description; }
        public Double getPrice() { return price; }
        public void setPrice(Double price) { this.price = price; }
        public Integer getStock() { return stock; }
        public void setStock(Integer stock) { this.stock = stock; }
    }
    
    // Test repository interface
    interface TestProductRepository extends BaseRepository<TestProduct, Long> {
    }
    
    // Full-featured CRUD controller
    @Component
    @Crud(
        entity = TestProduct.class,
        endpoint = "/api/products",
        enablePagination = true,
        enableSearch = true,
        searchableFields = {"name", "description"},
        enableBatchOperations = true,
        enableCount = true,
        enableExists = true,
        defaultPageSize = 20,
        maxPageSize = 100,
        maxBatchSize = 50
    )
    static class FullCrudController {
        private final TestProductRepository repository;
        
        public FullCrudController(TestProductRepository repository) {
            this.repository = repository;
        }
        
        // Override findAll to add custom logic
        @CrudOverride(value = "Custom findAll with stock filtering", operation = "findAll")
        public Response findAll(Request request) {
            return Response.json(ApiResponse.success("Custom findAll executed", 
                Collections.singletonList(new TestProduct(1L, "Test Product", "Test Description", 99.99, 10))));
        }
    }
    
    // Minimal CRUD controller
    @Component
    @Crud(entity = TestProduct.class, endpoint = "/api/simple-products")
    static class MinimalCrudController {
        private final TestProductRepository repository;
        
        public MinimalCrudController(TestProductRepository repository) {
            this.repository = repository;
        }
    }
    
    // Non-CRUD controller
    @Component
    static class RegularController {
        public Response getHealth(Request request) {
            return Response.json(ApiResponse.success("Healthy", null));
        }
    }
    
    @BeforeEach
    void setUp() {
        router = new Router();
        diContainer = new DIContainer();
        crudProcessor = new CrudProcessor(router, diContainer);
    }
    
    @Test
    @DisplayName("Should detect @Crud annotation on controllers")
    void shouldDetectCrudAnnotation() {
        // Test that @Crud annotation is properly detected
        assertTrue(FullCrudController.class.isAnnotationPresent(Crud.class));
        assertTrue(MinimalCrudController.class.isAnnotationPresent(Crud.class));
        assertFalse(RegularController.class.isAnnotationPresent(Crud.class));
    }
    
    @Test
    @DisplayName("Should extract @Crud configuration correctly")
    void shouldExtractCrudConfiguration() {
        Crud fullConfig = FullCrudController.class.getAnnotation(Crud.class);
        
        // Verify configuration values
        assertEquals(TestProduct.class, fullConfig.entity());
        assertEquals("/api/products", fullConfig.endpoint());
        assertTrue(fullConfig.enablePagination());
        assertTrue(fullConfig.enableSearch());
        assertTrue(fullConfig.enableBatchOperations());
        assertTrue(fullConfig.enableCount());
        assertTrue(fullConfig.enableExists());
        assertEquals(20, fullConfig.defaultPageSize());
        assertEquals(100, fullConfig.maxPageSize());
        assertEquals(50, fullConfig.maxBatchSize());
        assertArrayEquals(new String[]{"name", "description"}, fullConfig.searchableFields());
    }
    
    @Test
    @DisplayName("Should extract minimal @Crud configuration with defaults")
    void shouldExtractMinimalCrudConfiguration() {
        Crud minimalConfig = MinimalCrudController.class.getAnnotation(Crud.class);
        
        // Verify configuration values with defaults
        assertEquals(TestProduct.class, minimalConfig.entity());
        assertEquals("/api/simple-products", minimalConfig.endpoint());
        assertFalse(minimalConfig.enablePagination()); // Default is false
        assertFalse(minimalConfig.enableSearch()); // Default is false
        assertFalse(minimalConfig.enableBatchOperations()); // Default is false
        assertEquals(20, minimalConfig.defaultPageSize()); // Default value is 20, not 10
        assertEquals(100, minimalConfig.maxPageSize()); // Default value
    }
    
    @Test
    @DisplayName("Should detect method overrides correctly")
    void shouldDetectMethodOverrides() {
        // Check if FullCrudController has findAll method override
        boolean hasFindAll = false;
        try {
            FullCrudController.class.getDeclaredMethod("findAll", Request.class);
            hasFindAll = true;
        } catch (NoSuchMethodException e) {
            // Method not found
        }
        
        assertTrue(hasFindAll, "FullCrudController should have findAll method override");
        
        // Check if MinimalCrudController doesn't have overrides
        boolean hasMinimalFindAll = false;
        try {
            MinimalCrudController.class.getDeclaredMethod("findAll", Request.class);
            hasMinimalFindAll = true;
        } catch (NoSuchMethodException e) {
            // Method not found - this is expected
        }
        
        assertFalse(hasMinimalFindAll, "MinimalCrudController should not have findAll method override");
    }
    
    @Test
    @DisplayName("Should handle @CrudOverride annotation correctly")
    void shouldHandleCrudOverrideAnnotation() {
        try {
            java.lang.reflect.Method findAllMethod = FullCrudController.class.getDeclaredMethod("findAll", Request.class);
            
            // Check if method has @CrudOverride annotation
            boolean hasOverrideAnnotation = findAllMethod.isAnnotationPresent(CrudOverride.class);
            assertTrue(hasOverrideAnnotation, "Overridden method should have @CrudOverride annotation");
            
            if (hasOverrideAnnotation) {
                CrudOverride overrideAnnotation = findAllMethod.getAnnotation(CrudOverride.class);
                assertEquals("Custom findAll with stock filtering", overrideAnnotation.value());
                assertEquals("findAll", overrideAnnotation.operation());
            }
        } catch (NoSuchMethodException e) {
            fail("findAll method should exist in FullCrudController");
        }
    }
    
    @Test
    @DisplayName("Should validate CRUD annotation parameters")
    void shouldValidateCrudAnnotationParameters() {
        Crud config = FullCrudController.class.getAnnotation(Crud.class);
        
        // Validate required parameters
        assertNotNull(config.entity(), "Entity class should not be null");
        assertNotNull(config.endpoint(), "Endpoint should not be null");
        assertFalse(config.endpoint().trim().isEmpty(), "Endpoint should not be empty");
        
        // Validate optional parameters have reasonable defaults
        assertTrue(config.defaultPageSize() > 0, "Default page size should be positive");
        assertTrue(config.maxPageSize() > 0, "Max page size should be positive");
        assertTrue(config.maxBatchSize() > 0, "Max batch size should be positive");
        assertTrue(config.maxPageSize() >= config.defaultPageSize(), 
            "Max page size should be >= default page size");
    }
    
    @Test
    @DisplayName("Should create endpoint paths correctly")
    void shouldCreateEndpointPathsCorrectly() {
        Crud fullConfig = FullCrudController.class.getAnnotation(Crud.class);
        Crud minimalConfig = MinimalCrudController.class.getAnnotation(Crud.class);
        
        // Verify endpoint paths
        assertEquals("/api/products", fullConfig.endpoint());
        assertEquals("/api/simple-products", minimalConfig.endpoint());
        
        // Verify ID parameter name
        assertEquals("id", fullConfig.idParam()); // Default value
        assertEquals("id", minimalConfig.idParam()); // Default value
    }
    
    @Test
    @DisplayName("Should validate all annotation properties")
    void shouldValidateAllAnnotationProperties() {
        Crud config = FullCrudController.class.getAnnotation(Crud.class);
        
        // Test all string array properties
        assertTrue(config.searchableFields().length > 0, "Searchable fields should not be empty when search is enabled");
        assertTrue(config.excludeFields().length == 0, "Excluded fields should be empty by default");
        
        // Test boolean properties
        assertTrue(config.enablePagination());
        assertTrue(config.enableSearch());
        assertTrue(config.enableBatchOperations());
        assertTrue(config.enableCount());
        assertTrue(config.enableExists());
        assertFalse(config.softDelete()); // Default is false
        assertTrue(config.enableValidation()); // Default is true
        assertFalse(config.enableAuditLog()); // Default is false
        
        // Test numeric properties
        assertEquals(20, config.defaultPageSize());
        assertEquals(100, config.maxPageSize());
        assertEquals(50, config.maxBatchSize());
        
        // Test string properties
        assertEquals("/api/products", config.endpoint());
        assertEquals("id", config.idParam());
        assertEquals("deletedAt", config.softDeleteField());
        assertEquals(ApiResponse.class, config.responseWrapper());
    }
    
    @Test
    @DisplayName("Should handle controller class hierarchy")
    void shouldHandleControllerClassHierarchy() {
        // Test that we can properly inspect controller classes
        assertNotNull(FullCrudController.class.getConstructors());
        assertTrue(FullCrudController.class.getConstructors().length > 0);
        
        // Verify class has proper @Component annotation
        assertTrue(FullCrudController.class.isAnnotationPresent(Component.class));
        
        // Verify class has proper repository dependency
        Constructor<?>[] constructors = FullCrudController.class.getConstructors();
        boolean hasRepositoryDependency = false;
        for (Constructor<?> constructor : constructors) {
            if (constructor.getParameterTypes().length > 0 && 
                BaseRepository.class.isAssignableFrom(constructor.getParameterTypes()[0])) {
                hasRepositoryDependency = true;
                break;
            }
        }
        assertTrue(hasRepositoryDependency, "Controller should have repository dependency");
    }
} 