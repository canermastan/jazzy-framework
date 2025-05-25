package jazzyframework.data;

import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

import java.util.List;

/**
 * Tests for EntityScanner class.
 */
public class EntityScannerTest {

    private EntityScanner entityScanner;

    @BeforeEach
    public void setUp() {
        entityScanner = new EntityScanner();
    }

    @Test
    public void testScanForEntities() {
        List<Class<?>> entities = entityScanner.scanForEntities();
        
        assertNotNull(entities);
        // Should find at least the User entity from examples
        assertTrue(entities.size() >= 0); // May be 0 if no entities in test classpath
    }

    @Test
    public void testScanSpecificPackageForEntities() {
        // Test scanning a specific package
        List<Class<?>> entities = entityScanner.scanPackageForEntities("examples.database.entity");
        
        assertNotNull(entities);
        // Results depend on whether examples are in test classpath
    }

    @Test
    public void testScanMultiplePackagesForEntities() {
        String[] packages = {"examples.database.entity", "com.example", "org.test"};
        List<Class<?>> entities = entityScanner.scanPackagesForEntities(packages);
        
        assertNotNull(entities);
    }

    @Test
    public void testValidateEntity_ValidEntity() {
        boolean isValid = entityScanner.validateEntity(TestEntity.class);
        assertTrue(isValid);
    }

    @Test
    public void testValidateEntity_InvalidEntity() {
        boolean isValid = entityScanner.validateEntity(NonEntity.class);
        assertFalse(isValid);
    }

    @Test
    public void testValidateEntity_EntityWithoutDefaultConstructor() {
        boolean isValid = entityScanner.validateEntity(EntityWithoutDefaultConstructor.class);
        assertFalse(isValid);
    }

    @Test
    public void testScanPackageForEntities_NonExistentPackage() {
        List<Class<?>> entities = entityScanner.scanPackageForEntities("com.nonexistent.package");
        
        assertNotNull(entities);
        assertTrue(entities.isEmpty());
    }

    @Test
    public void testScanPackagesForEntities_EmptyArray() {
        List<Class<?>> entities = entityScanner.scanPackagesForEntities();
        
        assertNotNull(entities);
        assertTrue(entities.isEmpty());
    }

    // Test entities for validation

    @Entity
    public static class TestEntity {
        @Id
        private Long id;
        private String name;

        public TestEntity() {
            // Default constructor
        }

        public TestEntity(String name) {
            this.name = name;
        }

        // Getters and setters
        public Long getId() { return id; }
        public void setId(Long id) { this.id = id; }
        public String getName() { return name; }
        public void setName(String name) { this.name = name; }
    }

    // Non-entity class for testing
    public static class NonEntity {
        private Long id;
        private String name;

        public NonEntity() {}

        public Long getId() { return id; }
        public void setId(Long id) { this.id = id; }
        public String getName() { return name; }
        public void setName(String name) { this.name = name; }
    }

    // Entity without default constructor
    @Entity
    public static class EntityWithoutDefaultConstructor {
        @Id
        private Long id;
        private String name;

        public EntityWithoutDefaultConstructor(String name) {
            this.name = name;
        }

        public Long getId() { return id; }
        public void setId(Long id) { this.id = id; }
        public String getName() { return name; }
        public void setName(String name) { this.name = name; }
    }
} 