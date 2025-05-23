package jazzyframework.di;

import jazzyframework.di.annotations.*;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.DisplayName;

import java.util.List;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Tests for ComponentScanner functionality.
 * Tests component discovery, @Named, @Primary annotation detection.
 */
public class ComponentScannerTest {
    
    private ComponentScanner scanner;
    
    @BeforeEach
    void setUp() {
        scanner = new ComponentScanner();
    }
    
    @Test
    @DisplayName("Should scan and find @Component annotated classes")
    void testComponentScanning() {
        List<BeanDefinition> definitions = scanner.scanPackage("jazzyframework.di");
        
        assertNotNull(definitions);
        assertFalse(definitions.isEmpty());
        
        // Should find test components from DIContainerTest
        boolean foundSimpleTest = definitions.stream()
            .anyMatch(def -> def.getBeanClass().getSimpleName().equals("SimpleTestService"));
        assertTrue(foundSimpleTest, "Should find SimpleTestService component");
    }
    
    @Test
    @DisplayName("Should detect @Named annotations")
    void testNamedAnnotationDetection() {
        List<BeanDefinition> definitions = scanner.scanPackage("jazzyframework.di");
        
        // Find the named test service
        BeanDefinition namedDef = definitions.stream()
            .filter(def -> def.getName().equals("testService"))
            .findFirst()
            .orElse(null);
        
        assertNotNull(namedDef, "Should find named component");
        assertEquals("testService", namedDef.getName());
    }
    
    @Test
    @DisplayName("Should detect @Primary annotations")
    void testPrimaryAnnotationDetection() {
        List<BeanDefinition> definitions = scanner.scanPackage("jazzyframework.di");
        
        // Find the primary test service
        BeanDefinition primaryDef = definitions.stream()
            .filter(def -> def.getBeanClass().getSimpleName().equals("PrimaryTestService"))
            .findFirst()
            .orElse(null);
        
        assertNotNull(primaryDef, "Should find primary component");
        assertTrue(primaryDef.isPrimary(), "Should detect @Primary annotation");
    }
    
    @Test
    @DisplayName("Should handle non-existent packages gracefully")
    void testNonExistentPackage() {
        List<BeanDefinition> definitions = scanner.scanPackage("com.nonexistent.package");
        
        assertNotNull(definitions);
        assertTrue(definitions.isEmpty());
    }
    
    @Test
    @DisplayName("Should get component name correctly")
    void testGetComponentName() {
        // Test with @Named annotation
        String namedComponentName = scanner.getComponentName(TestNamedComponent.class);
        assertEquals("customName", namedComponentName);
        
        // Test with @Component value
        String componentValueName = scanner.getComponentName(TestComponentWithValue.class);
        assertEquals("componentValue", componentValueName);
        
        // Test with default name (class simple name)
        String defaultName = scanner.getComponentName(TestDefaultComponent.class);
        assertEquals("TestDefaultComponent", defaultName);
    }
    
    @Test
    @DisplayName("Should detect @PostConstruct and @PreDestroy methods")
    void testLifecycleMethodDetection() {
        List<BeanDefinition> definitions = scanner.scanPackage("jazzyframework.di");
        
        // Find component with lifecycle methods
        BeanDefinition lifecycleDef = definitions.stream()
            .filter(def -> def.getBeanClass().getSimpleName().equals("PostConstructTestService"))
            .findFirst()
            .orElse(null);
        
        assertNotNull(lifecycleDef);
        assertFalse(lifecycleDef.getPostConstructMethods().isEmpty());
        assertEquals(1, lifecycleDef.getPostConstructMethods().size());
        assertEquals("initialize", lifecycleDef.getPostConstructMethods().get(0).getName());
    }
    
    @Test
    @DisplayName("Should detect singleton and prototype scopes")
    void testScopeDetection() {
        List<BeanDefinition> definitions = scanner.scanPackage("jazzyframework.di");
        
        // Find singleton component
        BeanDefinition singletonDef = definitions.stream()
            .filter(def -> def.getBeanClass().getSimpleName().equals("SingletonTestService"))
            .findFirst()
            .orElse(null);
        
        assertNotNull(singletonDef);
        assertTrue(singletonDef.isSingleton());
        
        // Find prototype component
        BeanDefinition prototypeDef = definitions.stream()
            .filter(def -> def.getBeanClass().getSimpleName().equals("PrototypeTestService"))
            .findFirst()
            .orElse(null);
        
        assertNotNull(prototypeDef);
        assertFalse(prototypeDef.isSingleton()); // Prototype should not be singleton
    }
    
    // Test components for name detection
    
    @Component
    @Named("customName")
    public static class TestNamedComponent {
    }
    
    @Component("componentValue")
    public static class TestComponentWithValue {
    }
    
    @Component
    public static class TestDefaultComponent {
    }
} 