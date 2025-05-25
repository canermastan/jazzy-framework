package jazzyframework.data;

import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import org.hibernate.SessionFactory;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

/**
 * Tests for RepositoryFactory class.
 */
@ExtendWith(MockitoExtension.class)
public class RepositoryFactoryTest {

    @Mock
    private HibernateConfig hibernateConfig;

    @Mock
    private SessionFactory sessionFactory;

    private RepositoryFactory repositoryFactory;

    @BeforeEach
    public void setUp() {
        repositoryFactory = new RepositoryFactory(hibernateConfig);
        
        // Setup mocks
        when(hibernateConfig.isInitialized()).thenReturn(true);
        when(hibernateConfig.getSessionFactory()).thenReturn(sessionFactory);
        
        // Initialize the factory
        repositoryFactory.initialize();
    }

    @Test
    public void testCreateRepository_ValidInterface() {
        TestRepository repository = repositoryFactory.createRepository(TestRepository.class);
        
        assertNotNull(repository);
        // Verify it's a proxy
        assertTrue(repository.getClass().getName().contains("Proxy"));
    }

    @Test
    public void testCreateRepository_InvalidInterface() {
        assertThrows(IllegalArgumentException.class, () -> {
            repositoryFactory.createRepository(InvalidRepository.class);
        });
    }

    @Test
    public void testCreateRepository_Caching() {
        TestRepository repo1 = repositoryFactory.createRepository(TestRepository.class);
        TestRepository repo2 = repositoryFactory.createRepository(TestRepository.class);
        
        assertSame(repo1, repo2); // Should return same cached instance
    }

    @Test
    public void testHasRepository() {
        assertFalse(repositoryFactory.hasRepository(TestRepository.class));
        
        repositoryFactory.createRepository(TestRepository.class);
        
        assertTrue(repositoryFactory.hasRepository(TestRepository.class));
    }

    @Test
    public void testClearCache() {
        repositoryFactory.createRepository(TestRepository.class);
        assertEquals(1, repositoryFactory.getCacheSize());
        
        repositoryFactory.clearCache();
        assertEquals(0, repositoryFactory.getCacheSize());
    }

    @Test
    public void testGetCacheSize() {
        assertEquals(0, repositoryFactory.getCacheSize());
        
        repositoryFactory.createRepository(TestRepository.class);
        assertEquals(1, repositoryFactory.getCacheSize());
        
        repositoryFactory.createRepository(AnotherTestRepository.class);
        assertEquals(2, repositoryFactory.getCacheSize());
    }

    @Test
    public void testCreateRepository_SessionFactoryNotAvailable() {
        // Create factory with uninitialized HibernateConfig
        when(hibernateConfig.isInitialized()).thenReturn(false);
        RepositoryFactory uninitializedFactory = new RepositoryFactory(hibernateConfig);
        uninitializedFactory.initialize();
        
        assertThrows(IllegalStateException.class, () -> {
            uninitializedFactory.createRepository(TestRepository.class);
        });
    }

    @Test
    public void testRepositoryProxy_MethodDelegation() {
        TestRepository repository = repositoryFactory.createRepository(TestRepository.class);
        
        // Test that basic methods don't throw exceptions
        assertDoesNotThrow(() -> {
            repository.toString();
            repository.hashCode();
        });
    }

    // Test interfaces and entities

    public interface TestRepository extends BaseRepository<TestEntity, Long> {
        // Custom repository methods can be added here
    }

    public interface AnotherTestRepository extends BaseRepository<AnotherTestEntity, Long> {
    }

    // Invalid repository interface (doesn't extend BaseRepository)
    public interface InvalidRepository {
        void someMethod();
    }

    @Entity
    public static class TestEntity {
        @Id
        private Long id;
        private String name;

        public TestEntity() {}

        public TestEntity(String name) {
            this.name = name;
        }

        public Long getId() { return id; }
        public void setId(Long id) { this.id = id; }
        public String getName() { return name; }
        public void setName(String name) { this.name = name; }
    }

    @Entity
    public static class AnotherTestEntity {
        @Id
        private Long id;
        private String description;

        public AnotherTestEntity() {}

        public AnotherTestEntity(String description) {
            this.description = description;
        }

        public Long getId() { return id; }
        public void setId(Long id) { this.id = id; }
        public String getDescription() { return description; }
        public void setDescription(String description) { this.description = description; }
    }
} 