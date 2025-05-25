package jazzyframework.data;

import jazzyframework.data.annotations.Modifying;
import jazzyframework.data.annotations.Query;
import jazzyframework.di.annotations.Component;
import jazzyframework.di.annotations.PostConstruct;
import org.hibernate.Session;
import org.hibernate.SessionFactory;
import org.hibernate.Transaction;

import java.lang.reflect.InvocationHandler;
import java.lang.reflect.Method;
import java.lang.reflect.ParameterizedType;
import java.lang.reflect.Proxy;
import java.lang.reflect.Type;
import java.util.List;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;
import java.util.logging.Logger;

/**
 * Factory for creating repository implementations automatically.
 * 
 * <p>This factory creates proxy implementations for repository interfaces
 * that extend BaseRepository, similar to Spring Data JPA's approach.
 * The proxy supports:
 * <ul>
 *   <li>Method name parsing (findByEmail, countByActive, etc.)</li>
 *   <li>@Query annotations for custom HQL/JPQL</li>
 *   <li>Native SQL queries</li>
 *   <li>@Modifying annotations for UPDATE/DELETE operations</li>
 * </ul>
 * 
 * @since 0.3.0
 * @author Caner Mastan
 */
@Component
public class RepositoryFactory {
    private static final Logger logger = Logger.getLogger(RepositoryFactory.class.getName());
    
    private final HibernateConfig hibernateConfig;
    private final ConcurrentHashMap<Class<?>, Object> repositoryCache = new ConcurrentHashMap<>();
    private final QueryMethodParser queryParser = new QueryMethodParser();
    private SessionFactory sessionFactory;

    /**
     * Creates a new RepositoryFactory.
     * HibernateConfig will be injected by the DI container.
     */
    public RepositoryFactory(HibernateConfig hibernateConfig) {
        this.hibernateConfig = hibernateConfig;
    }

    /**
     * Initializes the factory after DI container setup.
     */
    @PostConstruct
    public void initialize() {
        if (hibernateConfig.isInitialized()) {
            this.sessionFactory = hibernateConfig.getSessionFactory();
            logger.info("RepositoryFactory initialized with SessionFactory");
        } else {
            logger.warning("HibernateConfig is not initialized, repositories may not work properly");
        }
    }

    /**
     * Creates a repository implementation for the given repository interface.
     * 
     * @param repositoryInterface the repository interface class
     * @param <T> the repository type
     * @return the repository implementation
     */
    @SuppressWarnings("unchecked")
    public <T> T createRepository(Class<T> repositoryInterface) {
        if (sessionFactory == null) {
            throw new IllegalStateException("SessionFactory is not available. Ensure database is enabled and configured.");
        }

        // Check cache first
        T cachedRepository = (T) repositoryCache.get(repositoryInterface);
        if (cachedRepository != null) {
            return cachedRepository;
        }

        // Validate that the interface extends BaseRepository
        if (!BaseRepository.class.isAssignableFrom(repositoryInterface)) {
            throw new IllegalArgumentException("Repository interface must extend BaseRepository: " + repositoryInterface.getName());
        }

        // Extract generic type parameters
        Type[] genericTypes = extractGenericTypes(repositoryInterface);
        Class<?> entityClass = (Class<?>) genericTypes[0];
        Class<?> idClass = (Class<?>) genericTypes[1];

        // Create the implementation
        BaseRepositoryImpl<?, ?> implementation = new BaseRepositoryImpl<>(sessionFactory, entityClass, idClass);

        // Create proxy with enhanced handler
        T proxy = (T) Proxy.newProxyInstance(
            repositoryInterface.getClassLoader(),
            new Class<?>[]{repositoryInterface},
            new EnhancedRepositoryInvocationHandler(implementation, entityClass, sessionFactory, queryParser)
        );

        // Cache the proxy
        repositoryCache.put(repositoryInterface, proxy);
        
        logger.fine("Created repository: " + repositoryInterface.getSimpleName() + 
                   " for entity: " + entityClass.getSimpleName());

        return proxy;
    }

    /**
     * Extracts generic type parameters from repository interface.
     * 
     * @param repositoryInterface the repository interface
     * @return array of generic types [entityType, idType]
     */
    private Type[] extractGenericTypes(Class<?> repositoryInterface) {
        // Look for BaseRepository in the interface hierarchy
        Type[] genericInterfaces = repositoryInterface.getGenericInterfaces();
        
        for (Type genericInterface : genericInterfaces) {
            if (genericInterface instanceof ParameterizedType) {
                ParameterizedType parameterizedType = (ParameterizedType) genericInterface;
                Type rawType = parameterizedType.getRawType();
                
                if (BaseRepository.class.equals(rawType)) {
                    Type[] actualTypeArguments = parameterizedType.getActualTypeArguments();
                    if (actualTypeArguments.length == 2) {
                        return actualTypeArguments;
                    }
                }
            }
        }

        throw new IllegalArgumentException("Could not extract generic types from repository interface: " + repositoryInterface.getName());
    }

    /**
     * Checks if a repository has been created for the given interface.
     * 
     * @param repositoryInterface the repository interface
     * @return true if a repository exists in cache
     */
    public boolean hasRepository(Class<?> repositoryInterface) {
        return repositoryCache.containsKey(repositoryInterface);
    }

    /**
     * Clears the repository cache.
     */
    public void clearCache() {
        repositoryCache.clear();
    }

    /**
     * Gets the number of cached repositories.
     * 
     * @return the cache size
     */
    public int getCacheSize() {
        return repositoryCache.size();
    }

