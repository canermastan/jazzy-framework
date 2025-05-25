package jazzyframework.di;

import jazzyframework.di.annotations.Named;
import jazzyframework.data.RepositoryScanner;
import jazzyframework.data.RepositoryFactory;
import jazzyframework.data.HibernateConfig;
import jazzyframework.core.PropertyLoader;
import org.picocontainer.DefaultPicoContainer;
import org.picocontainer.MutablePicoContainer;
import org.picocontainer.PicoContainer;

import java.lang.reflect.Constructor;
import java.lang.reflect.Method;
import java.lang.reflect.Parameter;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.logging.Logger;
import java.util.stream.Collectors;

/**
 * Advanced dependency injection container for Jazzy Framework.
 * 
 * <p>This container provides comprehensive DI features including:
 * <ul>
 *   <li>Automatic component discovery via package scanning</li>
 *   <li>Named injection with {@code @Named} annotation</li>
 *   <li>Primary bean selection with {@code @Primary} annotation</li>
 *   <li>Lifecycle management with {@code @PostConstruct} and {@code @PreDestroy}</li>
 *   <li>Singleton and Prototype scopes</li>
 *   <li>Constructor-based dependency injection</li>
 *   <li>Database integration with automatic repository discovery</li>
 *   <li>Property-based configuration management</li>
 * </ul>
 * 
 * <p>All components are automatically discovered and registered at server startup time.
 * The container uses PicoContainer as the underlying DI engine while providing
 * Spring-like annotation support and automatic configuration.
 * 
 * @since 0.3
 * @author Caner Mastan
 */
public class DIContainer {
    private static final Logger logger = Logger.getLogger(DIContainer.class.getName());
    private static DIContainer instance;
    
    private final MutablePicoContainer container;
    private final ComponentScanner scanner;
    final Map<String, BeanDefinition> beanDefinitions;
    final Map<Class<?>, List<BeanDefinition>> typeIndex;
    private final List<Object> managedBeans;
    boolean initialized = false;
    
    /**
     * Creates a new DI container.
     */
    public DIContainer() {
        this.container = new DefaultPicoContainer();
        this.scanner = new ComponentScanner();
        this.beanDefinitions = new HashMap<>();
        this.typeIndex = new HashMap<>();
        this.managedBeans = new ArrayList<>();
    }
    
    /**
     * Gets the singleton instance of the DI container.
     * 
     * @return the singleton DI container instance
     */
    public static synchronized DIContainer getInstance() {
        if (instance == null) {
            instance = new DIContainer();
        }
        return instance;
    }
    
    /**
     * Initializes the DI container with automatic component discovery.
     * Automatically scans all packages starting from the main class package.
     * This should be called once at server startup.
     */
    public void initialize() {
        if (initialized) {
            logger.warning("DI Container is already initialized");
            return;
        }
        
        logger.info("Initializing Advanced DI Container with automatic component discovery...");
        
        // First, register core infrastructure components
        registerInfrastructureComponents();
        
        // Scan for user components (@Component, @Service, @Controller, etc.)
        List<BeanDefinition> componentBeans = scanner.scanAllPackages();
        
        for (BeanDefinition beanDef : componentBeans) {
            registerBeanDefinition(beanDef);
        }
        
        // Initialize database infrastructure if enabled
        initializeDatabaseInfrastructure();
        
        // Scan and register repositories
        registerRepositories();
        
        validateDependencies();
        
        initialized = true;
        logger.info("Advanced DI Container initialized with " + beanDefinitions.size() + 
                   " components automatically discovered");
    }
    
    /**
     * Registers core infrastructure components.
     */
    private void registerInfrastructureComponents() {
        logger.info("Registering core infrastructure components...");
        
        // Register PropertyLoader as singleton
        PropertyLoader propertyLoader = PropertyLoader.getInstance();
        BeanDefinition propertyLoaderDef = new BeanDefinition(PropertyLoader.class);
        propertyLoaderDef.setSingletonInstance(propertyLoader);
        registerBeanDefinition(propertyLoaderDef);
        
        logger.info("Core infrastructure components registered");
    }
    
