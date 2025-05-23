package jazzyframework.di;

import jazzyframework.di.annotations.*;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.DisplayName;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Tests for BeanDefinition functionality.
 * Tests bean metadata extraction, name determination, scope detection, lifecycle methods.
 */
public class BeanDefinitionTest {
    
    @Test
    @DisplayName("Should create BeanDefinition with correct basic properties")
    void testBasicBeanDefinition() {
        BeanDefinition def = new BeanDefinition(SimpleBean.class);
        
        assertEquals(SimpleBean.class, def.getBeanClass());
        assertEquals("SimpleBean", def.getName());
        assertFalse(def.isPrimary());
        assertTrue(def.isSingleton()); // Default is singleton
    }
    
    @Test
    @DisplayName("Should detect @Named annotation for name")
    void testNamedAnnotation() {
        BeanDefinition def = new BeanDefinition(NamedBean.class);
        
        assertEquals("customBean", def.getName());
        assertEquals(NamedBean.class, def.getBeanClass());
    }
    
    @Test
    @DisplayName("Should detect @Component value for name")
    void testComponentValueForName() {
        BeanDefinition def = new BeanDefinition(ComponentValueBean.class);
        
        assertEquals("valueBean", def.getName());
    }
    
    @Test
    @DisplayName("Should detect @Primary annotation")
    void testPrimaryAnnotation() {
        BeanDefinition def = new BeanDefinition(PrimaryBean.class);
        
        assertTrue(def.isPrimary());
        assertEquals("PrimaryBean", def.getName());
    }
    
    @Test
    @DisplayName("Should detect @Prototype scope")
    void testPrototypeScope() {
        BeanDefinition def = new BeanDefinition(PrototypeBean.class);
        
        assertFalse(def.isSingleton());
        assertTrue(def.isPrimary()); // This bean is also primary
    }
    
    @Test
    @DisplayName("Should detect @PostConstruct methods")
    void testPostConstructDetection() {
        BeanDefinition def = new BeanDefinition(LifecycleBean.class);
        
        assertEquals(2, def.getPostConstructMethods().size());
        
        // Check method names
        boolean hasInit = def.getPostConstructMethods().stream()
            .anyMatch(method -> method.getName().equals("init"));
        boolean hasSecondInit = def.getPostConstructMethods().stream()
            .anyMatch(method -> method.getName().equals("secondInit"));
        
        assertTrue(hasInit);
        assertTrue(hasSecondInit);
    }
    
    @Test
    @DisplayName("Should detect @PreDestroy methods")
    void testPreDestroyDetection() {
        BeanDefinition def = new BeanDefinition(LifecycleBean.class);
        
        assertEquals(1, def.getPreDestroyMethods().size());
        assertEquals("cleanup", def.getPreDestroyMethods().get(0).getName());
    }
    
    @Test
    @DisplayName("Should throw exception for invalid @PostConstruct method")
    void testInvalidPostConstructMethod() {
        assertThrows(IllegalArgumentException.class, () -> {
            new BeanDefinition(InvalidPostConstructBean.class);
        });
    }
    
    @Test
    @DisplayName("Should throw exception for invalid @PreDestroy method")
    void testInvalidPreDestroyMethod() {
        assertThrows(IllegalArgumentException.class, () -> {
            new BeanDefinition(InvalidPreDestroyBean.class);
        });
    }
    
    @Test
    @DisplayName("Should handle singleton instance management")
    void testSingletonInstanceManagement() {
        BeanDefinition def = new BeanDefinition(SimpleBean.class);
        
        assertNull(def.getSingletonInstance());
        
        Object instance = new Object();
        def.setSingletonInstance(instance);
        
        assertSame(instance, def.getSingletonInstance());
    }
    
    @Test
    @DisplayName("Should generate correct toString representation")
    void testToStringMethod() {
        BeanDefinition def = new BeanDefinition(PrimaryBean.class);
        
        String toString = def.toString();
        
        assertTrue(toString.contains("PrimaryBean"));
        assertTrue(toString.contains("primary=true"));
        assertTrue(toString.contains("singleton=true"));
    }
    
    @Test
    @DisplayName("Should handle complex bean with all annotations")
    void testComplexBean() {
        BeanDefinition def = new BeanDefinition(ComplexBean.class);
        
        assertEquals("complexService", def.getName());
        assertTrue(def.isPrimary());
        assertFalse(def.isSingleton()); // Prototype
        assertEquals(1, def.getPostConstructMethods().size());
        assertEquals(1, def.getPreDestroyMethods().size());
    }
    
    // Test components
    
    @Component
    public static class SimpleBean {
    }
    
    @Component
    @Named("customBean")
    public static class NamedBean {
    }
    
    @Component("valueBean")
    public static class ComponentValueBean {
    }
    
    @Component
    @Primary
    public static class PrimaryBean {
    }
    
    @Component
    @Primary
    @Prototype
    public static class PrototypeBean {
    }
    
    @Component
    public static class LifecycleBean {
        
        @PostConstruct
        public void init() {
        }
        
        @PostConstruct
        public void secondInit() {
        }
        
        @PreDestroy
        public void cleanup() {
        }
    }
    
    // @Component  // Removed to avoid ComponentScanner errors during tests
    public static class InvalidPostConstructBean {
        
        @PostConstruct
        public void invalidInit(String param) { // Invalid: has parameters
        }
    }
    
    // @Component  // Removed to avoid ComponentScanner errors during tests
    public static class InvalidPreDestroyBean {
        
        @PreDestroy
        public String invalidCleanup() { // Invalid: returns non-void
            return "invalid";
        }
    }
    
    @Component("complexService")
    @Named("complexService")
    @Primary
    @Prototype
    public static class ComplexBean {
        
        @PostConstruct
        public void initialize() {
        }
        
        @PreDestroy
        public void destroy() {
        }
    }
} 