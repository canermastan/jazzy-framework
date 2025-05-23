package jazzyframework.di;

import jazzyframework.di.annotations.*;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.DisplayName;

import java.util.Map;
import java.util.List;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Comprehensive tests for DIContainer functionality.
 * Tests @Component, @Named, @Primary, @PostConstruct, @PreDestroy, @Singleton, @Prototype.
 */
public class DIContainerTest {
    
    private DIContainer container;
    
    @BeforeEach
    void setUp() {
        container = new DIContainer();
        // Don't initialize by default - let each test handle it
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
            if (def.getBeanClass().getDeclaringClass() == DIContainerTest.class) {
                container.registerBeanDefinition(def);
            }
        }
        
        container.initialized = true;
    }
    
    @Test
    @DisplayName("DIContainer should initialize successfully")
    void testContainerInitialization() {
        assertFalse(container.isInitialized());
        container.initialize();
        assertTrue(container.isInitialized());
    }
    
    @Test
    @DisplayName("Should register and retrieve simple component")
    void testSimpleComponentRegistration() {
        initializeContainerWithTestComponents();
        
        SimpleTestService service = container.getComponent(SimpleTestService.class);
        
        assertNotNull(service);
        assertTrue(service.isInitialized());
    }
    
    @Test
    @DisplayName("Should handle @Named component registration")
    void testNamedComponentRegistration() {
        initializeContainerWithTestComponents();
        
        // Get by name
        NamedTestService service = container.getComponent("testService");
        assertNotNull(service);
        assertEquals("NAMED", service.getType());
        
        // Get by class should also work
        NamedTestService serviceByClass = container.getComponent(NamedTestService.class);
        assertNotNull(serviceByClass);
        assertSame(service, serviceByClass); // Should be same singleton instance
    }
    
    @Test
    @DisplayName("Should handle @Primary annotation for conflict resolution")
    void testPrimaryAnnotation() {
        initializeContainerWithTestComponents();
        
        // When requesting TestInterface, should get PrimaryTestService due to @Primary
        TestInterface service = container.getComponent(TestInterface.class);
        assertNotNull(service);
        assertEquals("PRIMARY", service.getType());
        assertTrue(service instanceof PrimaryTestService);
    }
    
    @Test
    @DisplayName("Should call @PostConstruct methods after creation")
    void testPostConstructCalls() {
        initializeContainerWithTestComponents();
        
        PostConstructTestService service = container.getComponent(PostConstructTestService.class);
        
        assertNotNull(service);
        assertTrue(service.isPostConstructCalled());
        assertEquals(1, service.getPostConstructCallCount());
    }
    
    @Test
    @DisplayName("Should call @PreDestroy methods on disposal")
    void testPreDestroyCalls() {
        initializeContainerWithTestComponents();
        
        PreDestroyTestService service = container.getComponent(PreDestroyTestService.class);
        assertNotNull(service);
        assertFalse(service.isPreDestroyCalled());
        
        // Dispose container
        container.dispose();
        
        // PreDestroy should have been called
        assertTrue(service.isPreDestroyCalled());
    }
    
    @Test
    @DisplayName("@Singleton should return same instance")
    void testSingletonScope() {
        initializeContainerWithTestComponents();
        
        SingletonTestService service1 = container.getComponent(SingletonTestService.class);
        SingletonTestService service2 = container.getComponent(SingletonTestService.class);
        
        assertNotNull(service1);
        assertNotNull(service2);
        assertSame(service1, service2); // Should be same instance
    }
    
    @Test
    @DisplayName("@Prototype should return different instances")
    void testPrototypeScope() {
        initializeContainerWithTestComponents();
        
        PrototypeTestService service1 = container.getComponent(PrototypeTestService.class);
        PrototypeTestService service2 = container.getComponent(PrototypeTestService.class);
        
        assertNotNull(service1);
        assertNotNull(service2);
        assertNotSame(service1, service2); // Should be different instances
        assertNotEquals(service1.getInstanceId(), service2.getInstanceId());
    }
    
    @Test
    @DisplayName("Should handle constructor injection with @Named")
    void testNamedConstructorInjection() {
        initializeContainerWithTestComponents();
        
        DependentTestService service = container.getComponent(DependentTestService.class);
        
        assertNotNull(service);
        assertNotNull(service.getNamedService());
        assertEquals("NAMED", service.getNamedService().getType());
        assertNotNull(service.getPrimaryService());
        assertEquals("PRIMARY", service.getPrimaryService().getType());
    }
    
    @Test
    @DisplayName("Should throw exception for unknown component name")
    void testUnknownComponentName() {
        initializeContainerWithTestComponents();
        
        assertThrows(IllegalArgumentException.class, () -> {
            container.getComponent("unknownService");
        });
    }
    
    @Test
    @DisplayName("Should throw exception when accessing uninitialized container")
    void testUninitializedContainerAccess() {
        // Don't initialize the container for this test
        assertThrows(IllegalStateException.class, () -> {
            container.getComponent(SimpleTestService.class);
        });
    }
    
    @Test
    @DisplayName("Should provide bean definitions map")
    void testBeanDefinitionsAccess() {
        initializeContainerWithTestComponents();
        
        Map<String, BeanDefinition> definitions = container.getBeanDefinitions();
        
        assertNotNull(definitions);
        assertFalse(definitions.isEmpty());
        
        // Check that our test components are registered
        assertTrue(definitions.containsKey("SimpleTestService"));
        assertTrue(definitions.containsKey("testService")); // @Named
        assertTrue(definitions.containsKey("PrimaryTestService"));
    }
    
    @Test
    @DisplayName("Should handle multiple @PostConstruct methods")
    void testMultiplePostConstructMethods() {
        initializeContainerWithTestComponents();
        
        MultiplePostConstructService service = container.getComponent(MultiplePostConstructService.class);
        
        assertNotNull(service);
        assertTrue(service.isFirstPostConstructCalled());
        assertTrue(service.isSecondPostConstructCalled());
    }
    
    // Test Components
    
    @Component
    public static class SimpleTestService {
        private boolean initialized = false;
        
        @PostConstruct
        public void init() {
            initialized = true;
        }
        
        public boolean isInitialized() {
            return initialized;
        }
    }
    
    @Component
    @Named("testService")
    public static class NamedTestService {
        public String getType() {
            return "NAMED";
        }
    }
    
    public interface TestInterface {
        String getType();
    }
    
    @Component
    public static class AlternativeTestService implements TestInterface {
        public String getType() {
            return "ALTERNATIVE";
        }
    }
    
    @Component
    @Primary
    public static class PrimaryTestService implements TestInterface {
        public String getType() {
            return "PRIMARY";
        }
    }
    
    @Component
    public static class PostConstructTestService {
        private boolean postConstructCalled = false;
        private int callCount = 0;
        
        @PostConstruct
        public void initialize() {
            postConstructCalled = true;
            callCount++;
        }
        
        public boolean isPostConstructCalled() {
            return postConstructCalled;
        }
        
        public int getPostConstructCallCount() {
            return callCount;
        }
    }
    
    @Component
    public static class PreDestroyTestService {
        private boolean preDestroyCalled = false;
        
        @PreDestroy
        public void cleanup() {
            preDestroyCalled = true;
        }
        
        public boolean isPreDestroyCalled() {
            return preDestroyCalled;
        }
    }
    
    @Component
    @Singleton
    public static class SingletonTestService {
        private final String instanceId = java.util.UUID.randomUUID().toString();
        
        public String getInstanceId() {
            return instanceId;
        }
    }
    
    @Component
    @Prototype
    public static class PrototypeTestService {
        private final String instanceId = java.util.UUID.randomUUID().toString();
        
        public String getInstanceId() {
            return instanceId;
        }
    }
    
    @Component
    public static class DependentTestService {
        private final NamedTestService namedService;
        private final TestInterface primaryService;
        
        public DependentTestService(
                @Named("testService") NamedTestService namedService,
                TestInterface primaryService) {
            this.namedService = namedService;
            this.primaryService = primaryService;
        }
        
        public NamedTestService getNamedService() {
            return namedService;
        }
        
        public TestInterface getPrimaryService() {
            return primaryService;
        }
    }
    
    @Component
    public static class MultiplePostConstructService {
        private boolean firstPostConstructCalled = false;
        private boolean secondPostConstructCalled = false;
        
        @PostConstruct
        public void firstInit() {
            firstPostConstructCalled = true;
        }
        
        @PostConstruct
        public void secondInit() {
            secondPostConstructCalled = true;
        }
        
        public boolean isFirstPostConstructCalled() {
            return firstPostConstructCalled;
        }
        
        public boolean isSecondPostConstructCalled() {
            return secondPostConstructCalled;
        }
    }
} 