    /**
     * Initializes database infrastructure if enabled.
     */
    private void initializeDatabaseInfrastructure() {
        PropertyLoader propertyLoader = PropertyLoader.getInstance();
        
        if (!propertyLoader.isDatabaseEnabled()) {
            logger.info("Database is disabled, skipping database infrastructure initialization");
            return;
        }
        
        logger.info("Initializing database infrastructure...");
        
        try {
            // Register HibernateConfig
            BeanDefinition hibernateConfigDef = new BeanDefinition(HibernateConfig.class);
            registerBeanDefinition(hibernateConfigDef);
            
            // Create and initialize HibernateConfig instance
            HibernateConfig hibernateConfig = createBean(hibernateConfigDef);
            hibernateConfigDef.setSingletonInstance(hibernateConfig);
            
            // Register RepositoryFactory
            BeanDefinition repositoryFactoryDef = new BeanDefinition(RepositoryFactory.class);
            registerBeanDefinition(repositoryFactoryDef);
            
            logger.info("Database infrastructure initialized successfully");
        } catch (Exception e) {
            logger.severe("Failed to initialize database infrastructure: " + e.getMessage());
            throw new RuntimeException("Database initialization failed", e);
        }
    }
    
    /**
     * Scans and registers repository interfaces.
     */
    private void registerRepositories() {
        PropertyLoader propertyLoader = PropertyLoader.getInstance();
        
        if (!propertyLoader.isDatabaseEnabled()) {
            logger.info("Database is disabled, skipping repository scanning");
            return;
        }
        
        logger.info("Scanning for repository interfaces...");
        
        try {
            RepositoryFactory repositoryFactory = getComponentInternal(RepositoryFactory.class);
            RepositoryScanner repositoryScanner = new RepositoryScanner(repositoryFactory);
            
            List<BeanDefinition> repositoryBeans = repositoryScanner.createRepositoryBeans();
            
            for (BeanDefinition repositoryBean : repositoryBeans) {
                // Get the actual repository interface and implementation
                RepositoryScanner.RepositoryBeanWrapper wrapper = 
                    (RepositoryScanner.RepositoryBeanWrapper) repositoryBean.getSingletonInstance();
                
                Class<?> repositoryInterface = wrapper.getRepositoryInterface();
                Object repositoryImpl = wrapper.getRepositoryImpl();
                
                // Create a proper bean definition for the repository interface
                BeanDefinition repoDef = new BeanDefinition(repositoryInterface);
                repoDef.setSingletonInstance(repositoryImpl);
                
                registerBeanDefinition(repoDef);
                
                logger.info("Registered repository: " + repositoryInterface.getSimpleName());
            }
            
            logger.info("Repository scanning completed. Found " + repositoryBeans.size() + " repositories");
        } catch (Exception e) {
            logger.severe("Failed to scan repositories: " + e.getMessage());
            throw new RuntimeException("Repository scanning failed", e);
        }
    }
    
    /**
     * Internal method to get component without initialization check.
     * Used during container initialization to avoid chicken-and-egg problems.
     * 
     * @param type the class type
     * @param <T> the type parameter
     * @return the component instance with dependencies injected
     */
    private <T> T getComponentInternal(Class<T> type) {
        List<BeanDefinition> candidates = typeIndex.get(type);
        if (candidates == null || candidates.isEmpty()) {
            return createInstance(type);
        }
        
        BeanDefinition beanDef = selectCandidate(candidates, type);
        return createBean(beanDef);
    }
    
    /**
     * Internal method to get component by name without initialization check.
     * Used during container initialization to avoid chicken-and-egg problems.
     * 
     * @param name the component name
     * @param <T> the type parameter
     * @return the component instance
     */
    @SuppressWarnings("unchecked")
    private <T> T getComponentInternal(String name) {
        BeanDefinition beanDef = beanDefinitions.get(name);
        if (beanDef == null) {
            throw new IllegalArgumentException("No bean found with name: " + name);
        }
        
        return (T) createBean(beanDef);
    }
    
    /**
     * Registers a bean definition and builds indexes.
     * 
     * @param beanDef the bean definition to register
     */
    void registerBeanDefinition(BeanDefinition beanDef) {
        Class<?> beanClass = beanDef.getBeanClass();
        String name = beanDef.getName();
        
        beanDefinitions.put(name, beanDef);
        buildTypeIndex(beanClass, beanDef);
        
        logger.info("Registered bean definition: " + beanDef);
    }
    
