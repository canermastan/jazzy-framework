package jazzyframework.di;

import jazzyframework.di.annotations.*;

import java.lang.reflect.Method;
import java.util.ArrayList;
import java.util.List;

/**
 * Holds metadata information about a bean/component for dependency injection.
 * 
 * <p>This class encapsulates all the information needed by the {@link DIContainer}
 * to properly manage a bean's lifecycle and dependencies, including:
 * <ul>
 *   <li>Bean class and name information</li>
 *   <li>Primary bean designation for conflict resolution</li>
 *   <li>Scope management (singleton vs prototype)</li>
 *   <li>Lifecycle method references ({@code @PostConstruct} and {@code @PreDestroy})</li>
 *   <li>Singleton instance caching</li>
 * </ul>
 * 
 * <p>Bean definitions are automatically created by the {@link ComponentScanner}
 * during component discovery and used by the DI container for bean instantiation
 * and lifecycle management.
 * 
 * @since 0.2
 * @author Caner Mastan
 */
public class BeanDefinition {
    private final Class<?> beanClass;
    private final String name;
    private final boolean isPrimary;
    private final boolean isSingleton;
    private final List<Method> postConstructMethods;
    private final List<Method> preDestroyMethods;
    private Object singletonInstance;
    
    /**
     * Creates a new bean definition for the specified class.
     * Automatically extracts all metadata from annotations.
     * 
     * @param beanClass the class to create bean definition for
     */
    public BeanDefinition(Class<?> beanClass) {
        this.beanClass = beanClass;
        this.name = determineName(beanClass);
        this.isPrimary = beanClass.isAnnotationPresent(Primary.class);
        this.isSingleton = determineSingleton(beanClass);
        this.postConstructMethods = findPostConstructMethods(beanClass);
        this.preDestroyMethods = findPreDestroyMethods(beanClass);
    }
    
    /**
     * Determines the bean name from annotations or class name.
     * Priority: @Named > @Component.value > class simple name
     * 
     * @param clazz the bean class
     * @return the determined bean name
     */
    private String determineName(Class<?> clazz) {
        if (clazz.isAnnotationPresent(Named.class)) {
            return clazz.getAnnotation(Named.class).value();
        }
        if (clazz.isAnnotationPresent(Component.class)) {
            String componentName = clazz.getAnnotation(Component.class).value();
            if (!componentName.isEmpty()) {
                return componentName;
            }
        }
        return clazz.getSimpleName();
    }
    
    /**
     * Determines if the bean should be singleton or prototype.
     * Default is singleton unless @Prototype is present.
     * 
     * @param clazz the bean class
     * @return true if singleton, false if prototype
     */
    private boolean determineSingleton(Class<?> clazz) {
        if (clazz.isAnnotationPresent(Prototype.class)) {
            return false;
        }
        return true;
    }
    
    /**
     * Finds and validates @PostConstruct methods in the class.
     * 
     * @param clazz the bean class
     * @return list of valid @PostConstruct methods
     * @throws IllegalArgumentException if method signature is invalid
     */
    private List<Method> findPostConstructMethods(Class<?> clazz) {
        List<Method> methods = new ArrayList<>();
        for (Method method : clazz.getDeclaredMethods()) {
            if (method.isAnnotationPresent(PostConstruct.class)) {
                if (method.getParameterCount() == 0 && method.getReturnType() == void.class) {
                    methods.add(method);
                } else {
                    throw new IllegalArgumentException(
                        "@PostConstruct method must have no parameters and return void: " + 
                        clazz.getName() + "." + method.getName());
                }
            }
        }
        return methods;
    }
    
    /**
     * Finds and validates @PreDestroy methods in the class.
     * 
     * @param clazz the bean class
     * @return list of valid @PreDestroy methods
     * @throws IllegalArgumentException if method signature is invalid
     */
    private List<Method> findPreDestroyMethods(Class<?> clazz) {
        List<Method> methods = new ArrayList<>();
        for (Method method : clazz.getDeclaredMethods()) {
            if (method.isAnnotationPresent(PreDestroy.class)) {
                if (method.getParameterCount() == 0 && method.getReturnType() == void.class) {
                    methods.add(method);
                } else {
                    throw new IllegalArgumentException(
                        "@PreDestroy method must have no parameters and return void: " + 
                        clazz.getName() + "." + method.getName());
                }
            }
        }
        return methods;
    }
    
    // Getters
    
    /**
     * Gets the bean class.
     * 
     * @return the bean class
     */
    public Class<?> getBeanClass() {
        return beanClass;
    }
    
    /**
     * Gets the bean name.
     * 
     * @return the bean name
     */
    public String getName() {
        return name;
    }
    
    /**
     * Checks if this bean is marked as primary.
     * 
     * @return true if this bean is primary
     */
    public boolean isPrimary() {
        return isPrimary;
    }
    
    /**
     * Checks if this bean is singleton scoped.
     * 
     * @return true if singleton, false if prototype
     */
    public boolean isSingleton() {
        return isSingleton;
    }
    
    /**
     * Gets the list of @PostConstruct methods.
     * 
     * @return list of @PostConstruct methods
     */
    public List<Method> getPostConstructMethods() {
        return postConstructMethods;
    }
    
    /**
     * Gets the list of @PreDestroy methods.
     * 
     * @return list of @PreDestroy methods
     */
    public List<Method> getPreDestroyMethods() {
        return preDestroyMethods;
    }
    
    /**
     * Gets the singleton instance if available.
     * 
     * @return the singleton instance or null if not created yet
     */
    public Object getSingletonInstance() {
        return singletonInstance;
    }
    
    /**
     * Sets the singleton instance.
     * 
     * @param singletonInstance the singleton instance to set
     */
    public void setSingletonInstance(Object singletonInstance) {
        this.singletonInstance = singletonInstance;
    }
    
    @Override
    public String toString() {
        return "BeanDefinition{" +
                "class=" + beanClass.getSimpleName() +
                ", name='" + name + '\'' +
                ", primary=" + isPrimary +
                ", singleton=" + isSingleton +
                '}';
    }
} 