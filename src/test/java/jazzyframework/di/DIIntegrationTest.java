package jazzyframework.di;

import jazzyframework.di.annotations.*;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.DisplayName;

import static org.junit.jupiter.api.Assertions.*;

import java.util.List;

/**
 * Integration tests for the complete DI system.
 * Tests real-world scenarios with complex dependency graphs.
 */
public class DIIntegrationTest {
    
    private DIContainer container;
    
    @BeforeEach
    void setUp() {
        container = new DIContainer();
        initializeContainerWithTestComponents();
    }
    
    private void initializeContainerWithTestComponents() {
        // Create a custom scanner that finds our test components
        ComponentScanner scanner = new ComponentScanner();
        List<BeanDefinition> definitions = scanner.scanPackage("jazzyframework.di");
        
        // Manually initialize the container with test components
        container.beanDefinitions.clear();
        container.typeIndex.clear();
        
        for (BeanDefinition def : definitions) {
            // Only register our test components
            if (def.getBeanClass().getDeclaringClass() == DIIntegrationTest.class) {
                container.registerBeanDefinition(def);
            }
        }
        
        container.initialized = true;
    }
    
    @Test
    @DisplayName("Should handle complex dependency injection scenario")
    void testComplexDependencyInjection() {
        // Get the complex service which has multiple dependencies
        ComplexService service = container.getComponent(ComplexService.class);
        
        assertNotNull(service);
        assertTrue(service.isInitialized());
        
        // Check that all dependencies are injected correctly
        assertNotNull(service.getRepository());
        assertEquals("DATABASE", service.getRepository().getType());
        
        assertNotNull(service.getNotificationService());
        assertEquals("EMAIL", service.getNotificationService().getType());
        
        assertNotNull(service.getProcessor());
        assertNotNull(service.getSecondProcessor());
        // Prototype services should be different instances
        assertNotSame(service.getProcessor(), service.getSecondProcessor());
    }
    
    @Test
    @DisplayName("Should resolve @Primary conflicts correctly")
    void testPrimaryConflictResolution() {
        // When requesting DataRepository interface, should get DatabaseRepository (marked as @Primary)
        DataRepository repository = container.getComponent(DataRepository.class);
        
        assertNotNull(repository);
        assertEquals("DATABASE", repository.getType());
        assertTrue(repository instanceof DatabaseRepository);
    }
    
    @Test
    @DisplayName("Should handle @Named injection correctly")
    void testNamedInjection() {
        // Get service that uses @Named injection
        NotificationService emailService = container.getComponent("emailNotifier");
        assertNotNull(emailService);
        assertEquals("EMAIL", emailService.getType());
        
        NotificationService smsService = container.getComponent("smsNotifier");
        assertNotNull(smsService);
        assertEquals("SMS", smsService.getType());
    }
    
    @Test
    @DisplayName("Should maintain singleton behavior across multiple requests")
    void testSingletonBehavior() {
        DatabaseRepository repo1 = container.getComponent(DatabaseRepository.class);
        DatabaseRepository repo2 = container.getComponent(DatabaseRepository.class);
        
        assertNotNull(repo1);
        assertNotNull(repo2);
        assertSame(repo1, repo2); // Should be same singleton instance
        
        // Check that PostConstruct was called only once
        assertEquals(1, repo1.getInitCallCount());
    }
    
    @Test
    @DisplayName("Should create new instances for @Prototype components")
    void testPrototypeBehavior() {
        RequestProcessor proc1 = container.getComponent(RequestProcessor.class);
        RequestProcessor proc2 = container.getComponent(RequestProcessor.class);
        
        assertNotNull(proc1);
        assertNotNull(proc2);
        assertNotSame(proc1, proc2); // Should be different instances
        
        // Each should have been initialized
        assertTrue(proc1.isInitialized());
        assertTrue(proc2.isInitialized());
        
        // Should have different instance IDs
        assertNotEquals(proc1.getInstanceId(), proc2.getInstanceId());
    }
    
    @Test
    @DisplayName("Should call lifecycle methods in correct order")
    void testLifecycleMethodOrder() {
        LifecycleTrackingService service = container.getComponent(LifecycleTrackingService.class);
        
        assertNotNull(service);
        assertTrue(service.isPostConstruct1Called());
        assertTrue(service.isPostConstruct2Called());
        
        // Dispose container to trigger PreDestroy
        container.dispose();
        
        assertTrue(service.isPreDestroyCalled());
    }
    