    /**
     * Builds type index for fast lookup by type.
     * Indexes the bean by its class, all implemented interfaces, and superclass.
     * 
     * @param clazz the class to index
     * @param beanDef the bean definition
     */
    private void buildTypeIndex(Class<?> clazz, BeanDefinition beanDef) {
        typeIndex.computeIfAbsent(clazz, k -> new ArrayList<>()).add(beanDef);
        
        for (Class<?> iface : clazz.getInterfaces()) {
            typeIndex.computeIfAbsent(iface, k -> new ArrayList<>()).add(beanDef);
        }
        
        Class<?> superclass = clazz.getSuperclass();
        if (superclass != null && superclass != Object.class) {
            typeIndex.computeIfAbsent(superclass, k -> new ArrayList<>()).add(beanDef);
        }
    }
    
    /**
     * Validates dependencies and detects conflicts.
     * Warns about multiple beans without {@code @Primary} annotation and
     * throws exception for multiple {@code @Primary} beans of same type.
     * 
     * @throws IllegalStateException if multiple {@code @Primary} beans found for same type
     */
    private void validateDependencies() {
        for (Map.Entry<Class<?>, List<BeanDefinition>> entry : typeIndex.entrySet()) {
            Class<?> type = entry.getKey();
            List<BeanDefinition> candidates = entry.getValue();
            
            if (candidates.size() > 1) {
                long primaryCount = candidates.stream().filter(BeanDefinition::isPrimary).count();
                
                if (primaryCount == 0) {
                    logger.warning("Multiple beans found for type " + type.getSimpleName() + 
                                 " but no @Primary annotation. Consider using @Named or @Primary. Beans: " + 
                                 candidates);
                } else if (primaryCount > 1) {
                    throw new IllegalStateException("Multiple @Primary beans found for type " + 
                                                  type.getSimpleName() + ": " + candidates);
                }
            }
        }
    }
    
    /**
     * Gets a component instance by class type.
     * Handles @Primary annotation for conflict resolution.
     * 
     * @param type the class type
     * @param <T> the type parameter
     * @return the component instance with dependencies injected
     */
    public <T> T getComponent(Class<T> type) {
        if (!initialized) {
            throw new IllegalStateException("DI Container is not initialized. Call initialize() first.");
        }
        
        List<BeanDefinition> candidates = typeIndex.get(type);
        if (candidates == null || candidates.isEmpty()) {
            return createInstance(type);
        }
        
        BeanDefinition beanDef = selectCandidate(candidates, type);
        return createBean(beanDef);
    }
    
    /**
     * Gets a component instance by name.
     * 
     * @param name the component name
     * @param <T> the type parameter
     * @return the component instance
     */
    @SuppressWarnings("unchecked")
    public <T> T getComponent(String name) {
        if (!initialized) {
            throw new IllegalStateException("DI Container is not initialized. Call initialize() first.");
        }
        
        BeanDefinition beanDef = beanDefinitions.get(name);
        if (beanDef == null) {
            throw new IllegalArgumentException("No bean found with name: " + name);
        }
        
        return (T) createBean(beanDef);
    }
    
    /**
     * Selects the best candidate from multiple options.
     */
    private BeanDefinition selectCandidate(List<BeanDefinition> candidates, Class<?> type) {
        if (candidates.size() == 1) {
            return candidates.get(0);
        }
        
        List<BeanDefinition> primaryBeans = candidates.stream()
            .filter(BeanDefinition::isPrimary)
            .collect(Collectors.toList());
        
        if (primaryBeans.size() == 1) {
            return primaryBeans.get(0);
        } else if (primaryBeans.size() > 1) {
            throw new IllegalStateException("Multiple @Primary beans found for type " + 
                                          type.getSimpleName() + ": " + primaryBeans);
        }
        
        throw new IllegalStateException(
            "Multiple beans found for type " + type.getSimpleName() + 
            " but no @Primary annotation. Available beans: " + candidates + 
            ". Use @Named injection or add @Primary annotation.");
    }
    
    /**
     * Creates a bean instance according to its definition.
     */
    @SuppressWarnings("unchecked")
    private <T> T createBean(BeanDefinition beanDef) {
        if (beanDef.isSingleton() && beanDef.getSingletonInstance() != null) {
            return (T) beanDef.getSingletonInstance();
        }
        
        Object instance = createInstanceWithDI(beanDef.getBeanClass());
        callPostConstructMethods(instance, beanDef);
        
        if (beanDef.isSingleton()) {
            beanDef.setSingletonInstance(instance);
        }
        
        if (!managedBeans.contains(instance)) {
            managedBeans.add(instance);
        }
        
        return (T) instance;
    }
    
