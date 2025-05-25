package jazzyframework.data;

import jakarta.persistence.Entity;

import java.io.File;
import java.io.IOException;
import java.net.URL;
import java.util.ArrayList;
import java.util.Enumeration;
import java.util.List;
import java.util.logging.Logger;

/**
 * Scans packages for classes annotated with {@code @Entity} for Hibernate registration.
 * 
 * <p>This scanner provides automatic entity discovery by:
 * <ul>
 *   <li>Detecting the main class package from stack trace</li>
 *   <li>Recursively scanning all sub-packages</li>
 *   <li>Finding classes annotated with {@code @Entity}</li>
 *   <li>Providing the discovered entities to Hibernate configuration</li>
 * </ul>
 * 
 * <p>The scanning algorithm is identical to ComponentScanner but specifically
 * looks for JPA entities instead of DI components.
 * 
 * @since 0.3.0
 * @author Caner Mastan
 */
public class EntityScanner {
    private static final Logger logger = Logger.getLogger(EntityScanner.class.getName());

    /**
     * Scans for entity classes starting from the main class package.
     * 
     * @return list of entity classes found
     */
    public List<Class<?>> scanForEntities() {
        StackTraceElement[] stackTrace = Thread.currentThread().getStackTrace();
        String mainClassName = null;
        
        for (StackTraceElement element : stackTrace) {
            if ("main".equals(element.getMethodName())) {
                mainClassName = element.getClassName();
                break;
            }
        }
        
        if (mainClassName == null) {
            logger.warning("Could not detect main class, scanning common packages for entities");
            return scanCommonPackagesForEntities();
        }
        
        String basePackage = getBasePackage(mainClassName);
        logger.info("Scanning for entities from package: " + basePackage);
        
        return scanPackageForEntities(basePackage);
    }

    /**
     * Scans common package patterns when main class detection fails.
     * 
     * @return list of entity classes found
     */
    private List<Class<?>> scanCommonPackagesForEntities() {
        List<Class<?>> allEntities = new ArrayList<>();
        String[] commonPackages = {"com", "org", "net", "examples"};
        
        for (String pkg : commonPackages) {
            try {
                allEntities.addAll(scanPackageForEntities(pkg));
            } catch (Exception e) {
                // Ignore packages that don't exist
            }
        }
        
        return allEntities;
    }

    /**
     * Gets the base package from a fully qualified class name.
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
     * Scans the specified package for entity classes.
     * 
     * @param packageName the base package to scan
     * @return list of entity classes found
     */
    public List<Class<?>> scanPackageForEntities(String packageName) {
        List<Class<?>> entityClasses = new ArrayList<>();
        
        try {
            ClassLoader classLoader = Thread.currentThread().getContextClassLoader();
            String path = packageName.replace('.', '/');
            Enumeration<URL> resources = classLoader.getResources(path);
            
            while (resources.hasMoreElements()) {
                URL resource = resources.nextElement();
                File file = new File(resource.getFile());
                
                if (file.isDirectory()) {
                    entityClasses.addAll(findEntityClasses(file, packageName));
                }
            }
        } catch (IOException e) {
            logger.severe("Error scanning package for entities: " + packageName + " - " + e.getMessage());
        }
        
        if (!entityClasses.isEmpty()) {
            logger.fine("Found " + entityClasses.size() + " entity classes in package: " + packageName);
        }
        return entityClasses;
    }

    /**
     * Recursively finds entity classes in the given directory.
     * 
     * @param directory the directory to search
     * @param packageName the package name corresponding to the directory
     * @return list of entity classes found
     */
    private List<Class<?>> findEntityClasses(File directory, String packageName) {
        List<Class<?>> entityClasses = new ArrayList<>();
        
        if (!directory.exists()) {
            return entityClasses;
        }
        
        File[] files = directory.listFiles();
        if (files == null) {
            return entityClasses;
        }
        
        for (File file : files) {
            if (file.isDirectory()) {
                entityClasses.addAll(findEntityClasses(file, packageName + "." + file.getName()));
            } else if (file.getName().endsWith(".class")) {
                String className = packageName + '.' + file.getName().substring(0, file.getName().length() - 6);
                try {
                    Class<?> clazz = Class.forName(className);
                    if (isEntity(clazz)) {
                        entityClasses.add(clazz);
                        logger.fine("Found entity: " + className);
                    }
                } catch (ClassNotFoundException e) {
                    logger.warning("Could not load class: " + className);
                } catch (NoClassDefFoundError e) {
                    // Ignore classes that have missing dependencies
                    logger.fine("Skipping class with missing dependencies: " + className);
                }
            }
        }
        
        return entityClasses;
    }

    /**
     * Checks if a class is annotated with {@code @Entity}.
     * 
     * @param clazz the class to check
     * @return true if the class has {@code @Entity} annotation
     */
    private boolean isEntity(Class<?> clazz) {
        return clazz.isAnnotationPresent(Entity.class);
    }

    /**
     * Scans specific packages for entities.
     * Useful for testing or when you want to limit the scanning scope.
     * 
     * @param packages array of package names to scan
     * @return list of entity classes found
     */
    public List<Class<?>> scanPackagesForEntities(String... packages) {
        List<Class<?>> allEntities = new ArrayList<>();
        
        for (String packageName : packages) {
            allEntities.addAll(scanPackageForEntities(packageName));
        }
        
        return allEntities;
    }

    /**
     * Validates that an entity class is properly configured.
     * 
     * @param entityClass the entity class to validate
     * @return true if the entity is valid, false otherwise
     */
    public boolean validateEntity(Class<?> entityClass) {
        if (!isEntity(entityClass)) {
            logger.warning("Class is not annotated with @Entity: " + entityClass.getName());
            return false;
        }

        // Check for default constructor
        try {
            entityClass.getDeclaredConstructor();
        } catch (NoSuchMethodException e) {
            logger.warning("Entity class does not have a default constructor: " + entityClass.getName());
            return false;
        }

        return true;
    }
} 