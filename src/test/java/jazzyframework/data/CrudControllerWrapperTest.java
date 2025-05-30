package jazzyframework.data;

import jazzyframework.data.annotations.Crud;
import jazzyframework.http.ApiResponse;
import jazzyframework.http.Request;
import jazzyframework.http.Response;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.Mock;
import org.mockito.MockitoAnnotations;

import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import java.util.*;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;
import static org.mockito.ArgumentMatchers.*;

/**
 * Test suite for CrudControllerWrapper functionality.
 * Tests CRUD operations, pagination, search, and batch operations.
 */
class CrudControllerWrapperTest {

    @Mock
    private BaseRepository<Object, Object> mockRepository;
    
    @Mock
    private Request mockRequest;
    
    private CrudProcessor.CrudControllerWrapper wrapper;
    
    // Test entity
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
    
    // Test @Crud configuration
    @Crud(
        entity = TestEntity.class,
        endpoint = "/api/test",
        enablePagination = true,
        enableSearch = true,
        searchableFields = {"name", "description"},
        enableBatchOperations = true,
        defaultPageSize = 10,
        maxPageSize = 100
    )
    static class TestCrudConfig {
        // Used to get @Crud annotation for testing
    }
    
    @BeforeEach
    void setUp() {
        MockitoAnnotations.openMocks(this);
        
        // Get @Crud annotation from test class
        Crud crudConfig = TestCrudConfig.class.getAnnotation(Crud.class);
        
        // Create wrapper with mocked repository
        wrapper = new CrudProcessor.CrudControllerWrapper(
            mockRepository, TestEntity.class, Long.class, crudConfig
        );
    }
    
    @Test
    void testFindAll_WithoutPagination_ReturnsAllEntities() {
        // Arrange
        List<Object> entities = Arrays.asList(
            new TestEntity(1L, "Entity1", "Description1"),
            new TestEntity(2L, "Entity2", "Description2")
        );
        when(mockRepository.findAll()).thenReturn(entities);
        
        // Create wrapper without pagination
        Crud noPaginationConfig = mock(Crud.class);
        when(noPaginationConfig.enablePagination()).thenReturn(false);
        CrudProcessor.CrudControllerWrapper noPaginationWrapper = 
            new CrudProcessor.CrudControllerWrapper(mockRepository, TestEntity.class, Long.class, noPaginationConfig);
        
        // Act
        Response response = noPaginationWrapper.findAll(mockRequest);
        
        // Assert
        assertEquals(200, response.getStatusCode());
        verify(mockRepository).findAll();
    }
    
    @Test
    void testFindAll_WithPagination_ReturnsPagedResults() {
        // Arrange
        List<Object> entities = Arrays.asList(
            new TestEntity(1L, "Entity1", "Description1"),
            new TestEntity(2L, "Entity2", "Description2"),
            new TestEntity(3L, "Entity3", "Description3")
        );
        when(mockRepository.findAll()).thenReturn(entities);
        when(mockRequest.queryInt("page", 1)).thenReturn(1);
        when(mockRequest.queryInt("size", 10)).thenReturn(2);
        
        // Act
        Response response = wrapper.findAll(mockRequest);
        
        // Assert
        assertEquals(200, response.getStatusCode());
        verify(mockRepository).findAll();
        verify(mockRequest).queryInt("page", 1);
        verify(mockRequest).queryInt("size", 10);
    }
    
    @Test
    void testFindById_ExistingEntity_ReturnsEntity() {
        // Arrange
        TestEntity entity = new TestEntity(1L, "Test", "Description");
        when(mockRepository.findById(1L)).thenReturn(Optional.of(entity));
        when(mockRequest.path("id")).thenReturn("1");
        
        // Act
        Response response = wrapper.findById(mockRequest);
        
        // Assert
        assertEquals(200, response.getStatusCode());
        verify(mockRepository).findById(1L);
        verify(mockRequest).path("id");
    }
    
    @Test
    void testFindById_NonExistingEntity_Returns404() {
        // Arrange
        when(mockRepository.findById(999L)).thenReturn(Optional.empty());
        when(mockRequest.path("id")).thenReturn("999");
        
        // Act
        Response response = wrapper.findById(mockRequest);
        
        // Assert
        assertEquals(404, response.getStatusCode());
        verify(mockRepository).findById(999L);
    }
    