    /**
     * Creates an instance with dependency injection using constructor parameters.
     */
    @SuppressWarnings("unchecked")
    private <T> T createInstanceWithDI(Class<T> type) {
        try {
            Constructor<?>[] constructors = type.getConstructors();
            if (constructors.length == 0) {
                return type.getDeclaredConstructor().newInstance();
            }
            
            Constructor<?> constructor = constructors[0];
            Parameter[] parameters = constructor.getParameters();
            Object[] args = new Object[parameters.length];
            
            for (int i = 0; i < parameters.length; i++) {
                Parameter param = parameters[i];
                Class<?> paramType = param.getType();
                
                Named namedAnnotation = param.getAnnotation(Named.class);
                if (namedAnnotation != null) {
                    args[i] = getComponentInternal(namedAnnotation.value());
                } else {
                    args[i] = getComponentInternal(paramType);
                }
            }
            
            return (T) constructor.newInstance(args);
        } catch (Exception e) {
            logger.warning("Failed to create instance with DI for " + type.getSimpleName() + ": " + e.getMessage());
            try {
                return type.getDeclaredConstructor().newInstance();
            } catch (Exception ex) {
                throw new RuntimeException("Cannot create instance of " + type.getSimpleName(), ex);
            }
        }
    }
    
    /**
     * Calls @PostConstruct methods on the bean.
     */
    private void callPostConstructMethods(Object instance, BeanDefinition beanDef) {
        for (Method method : beanDef.getPostConstructMethods()) {
            try {
                method.setAccessible(true);
                method.invoke(instance);
                logger.info("Called @PostConstruct method: " + 
                           beanDef.getBeanClass().getSimpleName() + "." + method.getName());
            } catch (Exception e) {
                logger.severe("Failed to call @PostConstruct method: " + e.getMessage());
            }
        }
    }
    
    /**
     * Creates an instance of the specified class with dependency injection.
     * This method can create instances even for classes not registered as components.
     * 
     * @param type the class type
     * @param <T> the type parameter
     * @return the created instance with dependencies injected
     */
    public <T> T createInstance(Class<T> type) {
        return createInstanceWithDI(type);
    }
    
    /**
     * Checks if the container is initialized.
     * 
     * @return true if initialized, false otherwise
     */
    public boolean isInitialized() {
        return initialized;
    }
    
    /**
     * Gets all registered bean definitions.
     * 
     * @return map of bean names to definitions
     */
    public Map<String, BeanDefinition> getBeanDefinitions() {
        return new HashMap<>(beanDefinitions);
    }
    
    /**
     * Gets the underlying PicoContainer.
     * 
     * @return the PicoContainer instance
     */
    public PicoContainer getContainer() {
        return container;
    }
    
    /**
     * Disposes the container and releases all resources.
     * Calls @PreDestroy methods on all managed beans.
     */
    public void dispose() {
        logger.info("Disposing DI Container...");
        
        for (Object bean : managedBeans) {
            callPreDestroyMethods(bean);
        }
        
        container.dispose();
        managedBeans.clear();
        beanDefinitions.clear();
        typeIndex.clear();
        initialized = false;
        
        logger.info("DI Container disposed");
    }
    
    /**
     * Shuts down the container and releases all resources.
     * This is an alias for dispose() method.
     */
    public void shutdown() {
        dispose();
    }
    
    /**
     * Calls @PreDestroy methods on the bean.
     */
    private void callPreDestroyMethods(Object bean) {
        BeanDefinition beanDef = findBeanDefinition(bean.getClass());
        if (beanDef != null) {
            for (Method method : beanDef.getPreDestroyMethods()) {
                try {
                    method.setAccessible(true);
                    method.invoke(bean);
                    logger.info("Called @PreDestroy method: " + 
                               bean.getClass().getSimpleName() + "." + method.getName());
                } catch (Exception e) {
                    logger.severe("Failed to call @PreDestroy method: " + e.getMessage());
                }
            }
        }
    }
    
    /**
     * Finds bean definition by class.
     */
    private BeanDefinition findBeanDefinition(Class<?> clazz) {
        for (BeanDefinition beanDef : beanDefinitions.values()) {
            if (beanDef.getBeanClass().equals(clazz)) {
                return beanDef;
            }
        }
        return null;
    }
} 