    /**
     * Enhanced InvocationHandler for repository proxies with query support.
     */
    private static class EnhancedRepositoryInvocationHandler implements InvocationHandler {
        private final BaseRepositoryImpl<?, ?> implementation;
        private final Class<?> entityClass;
        private final SessionFactory sessionFactory;
        private final QueryMethodParser queryParser;

        public EnhancedRepositoryInvocationHandler(BaseRepositoryImpl<?, ?> implementation, 
                                                 Class<?> entityClass,
                                                 SessionFactory sessionFactory,
                                                 QueryMethodParser queryParser) {
            this.implementation = implementation;
            this.entityClass = entityClass;
            this.sessionFactory = sessionFactory;
            this.queryParser = queryParser;
        }

        @Override
        public Object invoke(Object proxy, Method method, Object[] args) throws Throwable {
            try {
                // Handle Object methods
                if (method.getDeclaringClass() == Object.class) {
                    return method.invoke(implementation, args);
                }

                // Handle toString specially for better debugging
                if ("toString".equals(method.getName()) && method.getParameterCount() == 0) {
                    return "RepositoryProxy[" + entityClass.getSimpleName() + "Repository]";
                }

                // 1. Check for @Query annotation
                Query queryAnnotation = method.getAnnotation(Query.class);
                if (queryAnnotation != null) {
                    return executeCustomQuery(method, args, queryAnnotation);
                }

                // 2. Check if method name can be parsed
                if (queryParser.canParseMethodName(method.getName())) {
                    return executeGeneratedQuery(method, args);
                }

                // 3. Handle default methods
                if (method.isDefault()) {
                    return java.lang.invoke.MethodHandles.lookup()
                        .findSpecial(
                            method.getDeclaringClass(),
                            method.getName(),
                            java.lang.invoke.MethodType.methodType(method.getReturnType(), method.getParameterTypes()),
                            method.getDeclaringClass()
                        )
                        .bindTo(proxy)
                        .invokeWithArguments(args);
                }

                // 4. Delegate to BaseRepository implementation
                return method.invoke(implementation, args);

            } catch (java.lang.reflect.InvocationTargetException e) {
                Throwable cause = e.getCause();
                if (cause instanceof RuntimeException) {
                    throw (RuntimeException) cause;
                } else if (cause instanceof Error) {
                    throw (Error) cause;
                } else {
                    throw new RuntimeException("Repository operation failed", cause);
                }
            } catch (Exception e) {
                throw new RuntimeException("Unexpected repository error", e);
            }
        }

        /**
         * Executes a custom query defined by @Query annotation.
         */
        private Object executeCustomQuery(Method method, Object[] args, Query queryAnnotation) {
            String queryString = queryAnnotation.value();
            boolean isNative = queryAnnotation.nativeQuery();
            boolean isModifying = method.isAnnotationPresent(Modifying.class);

            try (Session session = sessionFactory.openSession()) {
                Transaction transaction = session.beginTransaction();

                org.hibernate.query.Query<?> query;
                if (isNative) {
                    query = session.createNativeQuery(queryString);
                } else {
                    query = session.createQuery(queryString);
                }

                // Set parameters
                if (args != null) {
                    for (int i = 0; i < args.length; i++) {
                        query.setParameter(i + 1, args[i]);
                    }
                }

                Object result;
                if (isModifying) {
                    result = query.executeUpdate();
                } else {
                    Class<?> returnType = method.getReturnType();
                    if (returnType == Optional.class) {
                        result = Optional.ofNullable(query.uniqueResult());
                    } else if (List.class.isAssignableFrom(returnType)) {
                        result = query.list();
                    } else if (returnType == Long.class || returnType == long.class) {
                        result = query.uniqueResult();
                    } else {
                        result = query.uniqueResult();
                    }
                }

                transaction.commit();
                return result;
            }
        }

        /**
         * Executes a query generated from method name parsing.
         */
        private Object executeGeneratedQuery(Method method, Object[] args) {
            QueryMethodParser.QueryInfo queryInfo = queryParser.parseMethod(method, entityClass);

            try (Session session = sessionFactory.openSession()) {
                Transaction transaction = session.beginTransaction();

                org.hibernate.query.Query<?> query = session.createQuery(queryInfo.getQuery());

                // Set parameters
                List<String> paramNames = queryInfo.getParameterNames();
                if (args != null && paramNames.size() <= args.length) {
                    for (int i = 0; i < paramNames.size(); i++) {
                        Object value = args[i];
                        
                        // Handle special cases for string operations
                        String paramName = paramNames.get(i);
                        if (queryInfo.getQuery().contains("LIKE") && value instanceof String) {
                            String stringValue = (String) value;
                            if (queryInfo.getQuery().contains("Containing")) {
                                value = "%" + stringValue + "%";
                            } else if (queryInfo.getQuery().contains("StartingWith")) {
                                value = stringValue + "%";
                            } else if (queryInfo.getQuery().contains("EndingWith")) {
                                value = "%" + stringValue;
                            }
                        }
                        
                        query.setParameter(paramName, value);
                    }
                }

                Object result;
                String operation = queryInfo.getOperation();
                
                if ("exists".equals(operation)) {
                    Long count = (Long) query.uniqueResult();
                    result = count != null && count > 0;
                } else if ("count".equals(operation)) {
                    result = query.uniqueResult();
                } else if ("delete".equals(operation)) {
                    result = query.executeUpdate();
                } else {
                    // find operation
                    Class<?> returnType = method.getReturnType();
                    if (returnType == Optional.class || queryInfo.isOptionalReturn()) {
                        result = Optional.ofNullable(query.uniqueResult());
                    } else if (List.class.isAssignableFrom(returnType)) {
                        result = query.list();
                    } else {
                        result = query.uniqueResult();
                    }
                }

                transaction.commit();
                return result;
            }
        }
    }
} 