    @Test
    void testCreate_ValidEntity_ReturnsCreatedEntity() {
        // Arrange
        TestEntity inputEntity = new TestEntity(null, "New Entity", "New Description");
        TestEntity savedEntity = new TestEntity(1L, "New Entity", "New Description");
        
        when(mockRequest.toObject(TestEntity.class)).thenReturn(inputEntity);
        when(mockRepository.save(inputEntity)).thenReturn(savedEntity);
        
        // Act
        Response response = wrapper.create(mockRequest);
        
        // Assert
        assertEquals(201, response.getStatusCode());
        verify(mockRequest).toObject(TestEntity.class);
        verify(mockRepository).save(inputEntity);
    }
    
    @Test
    void testUpdate_ExistingEntity_ReturnsUpdatedEntity() {
        // Arrange
        TestEntity updateEntity = new TestEntity(1L, "Updated Entity", "Updated Description");
        
        when(mockRequest.path("id")).thenReturn("1");
        when(mockRequest.toObject(TestEntity.class)).thenReturn(updateEntity);
        when(mockRepository.existsById(1L)).thenReturn(true);
        when(mockRepository.save(updateEntity)).thenReturn(updateEntity);
        
        // Act
        Response response = wrapper.update(mockRequest);
        
        // Assert
        assertEquals(200, response.getStatusCode());
        verify(mockRepository).existsById(1L);
        verify(mockRepository).save(updateEntity);
    }
    
    @Test
    void testUpdate_NonExistingEntity_Returns404() {
        // Arrange
        when(mockRequest.path("id")).thenReturn("999");
        when(mockRepository.existsById(999L)).thenReturn(false);
        
        // Act
        Response response = wrapper.update(mockRequest);
        
        // Assert
        assertEquals(404, response.getStatusCode());
        verify(mockRepository).existsById(999L);
        verify(mockRepository, never()).save(any());
    }
    
    @Test
    void testDelete_ExistingEntity_DeletesSuccessfully() {
        // Arrange
        when(mockRequest.path("id")).thenReturn("1");
        when(mockRepository.existsById(1L)).thenReturn(true);
        
        // Act
        Response response = wrapper.delete(mockRequest);
        
        // Assert
        assertEquals(200, response.getStatusCode());
        verify(mockRepository).existsById(1L);
        verify(mockRepository).deleteById(1L);
    }
    
    @Test
    void testDelete_NonExistingEntity_Returns404() {
        // Arrange
        when(mockRequest.path("id")).thenReturn("999");
        when(mockRepository.existsById(999L)).thenReturn(false);
        
        // Act
        Response response = wrapper.delete(mockRequest);
        
        // Assert
        assertEquals(404, response.getStatusCode());
        verify(mockRepository).existsById(999L);
        verify(mockRepository, never()).deleteById(any());
    }
    
    @Test
    void testSearch_WithSearchableFields_FiltersResults() {
        // Arrange
        List<Object> entities = Arrays.asList(
            new TestEntity(1L, "Laptop", "Gaming laptop"),
            new TestEntity(2L, "Mouse", "Gaming mouse"),
            new TestEntity(3L, "Keyboard", "Mechanical keyboard")
        );
        when(mockRepository.findAll()).thenReturn(entities);
        when(mockRequest.query("name")).thenReturn("Laptop");
        when(mockRequest.query("description")).thenReturn(null);
        when(mockRequest.query("q", "")).thenReturn("");
        
        // Act
        Response response = wrapper.search(mockRequest);
        
        // Assert
        assertEquals(200, response.getStatusCode());
        verify(mockRepository).findAll();
        verify(mockRequest, atLeastOnce()).query(anyString());
    }
    
    @Test
    void testCount_ReturnsEntityCount() {
        // Arrange
        List<Object> entities = Arrays.asList(
            new TestEntity(1L, "Entity1", "Description1"),
            new TestEntity(2L, "Entity2", "Description2")
        );
        when(mockRepository.findAll()).thenReturn(entities);
        
        // Act
        Response response = wrapper.count(mockRequest);
        
        // Assert
        assertEquals(200, response.getStatusCode());
        verify(mockRepository).findAll();
    }
    
    @Test
    void testExists_ExistingEntity_ReturnsTrue() {
        // Arrange
        when(mockRequest.path("id")).thenReturn("1");
        when(mockRepository.existsById(1L)).thenReturn(true);
        
        // Act
        Response response = wrapper.exists(mockRequest);
        
        // Assert
        assertEquals(200, response.getStatusCode());
        verify(mockRepository).existsById(1L);
    }
    
