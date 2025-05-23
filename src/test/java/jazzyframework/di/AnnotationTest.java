package jazzyframework.di;

import jazzyframework.di.annotations.*;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.DisplayName;

import java.lang.reflect.Method;
import java.lang.reflect.Parameter;

import static org.junit.jupiter.api.Assertions.*;

/**
 * Tests for DI annotations functionality and presence.
 * Ensures annotations are properly retained and accessible at runtime.
 */
public class AnnotationTest {
    
    @Test
    @DisplayName("@Component annotation should be present and accessible")
    void testComponentAnnotation() {
        assertTrue(TestComponentClass.class.isAnnotationPresent(Component.class));
        
        Component annotation = TestComponentClass.class.getAnnotation(Component.class);
        assertNotNull(annotation);
        assertEquals("testComponent", annotation.value());
    }
    
    @Test
    @DisplayName("@Named annotation should be present and accessible")
    void testNamedAnnotation() {
        assertTrue(TestNamedClass.class.isAnnotationPresent(Named.class));
        
        Named annotation = TestNamedClass.class.getAnnotation(Named.class);
        assertNotNull(annotation);
        assertEquals("namedBean", annotation.value());
    }
    
    @Test
    @DisplayName("@Primary annotation should be present and accessible")
    void testPrimaryAnnotation() {
        assertTrue(TestPrimaryClass.class.isAnnotationPresent(Primary.class));
        
        Primary annotation = TestPrimaryClass.class.getAnnotation(Primary.class);
        assertNotNull(annotation);
    }
    
    @Test
    @DisplayName("@Singleton annotation should be present and accessible")
    void testSingletonAnnotation() {
        assertTrue(TestSingletonClass.class.isAnnotationPresent(Singleton.class));
        
        Singleton annotation = TestSingletonClass.class.getAnnotation(Singleton.class);
        assertNotNull(annotation);
    }
    
    @Test
    @DisplayName("@Prototype annotation should be present and accessible")
    void testPrototypeAnnotation() {
        assertTrue(TestPrototypeClass.class.isAnnotationPresent(Prototype.class));
        
        Prototype annotation = TestPrototypeClass.class.getAnnotation(Prototype.class);
        assertNotNull(annotation);
    }
    
    @Test
    @DisplayName("@PostConstruct annotation should be present on methods")
    void testPostConstructAnnotation() {
        Method[] methods = TestLifecycleClass.class.getDeclaredMethods();
        
        Method initMethod = null;
        for (Method method : methods) {
            if (method.getName().equals("initialize")) {
                initMethod = method;
                break;
            }
        }
        
        assertNotNull(initMethod);
        assertTrue(initMethod.isAnnotationPresent(PostConstruct.class));
        
        PostConstruct annotation = initMethod.getAnnotation(PostConstruct.class);
        assertNotNull(annotation);
    }
    
    @Test
    @DisplayName("@PreDestroy annotation should be present on methods")
    void testPreDestroyAnnotation() {
        Method[] methods = TestLifecycleClass.class.getDeclaredMethods();
        
        Method cleanupMethod = null;
        for (Method method : methods) {
            if (method.getName().equals("cleanup")) {
                cleanupMethod = method;
                break;
            }
        }
        
        assertNotNull(cleanupMethod);
        assertTrue(cleanupMethod.isAnnotationPresent(PreDestroy.class));
        
        PreDestroy annotation = cleanupMethod.getAnnotation(PreDestroy.class);
        assertNotNull(annotation);
    }
    
    @Test
    @DisplayName("@Named annotation should work on constructor parameters")
    void testNamedOnParameter() throws Exception {
        var constructor = TestDependentClass.class.getConstructor(String.class);
        Parameter parameter = constructor.getParameters()[0];
        
        assertTrue(parameter.isAnnotationPresent(Named.class));
        
        Named annotation = parameter.getAnnotation(Named.class);
        assertNotNull(annotation);
        assertEquals("parameterName", annotation.value());
    }
    
    @Test
    @DisplayName("Multiple annotations should work together")
    void testMultipleAnnotations() {
        assertTrue(TestComplexClass.class.isAnnotationPresent(Component.class));
        assertTrue(TestComplexClass.class.isAnnotationPresent(Named.class));
        assertTrue(TestComplexClass.class.isAnnotationPresent(Primary.class));
        assertTrue(TestComplexClass.class.isAnnotationPresent(Prototype.class));
        
        Component componentAnnotation = TestComplexClass.class.getAnnotation(Component.class);
        Named namedAnnotation = TestComplexClass.class.getAnnotation(Named.class);
        Primary primaryAnnotation = TestComplexClass.class.getAnnotation(Primary.class);
        Prototype prototypeAnnotation = TestComplexClass.class.getAnnotation(Prototype.class);
        
        assertNotNull(componentAnnotation);
        assertNotNull(namedAnnotation);
        assertNotNull(primaryAnnotation);
        assertNotNull(prototypeAnnotation);
        
        assertEquals("complexService", namedAnnotation.value());
    }
    
    @Test
    @DisplayName("Annotation retention should be RUNTIME")
    void testAnnotationRetention() {
        // This test verifies that all our annotations are accessible at runtime
        // If retention was not RUNTIME, the annotations wouldn't be available via reflection
        
        assertTrue(TestComponentClass.class.isAnnotationPresent(Component.class));
        assertTrue(TestNamedClass.class.isAnnotationPresent(Named.class));
        assertTrue(TestPrimaryClass.class.isAnnotationPresent(Primary.class));
        assertTrue(TestSingletonClass.class.isAnnotationPresent(Singleton.class));
        assertTrue(TestPrototypeClass.class.isAnnotationPresent(Prototype.class));
    }
    
    // Test classes with annotations
    
    @Component("testComponent")
    public static class TestComponentClass {
    }
    
    @Component
    @Named("namedBean")
    public static class TestNamedClass {
    }
    
    @Component
    @Primary
    public static class TestPrimaryClass {
    }
    
    @Component
    @Singleton
    public static class TestSingletonClass {
    }
    
    @Component
    @Prototype
    public static class TestPrototypeClass {
    }
    
    @Component
    public static class TestLifecycleClass {
        
        @PostConstruct
        public void initialize() {
        }
        
        @PreDestroy
        public void cleanup() {
        }
    }
    
    @Component
    public static class TestDependentClass {
        
        public TestDependentClass(@Named("parameterName") String dependency) {
        }
    }
    
    @Component
    @Named("complexService")
    @Primary
    @Prototype
    public static class TestComplexClass {
        
        @PostConstruct
        public void init() {
        }
        
        @PreDestroy
        public void destroy() {
        }
    }
} 