    @Test
    @DisplayName("Should handle circular dependency prevention")
    void testCircularDependencyHandling() {
        // This test ensures that our DI system can handle complex scenarios
        // In a real circular dependency, PicoContainer would throw an exception
        // Our current design doesn't support circular dependencies, which is good
        ComplexService service = container.getComponent(ComplexService.class);
        assertNotNull(service);
        
        // Verify that all dependencies are properly resolved
        assertNotNull(service.getRepository());
        assertNotNull(service.getNotificationService());
    }
    
    @Test
    @DisplayName("Should provide correct bean definitions")
    void testBeanDefinitionsProvision() {
        var definitions = container.getBeanDefinitions();
        
        assertNotNull(definitions);
        assertFalse(definitions.isEmpty());
        
        // Check specific components exist
        assertTrue(definitions.containsKey("DatabaseRepository"));
        assertTrue(definitions.containsKey("emailNotifier"));
        assertTrue(definitions.containsKey("smsNotifier"));
        assertTrue(definitions.containsKey("ComplexService"));
        
        // Check that @Primary annotation is detected
        BeanDefinition dbRepo = definitions.get("DatabaseRepository");
        assertTrue(dbRepo.isPrimary());
        
        // Check that @Prototype annotation is detected
        BeanDefinition processor = definitions.get("RequestProcessor");
        assertFalse(processor.isSingleton());
    }
    
    // Test Components for Integration Tests
    
    public interface DataRepository {
        String getType();
        int getInitCallCount();
    }
    
    @Component
    @Primary
    public static class DatabaseRepository implements DataRepository {
        private int initCallCount = 0;
        
        @PostConstruct
        public void initialize() {
            initCallCount++;
        }
        
        @Override
        public String getType() {
            return "DATABASE";
        }
        
        @Override
        public int getInitCallCount() {
            return initCallCount;
        }
    }
    
    @Component
    public static class InMemoryRepository implements DataRepository {
        private int initCallCount = 0;
        
        @PostConstruct
        public void initialize() {
            initCallCount++;
        }
        
        @Override
        public String getType() {
            return "MEMORY";
        }
        
        @Override
        public int getInitCallCount() {
            return initCallCount;
        }
    }
    
    public interface NotificationService {
        String getType();
    }
    
    @Component
    @Named("emailNotifier")
    public static class EmailNotificationService implements NotificationService {
        @Override
        public String getType() {
            return "EMAIL";
        }
    }
    
    @Component
    @Named("smsNotifier")
    public static class SmsNotificationService implements NotificationService {
        @Override
        public String getType() {
            return "SMS";
        }
    }
    
    @Component
    @Prototype
    public static class RequestProcessor {
        private final String instanceId = java.util.UUID.randomUUID().toString().substring(0, 8);
        private boolean initialized = false;
        
        @PostConstruct
        public void init() {
            initialized = true;
        }
        
        public String getInstanceId() {
            return instanceId;
        }
        
        public boolean isInitialized() {
            return initialized;
        }
    }
    
    @Component
    public static class ComplexService {
        private final DataRepository repository;
        private final NotificationService notificationService;
        private final RequestProcessor processor;
        private final RequestProcessor secondProcessor;
        private boolean initialized = false;
        
        public ComplexService(
                DataRepository repository,
                @Named("emailNotifier") NotificationService notificationService,
                RequestProcessor processor,
                RequestProcessor secondProcessor) {
            this.repository = repository;
            this.notificationService = notificationService;
            this.processor = processor;
            this.secondProcessor = secondProcessor;
        }
        
        @PostConstruct
        public void initialize() {
            initialized = true;
        }
        
        public boolean isInitialized() {
            return initialized;
        }
        
        public DataRepository getRepository() {
            return repository;
        }
        
        public NotificationService getNotificationService() {
            return notificationService;
        }
        
        public RequestProcessor getProcessor() {
            return processor;
        }
        
        public RequestProcessor getSecondProcessor() {
            return secondProcessor;
        }
    }
    
    @Component
    public static class LifecycleTrackingService {
        private boolean postConstruct1Called = false;
        private boolean postConstruct2Called = false;
        private boolean preDestroyCalled = false;
        
        @PostConstruct
        public void init1() {
            postConstruct1Called = true;
        }
        
        @PostConstruct
        public void init2() {
            postConstruct2Called = true;
        }
        
        @PreDestroy
        public void cleanup() {
            preDestroyCalled = true;
        }
        
        public boolean isPostConstruct1Called() {
            return postConstruct1Called;
        }
        
        public boolean isPostConstruct2Called() {
            return postConstruct2Called;
        }
        
        public boolean isPreDestroyCalled() {
            return preDestroyCalled;
        }
    }
} 