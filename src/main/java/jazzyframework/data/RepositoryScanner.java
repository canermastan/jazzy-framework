package jazzyframework.data;

import jazzyframework.di.BeanDefinition;
import jazzyframework.di.annotations.Component;

import java.io.File;
import java.io.IOException;
import java.net.URL;
import java.util.ArrayList;
import java.util.Enumeration;
import java.util.List;
import java.util.logging.Logger;

/**
 * Scans packages for repository interfaces and creates proxy implementations.
 * 
 * <p>This scanner automatically discovers interfaces that extend BaseRepository
 * and creates proxy implementations using RepositoryFactory. The proxies are
 * then registered with the DI container for automatic injection.
 * 
 * <p>Key features:
 * <ul>
 *   <li>Automatic repository interface discovery</li>
 *   <li>Proxy implementation creation</li>
 *   <li>DI container integration</li>
 *   <li>Type-safe generic handling</li>
 * </ul>
 * 
 * @since 0.3.0
 * @author Caner Mastan
 */
@Component
public class RepositoryScanner {
    private static final Logger logger = Logger.getLogger(RepositoryScanner.class.getName());
    
    private final RepositoryFactory repositoryFactory;
    private final List<Class<?>> discoveredRepositories = new ArrayList<>();

    /**
     * Creates a new RepositoryScanner.
     * RepositoryFactory will be injected by the DI container.
     */
    public RepositoryScanner(RepositoryFactory repositoryFactory) {
        this.repositoryFactory = repositoryFactory;
    }

    /**
     * Scans for repository interfaces starting from the main class package.
     * 
     * @return list of discovered repository interfaces
     */
    public List<Class<?>> scanForRepositories() {
        StackTraceElement[] stackTrace = Thread.currentThread().getStackTrace();
        String mainClassName = null;
        
        for (StackTraceElement element : stackTrace) {
            if ("main".equals(element.getMethodName())) {
                mainClassName = element.getClassName();
                break;
            }
        }
        
        if (mainClassName == null) {
            logger.warning("Could not detect main class, scanning common packages for repositories");
            return scanCommonPackagesForRepositories();
        }
        
        String basePackage = getBasePackage(mainClassName);
        logger.info("Scanning for repositories from package: " + basePackage);
        
        return scanPackageForRepositories(basePackage);
    }

