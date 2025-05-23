package jazzyframework.di;

import jazzyframework.di.annotations.Component;
import jazzyframework.di.annotations.Named;
import jazzyframework.di.annotations.Primary;

import java.io.File;
import java.io.IOException;
import java.net.URL;
import java.util.ArrayList;
import java.util.Enumeration;
import java.util.List;
import java.util.logging.Logger;

/**
 * Scans packages for classes annotated with {@code @Component} and creates 
 * {@link BeanDefinition} objects for dependency injection container registration.
 * 
 * <p>This scanner provides two main scanning strategies:
 * <ul>
 *   <li><b>Automatic detection:</b> Detects the main class package from stack trace</li>
 *   <li><b>Explicit scanning:</b> Scans specific packages provided by user</li>
 * </ul>
 * 
 * <p>The scanner also detects and processes DI-related annotations:
 * <ul>
 *   <li>{@code @Named} - for named component registration</li>
 *   <li>{@code @Primary} - for primary bean selection</li>
 *   <li>{@code @PostConstruct} and {@code @PreDestroy} - for lifecycle methods</li>
 *   <li>{@code @Singleton} and {@code @Prototype} - for scope management</li>
 * </ul>
 * 
 * @since 0.2
 * @author Caner Mastan
 */
public class ComponentScanner {
    private static final Logger logger = Logger.getLogger(ComponentScanner.class.getName());
    
    /**
     * Automatically scans for components starting from the main class package.
     * This method detects the package of the calling class and scans all sub-packages.
     * 
     * <p>The detection algorithm:
     * <ol>
     *   <li>Examines the stack trace for a method named "main"</li>
     *   <li>Extracts the package name from the main class</li>
     *   <li>Recursively scans that package and all sub-packages</li>
     *   <li>Falls back to common packages if main class detection fails</li>
     * </ol>
     * 
     * @return list of BeanDefinition objects for found components
     */
    public List<BeanDefinition> scanAllPackages() {
        StackTraceElement[] stackTrace = Thread.currentThread().getStackTrace();
        String mainClassName = null;
        
        for (StackTraceElement element : stackTrace) {
            if ("main".equals(element.getMethodName())) {
                mainClassName = element.getClassName();
                break;
            }
        }
        
        if (mainClassName == null) {
            logger.warning("Could not detect main class, scanning common packages");
            return scanCommonPackages();
        }
        
        String basePackage = getBasePackage(mainClassName);
        logger.info("Auto-detecting components from package: " + basePackage);
        
        return scanPackage(basePackage);
    }
    
    /**
     * Scans common package patterns when main class detection fails.
     * 
     * @return list of BeanDefinition objects for found components
     */
    private List<BeanDefinition> scanCommonPackages() {
        List<BeanDefinition> allBeans = new ArrayList<>();
        String[] commonPackages = {"com", "org", "net", "examples"};
        
        for (String pkg : commonPackages) {
            try {
                allBeans.addAll(scanPackage(pkg));
            } catch (Exception e) {
                // Ignore packages that don't exist
            }
        }
        
        return allBeans;
    }
    
    /**
     * Gets the base package from a fully qualified class name.
     * For example: "com.example.myapp.Main" -> "com.example.myapp"
     * 
     * @param className the fully qualified class name
     * @return the base package name
     */
    private String getBasePackage(String className) {
        int lastDot = className.lastIndexOf('.');
        if (lastDot > 0) {
            return className.substring(0, lastDot);
        }
        return "";
    }
    
    /**
     * Scans the specified package for component classes.
     * 
     * @param packageName the base package to scan
     * @return list of BeanDefinition objects for found components
     */
    public List<BeanDefinition> scanPackage(String packageName) {
        List<BeanDefinition> beanDefinitions = new ArrayList<>();
        
        try {
            ClassLoader classLoader = Thread.currentThread().getContextClassLoader();
            String path = packageName.replace('.', '/');
            Enumeration<URL> resources = classLoader.getResources(path);
            
            while (resources.hasMoreElements()) {
                URL resource = resources.nextElement();
                File file = new File(resource.getFile());
                
                if (file.isDirectory()) {
                    beanDefinitions.addAll(findClasses(file, packageName));
                }
            }
        } catch (IOException e) {
            logger.severe("Error scanning package: " + packageName + " - " + e.getMessage());
        }
        
        logger.info("Found " + beanDefinitions.size() + " components in package: " + packageName);
        return beanDefinitions;
    }
    
    /**
     * Recursively finds classes in the given directory.
     * 
     * @param directory the directory to search
     * @param packageName the package name corresponding to the directory
     * @return list of BeanDefinition objects for found components
     */
    private List<BeanDefinition> findClasses(File directory, String packageName) {
        List<BeanDefinition> beanDefinitions = new ArrayList<>();
        
        if (!directory.exists()) {
            return beanDefinitions;
        }
        
        File[] files = directory.listFiles();
        if (files == null) {
            return beanDefinitions;
        }
        
        for (File file : files) {
            if (file.isDirectory()) {
                beanDefinitions.addAll(findClasses(file, packageName + "." + file.getName()));
            } else if (file.getName().endsWith(".class")) {
                String className = packageName + '.' + file.getName().substring(0, file.getName().length() - 6);
                try {
                    Class<?> clazz = Class.forName(className);
                    if (isComponent(clazz)) {
                        BeanDefinition beanDef = new BeanDefinition(clazz);
                        beanDefinitions.add(beanDef);
                        
                        String info = "Found component: " + className;
                        if (clazz.isAnnotationPresent(Named.class)) {
                            info += " (@Named: " + clazz.getAnnotation(Named.class).value() + ")";
                        }
                        if (clazz.isAnnotationPresent(Primary.class)) {
                            info += " (@Primary)";
                        }
                        logger.info(info);
                    }
                } catch (ClassNotFoundException e) {
                    logger.warning("Could not load class: " + className);
                } catch (NoClassDefFoundError e) {
                    // Ignore classes that have missing dependencies
                    logger.fine("Skipping class with missing dependencies: " + className);
                }
            }
        }
        
        return beanDefinitions;
    }
    
    /**
     * Checks if a class is annotated with {@code @Component}.
     * 
     * @param clazz the class to check
     * @return true if the class has {@code @Component} annotation
     */
    private boolean isComponent(Class<?> clazz) {
        return clazz.isAnnotationPresent(Component.class);
    }
    
    /**
     * Gets the component name from annotation or uses class name.
     * 
     * @param clazz the component class
     * @return the component name
     */
    public String getComponentName(Class<?> clazz) {
        if (clazz.isAnnotationPresent(Named.class)) {
            return clazz.getAnnotation(Named.class).value();
        }
        if (clazz.isAnnotationPresent(Component.class)) {
            String value = clazz.getAnnotation(Component.class).value();
            return value.isEmpty() ? clazz.getSimpleName() : value;
        }
        return clazz.getSimpleName();
    }
} 