    @Test
    void testExists_NonExistingEntity_ReturnsFalse() {
        // Arrange
        when(mockRequest.path("id")).thenReturn("999");
        when(mockRepository.existsById(999L)).thenReturn(false);
        
        // Act
        Response response = wrapper.exists(mockRequest);
        
        // Assert
        assertEquals(200, response.getStatusCode());
        verify(mockRepository).existsById(999L);
    }
    
    @Test
    void testCreateBatch_ValidEntities_CreatesAll() {
        // Arrange
        Map<String, Object> jsonData = new HashMap<>();
        List<Map<String, Object>> entitiesData = Arrays.asList(
            Map.of("name", "Entity1", "description", "Desc1"),
            Map.of("name", "Entity2", "description", "Desc2")
        );
        jsonData.put("entities", entitiesData);
        
        when(mockRequest.parseJson()).thenReturn(jsonData);
        when(mockRepository.save(any())).thenReturn(new TestEntity(1L, "Entity1", "Desc1"));
        
        // Act
        Response response = wrapper.createBatch(mockRequest);
        
        // Assert
        assertEquals(201, response.getStatusCode());
        verify(mockRequest).parseJson();
        verify(mockRepository, times(2)).save(any());
    }
    
    @Test
    void testCreateBatch_ExceedsMaxBatchSize_Returns400() {
        // Arrange
        Map<String, Object> jsonData = new HashMap<>();
        List<Map<String, Object>> entitiesData = new ArrayList<>();
        
        // Create more entities than maxBatchSize (default is 100, but let's create 101)
        for (int i = 0; i < 101; i++) {
            entitiesData.add(Map.of("name", "Entity" + i, "description", "Desc" + i));
        }
        jsonData.put("entities", entitiesData);
        
        when(mockRequest.parseJson()).thenReturn(jsonData);
        
        // Act
        Response response = wrapper.createBatch(mockRequest);
        
        // Assert
        assertEquals(400, response.getStatusCode());
        verify(mockRepository, never()).save(any());
    }
    
    @Test
    void testUpdateBatch_ValidEntities_UpdatesAll() {
        // Arrange
        Map<String, Object> jsonData = new HashMap<>();
        List<Map<String, Object>> entitiesData = Arrays.asList(
            Map.of("id", 1, "name", "Updated Entity1", "description", "Updated Desc1"),
            Map.of("id", 2, "name", "Updated Entity2", "description", "Updated Desc2")
        );
        jsonData.put("entities", entitiesData);
        
        when(mockRequest.parseJson()).thenReturn(jsonData);
        when(mockRepository.existsById(any())).thenReturn(true);
        when(mockRepository.save(any())).thenReturn(new TestEntity(1L, "Updated Entity1", "Updated Desc1"));
        
        // Act
        Response response = wrapper.updateBatch(mockRequest);
        
        // Assert
        assertEquals(200, response.getStatusCode());
        verify(mockRequest).parseJson();
        verify(mockRepository, times(2)).existsById(any());
        verify(mockRepository, times(2)).save(any());
    }
    
    @Test
    void testDeleteBatch_ValidIds_DeletesAll() {
        // Arrange
        Map<String, Object> jsonData = new HashMap<>();
        List<Object> ids = Arrays.asList(1, 2, 3);
        jsonData.put("ids", ids);
        
        when(mockRequest.parseJson()).thenReturn(jsonData);
        when(mockRepository.existsById(any())).thenReturn(true);
        
        // Act
        Response response = wrapper.deleteBatch(mockRequest);
        
        // Assert
        assertEquals(200, response.getStatusCode());
        verify(mockRequest).parseJson();
        verify(mockRepository, times(3)).existsById(any());
        verify(mockRepository, times(3)).deleteById(any());
    }
    
    @Test
    void testDeleteBatch_NonExistingIds_ReportsErrors() {
        // Arrange
        Map<String, Object> jsonData = new HashMap<>();
        List<Object> ids = Arrays.asList(1, 999); // 999 doesn't exist
        jsonData.put("ids", ids);
        
        when(mockRequest.parseJson()).thenReturn(jsonData);
        when(mockRepository.existsById(1L)).thenReturn(true);
        when(mockRepository.existsById(999L)).thenReturn(false);
        
        // Act
        Response response = wrapper.deleteBatch(mockRequest);
        
        // Assert
        assertEquals(200, response.getStatusCode());
        verify(mockRepository).deleteById(1L); // Only existing entity deleted
        verify(mockRepository, never()).deleteById(999L); // Non-existing entity not deleted
    }
} 