    /**
     * Scans common package patterns when main class detection fails.
     * 
     * @return list of repository interfaces found
     */
    private List<Class<?>> scanCommonPackagesForRepositories() {
        List<Class<?>> allRepositories = new ArrayList<>();
        String[] commonPackages = {"com", "org", "net", "examples"};
        
        for (String pkg : commonPackages) {
            try {
                allRepositories.addAll(scanPackageForRepositories(pkg));
            } catch (Exception e) {
                // Ignore packages that don't exist
            }
        }
        
        return allRepositories;
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
     * Scans the specified package for repository interfaces.
     * 
     * @param packageName the base package to scan
     * @return list of repository interfaces found
     */
    public List<Class<?>> scanPackageForRepositories(String packageName) {
        List<Class<?>> repositoryInterfaces = new ArrayList<>();
        
        try {
            ClassLoader classLoader = Thread.currentThread().getContextClassLoader();
            String path = packageName.replace('.', '/');
            Enumeration<URL> resources = classLoader.getResources(path);
            
            while (resources.hasMoreElements()) {
                URL resource = resources.nextElement();
                File file = new File(resource.getFile());
                
                if (file.isDirectory()) {
                    repositoryInterfaces.addAll(findRepositoryInterfaces(file, packageName));
                }
            }
        } catch (IOException e) {
            logger.severe("Error scanning package for repositories: " + packageName + " - " + e.getMessage());
        }
        
        if (!repositoryInterfaces.isEmpty()) {
            logger.fine("Found " + repositoryInterfaces.size() + " repository interfaces in package: " + packageName);
        }
        return repositoryInterfaces;
    }

    /**
     * Recursively finds repository interfaces in the given directory.
     * 
     * @param directory the directory to search
     * @param packageName the package name corresponding to the directory
     * @return list of repository interfaces found
     */
    private List<Class<?>> findRepositoryInterfaces(File directory, String packageName) {
        List<Class<?>> repositoryInterfaces = new ArrayList<>();
        
        if (!directory.exists()) {
            return repositoryInterfaces;
        }
        
        File[] files = directory.listFiles();
        if (files == null) {
            return repositoryInterfaces;
        }
        
        for (File file : files) {
            if (file.isDirectory()) {
                repositoryInterfaces.addAll(findRepositoryInterfaces(file, packageName + "." + file.getName()));
            } else if (file.getName().endsWith(".class")) {
                String className = packageName + '.' + file.getName().substring(0, file.getName().length() - 6);
                try {
                    Class<?> clazz = Class.forName(className);
                    if (isRepositoryInterface(clazz)) {
                        repositoryInterfaces.add(clazz);
                        discoveredRepositories.add(clazz);
                        logger.info("Found repository interface: " + className);
                    }
                } catch (ClassNotFoundException e) {
                    logger.warning("Could not load class: " + className);
                } catch (NoClassDefFoundError e) {
                    logger.fine("Skipping class with missing dependencies: " + className);
                }
            }
        }
        
        return repositoryInterfaces;
    }

    /**
     * Checks if a class is a repository interface (extends BaseRepository).
     * 
     * @param clazz the class to check
     * @return true if the class is a repository interface
     */
    private boolean isRepositoryInterface(Class<?> clazz) {
        return clazz.isInterface() && 
               BaseRepository.class.isAssignableFrom(clazz) &&
               !BaseRepository.class.equals(clazz);
    }

    /**
     * Creates repository implementations for discovered interfaces.
     * 
     * @return list of BeanDefinition objects for repository implementations
     */
    public List<BeanDefinition> createRepositoryBeans() {
        List<BeanDefinition> beanDefinitions = new ArrayList<>();
        
        List<Class<?>> repositories = scanForRepositories();
        
        for (Class<?> repositoryInterface : repositories) {
            try {
                Object repositoryImpl = repositoryFactory.createRepository(repositoryInterface);
                BeanDefinition beanDef = createRepositoryBeanDefinition(repositoryInterface, repositoryImpl);
                beanDefinitions.add(beanDef);
                
                logger.fine("Created repository bean: " + repositoryInterface.getSimpleName());
            } catch (Exception e) {
                logger.severe("Failed to create repository for interface: " + repositoryInterface.getName() + " - " + e.getMessage());
            }
        }
        
        return beanDefinitions;
    }

    /**
     * Creates a BeanDefinition for a repository implementation.
     * 
     * @param repositoryInterface the repository interface
     * @param repositoryImpl the repository implementation
     * @return the BeanDefinition
     */
    private BeanDefinition createRepositoryBeanDefinition(Class<?> repositoryInterface, Object repositoryImpl) {
        RepositoryBeanWrapper wrapper = new RepositoryBeanWrapper(repositoryInterface, repositoryImpl);
        
        BeanDefinition beanDef = new BeanDefinition(wrapper.getClass());
        beanDef.setSingletonInstance(wrapper);
        
        return beanDef;
    }

    /**
     * Gets the list of discovered repository interfaces.
     * 
     * @return list of discovered repositories
     */
    public List<Class<?>> getDiscoveredRepositories() {
        return new ArrayList<>(discoveredRepositories);
    }

    /**
     * Wrapper class for repository implementations to work with BeanDefinition.
     */
    public static class RepositoryBeanWrapper {
        private final Class<?> repositoryInterface;
        private final Object repositoryImpl;

        public RepositoryBeanWrapper(Class<?> repositoryInterface, Object repositoryImpl) {
            this.repositoryInterface = repositoryInterface;
            this.repositoryImpl = repositoryImpl;
        }

        public Class<?> getRepositoryInterface() {
            return repositoryInterface;
        }

        public Object getRepositoryImpl() {
            return repositoryImpl;
        }

        @Override
        public String toString() {
            return "RepositoryBean[" + repositoryInterface.getSimpleName() + "]";
        }
    }
} 