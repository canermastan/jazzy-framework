package jazzyframework.data;

import jazzyframework.data.annotations.Crud;
import jazzyframework.di.DIContainer;
import jazzyframework.http.ApiResponse;
import jazzyframework.http.Request;
import jazzyframework.http.Response;
import jazzyframework.routing.Router;

import java.lang.reflect.Constructor;
import java.lang.reflect.Field;
import java.lang.reflect.Method;
import java.lang.reflect.ParameterizedType;
import java.lang.reflect.Type;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.logging.Logger;

/**
 * Processes @Crud annotations and automatically generates CRUD operations.
 * 
 * <p>This class is responsible for:
 * <ul>
 *   <li>Scanning controller classes for @Crud annotations</li>
 *   <li>Automatically registering CRUD endpoints with the router</li>
 *   <li>Generating default CRUD method implementations</li>
 *   <li>Integrating with the repository layer for database operations</li>
 * </ul>
 * 
 * <p>The processor works by:
 * <ol>
 *   <li>Finding the repository field/parameter in the controller</li>
 *   <li>Creating dynamic method implementations for CRUD operations</li>
 *   <li>Registering these methods with the router</li>
 *   <li>Handling pagination, validation, and response formatting</li>
 * </ol>
 * 
 * @since 0.4.0
 * @author Caner Mastan
 */
public class CrudProcessor {
    private static final Logger logger = Logger.getLogger(CrudProcessor.class.getName());
    
    private final Router router;
    private final DIContainer diContainer;
    private static final Map<String, CrudControllerWrapper> crudWrappers = new HashMap<>();
    private static CrudGlobalController globalController;
    
    /**
     * Creates a new CrudProcessor.
     * 
     * @param router the router to register endpoints with
     * @param diContainer the DI container for dependency resolution
     */
    public CrudProcessor(Router router, DIContainer diContainer) {
        this.router = router;
        this.diContainer = diContainer;
        
        // Create global CRUD controller singleton
        if (globalController == null) {
            globalController = new CrudGlobalController();
        }
    }
    
    /**
     * Processes all controllers with @Crud annotations from the DI container.
     */
    public void processAllCrudControllers() {
        Map<String, ?> allBeans = diContainer.getBeanDefinitions();
        
        for (Object value : allBeans.values()) {
            if (value instanceof jazzyframework.di.BeanDefinition) {
                jazzyframework.di.BeanDefinition beanDef = (jazzyframework.di.BeanDefinition) value;
                Class<?> beanClass = beanDef.getBeanClass();
                
                if (beanClass.isAnnotationPresent(Crud.class)) {
                    processController(beanClass);
                }
            }
        }
    }
    
    /**
     * Processes a controller class and registers CRUD endpoints if @Crud annotation is present.
     * 
     * @param controllerClass the controller class to process
     */
    @SuppressWarnings("unchecked")
    public void processController(Class<?> controllerClass) {
        Crud crudAnnotation = controllerClass.getAnnotation(Crud.class);
        if (crudAnnotation == null) {
            return; // No @Crud annotation, skip processing
        }
        
        try {
            // Find the repository field or constructor parameter
            BaseRepository<?, ?> repository = findRepository(controllerClass, crudAnnotation.entity());
            if (repository == null) {
                logger.warning("No suitable repository found for " + controllerClass.getSimpleName());
                return;
            }
            
            // Extract entity and ID types
            Class<?> entityType = crudAnnotation.entity();
            Class<?> idType = extractIdType(repository);
            
            // Create CRUD controller wrapper
            CrudControllerWrapper wrapper = new CrudControllerWrapper(
                repository, entityType, idType, crudAnnotation
            );
            
            // Register CRUD endpoints
            registerCrudEndpoints(wrapper, crudAnnotation, controllerClass);
            
        } catch (Exception e) {
            logger.severe("Failed to process CRUD controller " + controllerClass.getSimpleName() + ": " + e.getMessage());
            e.printStackTrace();
        }
    }
    
    /**
     * Finds the repository field or constructor parameter in the controller.
     */
    @SuppressWarnings("unchecked")
    private BaseRepository<?, ?> findRepository(Class<?> controllerClass, Class<?> entityType) {
        try {
            // First, try to get the controller instance from DI container
            Object controllerInstance = diContainer.getComponent(controllerClass);
            if (controllerInstance == null) {
                logger.warning("Controller instance not found in DI container: " + controllerClass.getSimpleName());
                return null;
            }
            
            // Look for repository field
            for (Field field : controllerClass.getDeclaredFields()) {
                if (BaseRepository.class.isAssignableFrom(field.getType())) {
                    field.setAccessible(true);
                    BaseRepository<?, ?> repository = (BaseRepository<?, ?>) field.get(controllerInstance);
                    if (repository != null && isRepositoryForEntity(repository, entityType)) {
                        return repository;
                    }
                }
            }
            
            logger.warning("No suitable repository field found in " + controllerClass.getSimpleName());
            return null;
            
        } catch (Exception e) {
            logger.severe("Error finding repository: " + e.getMessage());
            return null;
        }
    }
    
    /**
     * Checks if the repository is for the specified entity type.
     */
    private boolean isRepositoryForEntity(BaseRepository<?, ?> repository, Class<?> entityType) {
        // This is a simplified check - in a real implementation, we would
        // extract the generic type parameters from the repository interface
        return true; // For now, assume any repository works
    }
    
    /**
     * Extracts the ID type from the repository.
     */
    private Class<?> extractIdType(BaseRepository<?, ?> repository) {
        // Try to extract ID type from repository interface
        Type[] interfaces = repository.getClass().getGenericInterfaces();
        for (Type interfaceType : interfaces) {
            if (interfaceType instanceof ParameterizedType) {
                ParameterizedType paramType = (ParameterizedType) interfaceType;
                if (BaseRepository.class.isAssignableFrom((Class<?>) paramType.getRawType())) {
                    Type[] typeArgs = paramType.getActualTypeArguments();
                    if (typeArgs.length >= 2) {
                        return (Class<?>) typeArgs[1]; // Second type parameter is ID type
                    }
                }
            }
        }
        
        // Default to Long if we can't determine the ID type
        return Long.class;
    }
    
    /**
     * Registers CRUD endpoints with the router.
     */
    private void registerCrudEndpoints(CrudControllerWrapper wrapper, Crud crudAnnotation, Class<?> controllerClass) {
        String endpoint = crudAnnotation.endpoint();
        String idParam = crudAnnotation.idParam();
        
        // Store wrapper with unique key for later lookup
        String wrapperKey = endpoint; // Use endpoint as key for simplicity
        crudWrappers.put(wrapperKey, wrapper);
        
        // Check which methods are overridden in the controller
        boolean hasFindAll = hasMethod(controllerClass, "findAll");
        boolean hasFindById = hasMethod(controllerClass, "findById");
        boolean hasCreate = hasMethod(controllerClass, "create");
        boolean hasUpdate = hasMethod(controllerClass, "update");
        boolean hasDelete = hasMethod(controllerClass, "delete");
        
        // === BASIC CRUD ENDPOINTS ===
        
        // Only register auto-generated endpoints if the method is NOT overridden
        if (!hasFindAll) {
            router.GET(endpoint, "crudFindAll", CrudGlobalController.class);
        }
        
        if (!hasFindById) {
            router.GET(endpoint + "/{" + idParam + "}", "crudFindById", CrudGlobalController.class);
        }
        
        if (!hasCreate) {
            router.POST(endpoint, "crudCreate", CrudGlobalController.class);
        }
        
        if (!hasUpdate) {
            router.PUT(endpoint + "/{" + idParam + "}", "crudUpdate", CrudGlobalController.class);
        }
        
        if (!hasDelete) {
            router.DELETE(endpoint + "/{" + idParam + "}", "crudDelete", CrudGlobalController.class);
        }
        
        // === EXTENDED CRUD ENDPOINTS ===
        
        // Search endpoint
        if (crudAnnotation.enableSearch()) {
            router.GET(endpoint + "/search", "crudSearch", CrudGlobalController.class);
        }
        
        // Count endpoint
        if (crudAnnotation.enableCount()) {
            router.GET(endpoint + "/count", "crudCount", CrudGlobalController.class);
        }
        
        // Exists endpoint
        if (crudAnnotation.enableExists()) {
            router.GET(endpoint + "/exists/{" + idParam + "}", "crudExists", CrudGlobalController.class);
        }
        
        // Batch operations
        if (crudAnnotation.enableBatchOperations()) {
            router.POST(endpoint + "/batch", "crudCreateBatch", CrudGlobalController.class);
            router.PUT(endpoint + "/batch", "crudUpdateBatch", CrudGlobalController.class);
            router.DELETE(endpoint + "/batch", "crudDeleteBatch", CrudGlobalController.class);
        }
    }
    
    /**
     * Checks if a controller class has a specific method defined.
     * 
     * <p>This method is used to detect method overrides in controllers that use
     * the @Crud annotation. If a method is found, the auto-generation for that
     * specific CRUD operation will be skipped.
     * 
     * @param controllerClass the controller class to inspect
     * @param methodName the method name to look for
     * @return true if the method exists with correct signature, false otherwise
     */
    private boolean hasMethod(Class<?> controllerClass, String methodName) {
        try {
            Method method = controllerClass.getDeclaredMethod(methodName, Request.class);
            return method != null;
        } catch (NoSuchMethodException e) {
            return false;
        }
    }
    
    /**
     * Gets a CRUD wrapper by endpoint.
     * 
     * <p>This method is used internally to retrieve the appropriate CRUD wrapper
     * for handling requests to auto-generated endpoints. The wrapper contains
     * the repository instance and configuration needed for CRUD operations.
     * 
     * @param endpoint the endpoint path to look up
     * @return the CRUD wrapper for the endpoint, or null if not found
     */
    public static CrudControllerWrapper getCrudWrapper(String endpoint) {
        return crudWrappers.get(endpoint);
    }
    
    /**
     * Global CRUD controller that handles all CRUD operations.
     * This controller is registered with the DI container and delegates to the appropriate wrapper.
     */
    @jazzyframework.di.annotations.Component
    public static class CrudGlobalController {
        
        public Response crudFindAll(Request request) {
            String endpoint = extractEndpoint(request.getPath());
            
            CrudControllerWrapper wrapper = getCrudWrapper(endpoint);
            if (wrapper != null) {
                return wrapper.findAll(request);
            } else {
                return Response.json(ApiResponse.error("CRUD wrapper not found for endpoint: " + endpoint)).status(500);
            }
        }
        
        public Response crudFindById(Request request) {
            String endpoint = extractEndpoint(request.getPath());
            
            CrudControllerWrapper wrapper = getCrudWrapper(endpoint);
            if (wrapper != null) {
                return wrapper.findById(request);
            } else {
                return Response.json(ApiResponse.error("CRUD wrapper not found for endpoint: " + endpoint)).status(500);
            }
        }
        
        public Response crudCreate(Request request) {
            String endpoint = extractEndpoint(request.getPath());
            
            CrudControllerWrapper wrapper = getCrudWrapper(endpoint);
            if (wrapper != null) {
                return wrapper.create(request);
            } else {
                return Response.json(ApiResponse.error("CRUD wrapper not found for endpoint: " + endpoint)).status(500);
            }
        }
        
        public Response crudUpdate(Request request) {
            String endpoint = extractEndpoint(request.getPath());
            
            CrudControllerWrapper wrapper = getCrudWrapper(endpoint);
            if (wrapper != null) {
                return wrapper.update(request);
            } else {
                return Response.json(ApiResponse.error("CRUD wrapper not found for endpoint: " + endpoint)).status(500);
            }
        }
        
        public Response crudDelete(Request request) {
            String endpoint = extractEndpoint(request.getPath());
            
            CrudControllerWrapper wrapper = getCrudWrapper(endpoint);
            if (wrapper != null) {
                return wrapper.delete(request);
            } else {
                return Response.json(ApiResponse.error("CRUD wrapper not found for endpoint: " + endpoint)).status(500);
            }
        }
        
        // === EXTENDED CRUD OPERATIONS ===
        
        /**
         * Handles search requests for entities with filtering capabilities.
         * 
         * <p>This method processes GET requests to /endpoint/search and supports:
         * <ul>
         *   <li>Field-specific filtering based on searchableFields configuration</li>
         *   <li>Generic search using the 'q' query parameter</li>
         *   <li>Multiple filter combinations</li>
         * </ul>
         * 
         * @param request the HTTP request containing search parameters
         * @return Response containing filtered entities with search metadata
         */
        public Response crudSearch(Request request) {
            String endpoint = extractEndpointFromSearch(request.getPath());
            
            CrudControllerWrapper wrapper = getCrudWrapper(endpoint);
            if (wrapper != null) {
                return wrapper.search(request);
            } else {
                return Response.json(ApiResponse.error("CRUD wrapper not found for endpoint: " + endpoint)).status(500);
            }
        }
        
        /**
         * Handles count requests to get the total number of entities.
         * 
         * <p>This method processes GET requests to /endpoint/count and returns
         * the total count of entities managed by the repository.
         * 
         * @param request the HTTP request
         * @return Response containing the total entity count
         */
        public Response crudCount(Request request) {
            String endpoint = extractEndpointFromUtility(request.getPath(), "/count");
            
            CrudControllerWrapper wrapper = getCrudWrapper(endpoint);
            if (wrapper != null) {
                return wrapper.count(request);
            } else {
                return Response.json(ApiResponse.error("CRUD wrapper not found for endpoint: " + endpoint)).status(500);
            }
        }
        
        /**
         * Handles existence check requests for specific entities.
         * 
         * <p>This method processes GET requests to /endpoint/exists/{id} to check
         * whether an entity with the given ID exists in the repository.
         * 
         * @param request the HTTP request containing the entity ID in path parameters
         * @return Response indicating whether the entity exists
         */
        public Response crudExists(Request request) {
            String endpoint = extractEndpointFromExists(request.getPath());
            
            CrudControllerWrapper wrapper = getCrudWrapper(endpoint);
            if (wrapper != null) {
                return wrapper.exists(request);
            } else {
                return Response.json(ApiResponse.error("CRUD wrapper not found for endpoint: " + endpoint)).status(500);
            }
        }
        
        /**
         * Handles batch creation requests for multiple entities.
         * 
         * <p>This method processes POST requests to /endpoint/batch and creates
         * multiple entities in a single operation. The request body should contain
         * an 'entities' array with entity data objects.
         * 
         * @param request the HTTP request containing entities array in JSON body
         * @return Response with creation results and error details
         */
        public Response crudCreateBatch(Request request) {
            String endpoint = extractEndpointFromBatch(request.getPath());
            
            CrudControllerWrapper wrapper = getCrudWrapper(endpoint);
            if (wrapper != null) {
                return wrapper.createBatch(request);
            } else {
                return Response.json(ApiResponse.error("CRUD wrapper not found for endpoint: " + endpoint)).status(500);
            }
        }
        
        /**
         * Handles batch update requests for multiple entities.
         * 
         * <p>This method processes PUT requests to /endpoint/batch and updates
         * multiple entities in a single operation. Each entity in the request
         * must include its ID for identification.
         * 
         * @param request the HTTP request containing entities array with IDs in JSON body
         * @return Response with updated entities and detailed operation results
         */
        public Response crudUpdateBatch(Request request) {
            String endpoint = extractEndpointFromBatch(request.getPath());
            
            CrudControllerWrapper wrapper = getCrudWrapper(endpoint);
            if (wrapper != null) {
                return wrapper.updateBatch(request);
            } else {
                return Response.json(ApiResponse.error("CRUD wrapper not found for endpoint: " + endpoint)).status(500);
            }
        }
        
        /**
         * Handles DELETE /endpoint/batch - delete multiple entities.
         * 
         * <p>Deletes multiple entities identified by their IDs in a single request:
         * <pre>
         * {
         *   "ids": [1, 2, 3, 4, 5]
         * }
         * </pre>
         * 
         * <p>Features:
         * <ul>
         *   <li>Validates entity existence before deletion</li>
         *   <li>Respects maxBatchSize configuration limit</li>
         *   <li>Continues processing even if individual deletions fail</li>
         *   <li>Returns list of successfully deleted IDs</li>
         * </ul>
         * 
         * @param request the HTTP request containing IDs array in JSON body
         * @return Response with deleted IDs and detailed operation results
         */
        public Response crudDeleteBatch(Request request) {
            String endpoint = extractEndpointFromBatch(request.getPath());
            
            CrudControllerWrapper wrapper = getCrudWrapper(endpoint);
            if (wrapper != null) {
                return wrapper.deleteBatch(request);
            } else {
                return Response.json(ApiResponse.error("CRUD wrapper not found for endpoint: " + endpoint)).status(500);
            }
        }
        
        /**
         * Extracts the base endpoint from a request path.
         * For example: "/api/users/123" -> "/api/users"
         */
        private String extractEndpoint(String path) {
            if (path == null) return "";
            
            // Remove query parameters if any
            if (path.contains("?")) {
                path = path.substring(0, path.indexOf("?"));
            }
            
            // For paths like /api/users/123, extract /api/users
            String[] segments = path.split("/");
            if (segments.length >= 3) {
                // Check if last segment is likely an ID (numeric)
                String lastSegment = segments[segments.length - 1];
                if (isNumeric(lastSegment)) {
                    // Remove the ID part
                    return path.substring(0, path.lastIndexOf("/"));
                }
            }
            
            return path;
        }
        
        private boolean isNumeric(String str) {
            try {
                Long.parseLong(str);
                return true;
            } catch (NumberFormatException e) {
                return false;
            }
        }
        
        /**
         * Extracts endpoint from search path.
         * For example: "/api/users/search" -> "/api/users"
         */
        private String extractEndpointFromSearch(String path) {
            if (path == null) return "";
            
            // Remove query parameters if any
            if (path.contains("?")) {
                path = path.substring(0, path.indexOf("?"));
            }
            
            // Remove /search suffix
            if (path.endsWith("/search")) {
                return path.substring(0, path.lastIndexOf("/search"));
            }
            
            return path;
        }
        
        /**
         * Extracts endpoint from utility paths like /count.
         * For example: "/api/users/count" -> "/api/users"
         */
        private String extractEndpointFromUtility(String path, String suffix) {
            if (path == null) return "";
            
            // Remove query parameters if any
            if (path.contains("?")) {
                path = path.substring(0, path.indexOf("?"));
            }
            
            // Remove the suffix
            if (path.endsWith(suffix)) {
                return path.substring(0, path.lastIndexOf(suffix));
            }
            
            return path;
        }
        
        /**
         * Extracts endpoint from exists path.
         * For example: "/api/users/exists/123" -> "/api/users"
         */
        private String extractEndpointFromExists(String path) {
            if (path == null) return "";
            
            // Remove query parameters if any
            if (path.contains("?")) {
                path = path.substring(0, path.indexOf("?"));
            }
            
            // For /api/users/exists/123, extract /api/users
            String[] segments = path.split("/");
            for (int i = 0; i < segments.length; i++) {
                if ("exists".equals(segments[i]) && i >= 1) {
                    // Reconstruct path up to "exists"
                    StringBuilder sb = new StringBuilder();
                    for (int j = 0; j < i; j++) {
                        if (!segments[j].isEmpty()) {
                            sb.append("/").append(segments[j]);
                        }
                    }
                    return sb.toString();
                }
            }
            
            return path;
        }
        
        /**
         * Extracts endpoint from batch path.
         * For example: "/api/users/batch" -> "/api/users"
         */
        private String extractEndpointFromBatch(String path) {
            return extractEndpointFromUtility(path, "/batch");
        }
    }
    
    /**
     * Wrapper class that provides CRUD method implementations.
     */
    public static class CrudControllerWrapper {
        private final BaseRepository<Object, Object> repository;
        private final Class<?> entityType;
        private final Class<?> idType;
        private final Crud crudConfig;
        private final Logger logger = Logger.getLogger(CrudControllerWrapper.class.getName());
        
        @SuppressWarnings("unchecked")
        public CrudControllerWrapper(BaseRepository<?, ?> repository, Class<?> entityType, Class<?> idType, Crud crudConfig) {
            this.repository = (BaseRepository<Object, Object>) repository;
            this.entityType = entityType;
            this.idType = idType;
            this.crudConfig = crudConfig;
        }
        
        /**
         * Handles GET /endpoint - find all entities with optional pagination.
         */
        public Response findAll(Request request) {
            try {
                if (crudConfig.enablePagination()) {
                    return findAllWithPagination(request);
                } else {
                    List<Object> entities = repository.findAll();
                    ApiResponse apiResponse = createSuccessResponse("Entities retrieved successfully", entities);
                    return Response.json(apiResponse);
                }
            } catch (Exception e) {
                logger.severe("Error in findAll: " + e.getMessage());
                ApiResponse errorResponse = createErrorResponse("Failed to retrieve entities", e.getMessage());
                return Response.json(errorResponse).status(500);
            }
        }
        
        /**
         * Handles pagination for findAll.
         */
        private Response findAllWithPagination(Request request) {
            int page = request.queryInt("page", 1);
            int size = Math.min(
                request.queryInt("size", crudConfig.defaultPageSize()),
                crudConfig.maxPageSize()
            );
            
            // For now, implement simple pagination
            // In a real implementation, we would use JPA Pageable
            List<Object> allEntities = repository.findAll();
            long total = allEntities.size();
            int totalPages = (int) Math.ceil((double) total / size);
            
            int start = (page - 1) * size;
            int end = Math.min(start + size, allEntities.size());
            
            List<Object> pageContent = start < allEntities.size() ? 
                allEntities.subList(start, end) : 
                List.of();
            
            ApiResponse apiResponse = createSuccessResponse("Entities retrieved successfully", pageContent)
                .withPagination(page, size, total, totalPages);
            
            return Response.json(apiResponse);
        }
        
        /**
         * Handles GET /endpoint/{id} - find entity by ID.
         */
        public Response findById(Request request) {
            try {
                Object id = convertId(request.path(crudConfig.idParam()));
                Optional<Object> entity = repository.findById(id);
                
                if (entity.isPresent()) {
                    ApiResponse apiResponse = createSuccessResponse("Entity retrieved successfully", entity.get());
                    return Response.json(apiResponse);
                } else {
                    ApiResponse errorResponse = createErrorResponse("Entity not found", null);
                    return Response.json(errorResponse).status(404);
                }
            } catch (Exception e) {
                logger.severe("Error in findById: " + e.getMessage());
                ApiResponse errorResponse = createErrorResponse("Failed to retrieve entity", e.getMessage());
                return Response.json(errorResponse).status(500);
            }
        }
        
        /**
         * Handles POST /endpoint - create new entity.
         */
        public Response create(Request request) {
            try {
                Object entity = request.toObject(entityType);
                Object savedEntity = repository.save(entity);
                
                ApiResponse apiResponse = createSuccessResponse("Entity created successfully", savedEntity);
                return Response.json(apiResponse).status(201);
            } catch (Exception e) {
                logger.severe("Error in create: " + e.getMessage());
                ApiResponse errorResponse = createErrorResponse("Failed to create entity", e.getMessage());
                return Response.json(errorResponse).status(400);
            }
        }
        
        /**
         * Handles PUT /endpoint/{id} - update entity.
         */
        public Response update(Request request) {
            try {
                Object id = convertId(request.path(crudConfig.idParam()));
                
                // Check if entity exists
                if (!repository.existsById(id)) {
                    ApiResponse errorResponse = createErrorResponse("Entity not found", null);
                    return Response.json(errorResponse).status(404);
                }
                
                Object entity = request.toObject(entityType);
                // Set ID on the entity (assuming it has a setId method or similar)
                setEntityId(entity, id);
                
                Object updatedEntity = repository.save(entity);
                
                ApiResponse apiResponse = createSuccessResponse("Entity updated successfully", updatedEntity);
                return Response.json(apiResponse);
            } catch (Exception e) {
                logger.severe("Error in update: " + e.getMessage());
                ApiResponse errorResponse = createErrorResponse("Failed to update entity", e.getMessage());
                return Response.json(errorResponse).status(400);
            }
        }
        
        /**
         * Handles DELETE /endpoint/{id} - delete entity.
         */
        public Response delete(Request request) {
            try {
                Object id = convertId(request.path(crudConfig.idParam()));
                
                if (!repository.existsById(id)) {
                    ApiResponse errorResponse = createErrorResponse("Entity not found", null);
                    return Response.json(errorResponse).status(404);
                }
                
                if (crudConfig.softDelete()) {
                    // Implement soft delete logic here
                    // For now, just do hard delete
                    repository.deleteById(id);
                } else {
                    repository.deleteById(id);
                }
                
                ApiResponse apiResponse = createSuccessResponse("Entity deleted successfully", null);
                return Response.json(apiResponse);
            } catch (Exception e) {
                logger.severe("Error in delete: " + e.getMessage());
                ApiResponse errorResponse = createErrorResponse("Failed to delete entity", e.getMessage());
                return Response.json(errorResponse).status(500);
            }
        }
        
        // === EXTENDED CRUD OPERATIONS ===
        
        /**
         * Handles GET /endpoint/search - search entities with filters.
         * 
         * <p>This method provides flexible search capabilities:
         * <ul>
         *   <li>Field-specific search: Use query parameters matching searchableFields</li>
         *   <li>Generic search: Use 'q' parameter to search across all string fields</li>
         *   <li>Case-insensitive matching with contains semantics</li>
         * </ul>
         * 
         * <p>Example requests:
         * <pre>
         * GET /users/search?name=john        (search by name field)
         * GET /users/search?email=gmail.com  (search by email field)
         * GET /users/search?q=alice          (generic search)
         * </pre>
         * 
         * @param request the HTTP request containing search parameters in query string
         * @return Response containing filtered entities with search metadata
         */
        public Response search(Request request) {
            try {
                List<Object> allEntities = repository.findAll();
                List<Object> filteredEntities = allEntities;
                
                // Apply search filters if specified
                if (crudConfig.searchableFields().length > 0) {
                    filteredEntities = applySearchFilters(allEntities, request);
                } else {
                    // Apply generic search if no specific fields configured
                    String query = request.query("q");
                    if (query != null && !query.trim().isEmpty()) {
                        filteredEntities = applyGenericSearch(allEntities, query);
                    }
                }
                
                ApiResponse apiResponse = createSuccessResponse("Search completed successfully", filteredEntities)
                    .withMetadata("totalFound", filteredEntities.size())
                    .withMetadata("searchQuery", request.query("q", ""));
                
                return Response.json(apiResponse);
            } catch (Exception e) {
                logger.severe("Error in search: " + e.getMessage());
                ApiResponse errorResponse = createErrorResponse("Search failed", e.getMessage());
                return Response.json(errorResponse).status(500);
            }
        }
        
        /**
         * Handles GET /endpoint/count - get total entity count.
         * 
         * <p>Returns the total number of entities managed by this repository.
         * Useful for pagination calculations and statistics.
         * 
         * @param request the HTTP request (parameters ignored)
         * @return Response containing the total count with entity type metadata
         */
        public Response count(Request request) {
            try {
                List<Object> allEntities = repository.findAll();
                long totalCount = allEntities.size();
                
                ApiResponse apiResponse = createSuccessResponse("Count retrieved successfully", totalCount)
                    .withMetadata("entityType", entityType.getSimpleName());
                
                return Response.json(apiResponse);
            } catch (Exception e) {
                logger.severe("Error in count: " + e.getMessage());
                ApiResponse errorResponse = createErrorResponse("Failed to get count", e.getMessage());
                return Response.json(errorResponse).status(500);
            }
        }
        
        /**
         * Handles GET /endpoint/exists/{id} - check if entity exists.
         * 
         * <p>Checks whether an entity with the specified ID exists in the repository
         * without actually retrieving the entity data. More efficient than findById
         * when you only need to verify existence.
         * 
         * @param request the HTTP request containing entity ID in path parameters
         * @return Response containing boolean existence result with ID metadata
         */
        public Response exists(Request request) {
            try {
                Object id = convertId(request.path(crudConfig.idParam()));
                boolean exists = repository.existsById(id);
                
                ApiResponse apiResponse = createSuccessResponse("Existence check completed", exists)
                    .withMetadata("entityId", id)
                    .withMetadata("exists", exists);
                
                return Response.json(apiResponse);
            } catch (Exception e) {
                logger.severe("Error in exists: " + e.getMessage());
                ApiResponse errorResponse = createErrorResponse("Failed to check existence", e.getMessage());
                return Response.json(errorResponse).status(500);
            }
        }
        
        /**
         * Handles POST /endpoint/batch - create multiple entities.
         * 
         * <p>Creates multiple entities in a single request. The request body should
         * contain an JSON object with an 'entities' array:
         * <pre>
         * {
         *   "entities": [
         *     {"name": "User1", "email": "user1@example.com"},
         *     {"name": "User2", "email": "user2@example.com"}
         *   ]
         * }
         * </pre>
         * 
         * <p>Features:
         * <ul>
         *   <li>Respects maxBatchSize configuration limit</li>
         *   <li>Continues processing even if individual entities fail</li>
         *   <li>Returns detailed success/error counts and error messages</li>
         * </ul>
         * 
         * @param request the HTTP request containing entities array in JSON body
         * @return Response with created entities and detailed operation results
         */
        public Response createBatch(Request request) {
            try {
                Map<String, Object> jsonData = request.parseJson();
                @SuppressWarnings("unchecked")
                List<Map<String, Object>> entitiesData = (List<Map<String, Object>>) jsonData.get("entities");
                
                if (entitiesData == null || entitiesData.isEmpty()) {
                    return Response.json(ApiResponse.error("No entities provided for batch creation")).status(400);
                }
                
                if (entitiesData.size() > crudConfig.maxBatchSize()) {
                    return Response.json(ApiResponse.error("Batch size exceeds maximum allowed: " + crudConfig.maxBatchSize())).status(400);
                }
                
                List<Object> savedEntities = new ArrayList<>();
                List<String> errors = new ArrayList<>();
                
                for (int i = 0; i < entitiesData.size(); i++) {
                    try {
                        // Convert map to entity (simplified - in real implementation would use proper JSON mapping)
                        Object entity = convertMapToEntity(entitiesData.get(i));
                        Object savedEntity = repository.save(entity);
                        savedEntities.add(savedEntity);
                    } catch (Exception e) {
                        errors.add("Entity " + i + ": " + e.getMessage());
                    }
                }
                
                ApiResponse apiResponse = createSuccessResponse("Batch create completed", savedEntities)
                    .withMetadata("successCount", savedEntities.size())
                    .withMetadata("errorCount", errors.size())
                    .withMetadata("errors", errors);
                
                return Response.json(apiResponse).status(201);
            } catch (Exception e) {
                logger.severe("Error in createBatch: " + e.getMessage());
                ApiResponse errorResponse = createErrorResponse("Batch create failed", e.getMessage());
                return Response.json(errorResponse).status(500);
            }
        }
        
        /**
         * Handles PUT /endpoint/batch - update multiple entities.
         * 
         * <p>Updates multiple existing entities in a single request. Each entity
         * must include its ID for identification:
         * <pre>
         * {
         *   "entities": [
         *     {"id": 1, "name": "Updated User1", "email": "updated1@example.com"},
         *     {"id": 2, "name": "Updated User2", "email": "updated2@example.com"}
         *   ]
         * }
         * </pre>
         * 
         * <p>Features:
         * <ul>
         *   <li>Validates entity existence before updating</li>
         *   <li>Respects maxBatchSize configuration limit</li>
         *   <li>Provides detailed error reporting for failed updates</li>
         * </ul>
         * 
         * @param request the HTTP request containing entities with IDs in JSON body
         * @return Response with updated entities and detailed operation results
         */
        public Response updateBatch(Request request) {
            try {
                Map<String, Object> jsonData = request.parseJson();
                @SuppressWarnings("unchecked")
                List<Map<String, Object>> entitiesData = (List<Map<String, Object>>) jsonData.get("entities");
                
                if (entitiesData == null || entitiesData.isEmpty()) {
                    return Response.json(ApiResponse.error("No entities provided for batch update")).status(400);
                }
                
                if (entitiesData.size() > crudConfig.maxBatchSize()) {
                    return Response.json(ApiResponse.error("Batch size exceeds maximum allowed: " + crudConfig.maxBatchSize())).status(400);
                }
                
                List<Object> updatedEntities = new ArrayList<>();
                List<String> errors = new ArrayList<>();
                
                for (int i = 0; i < entitiesData.size(); i++) {
                    try {
                        Map<String, Object> entityData = entitiesData.get(i);
                        Object id = entityData.get("id");
                        
                        if (id == null) {
                            errors.add("Entity " + i + ": Missing ID for update");
                            continue;
                        }
                        
                        if (!repository.existsById(id)) {
                            errors.add("Entity " + i + ": Entity with ID " + id + " not found");
                            continue;
                        }
                        
                        Object entity = convertMapToEntity(entityData);
                        setEntityId(entity, id);
                        Object updatedEntity = repository.save(entity);
                        updatedEntities.add(updatedEntity);
                    } catch (Exception e) {
                        errors.add("Entity " + i + ": " + e.getMessage());
                    }
                }
                
                ApiResponse apiResponse = createSuccessResponse("Batch update completed", updatedEntities)
                    .withMetadata("successCount", updatedEntities.size())
                    .withMetadata("errorCount", errors.size())
                    .withMetadata("errors", errors);
                
                return Response.json(apiResponse);
            } catch (Exception e) {
                logger.severe("Error in updateBatch: " + e.getMessage());
                ApiResponse errorResponse = createErrorResponse("Batch update failed", e.getMessage());
                return Response.json(errorResponse).status(500);
            }
        }
        
        /**
         * Handles DELETE /endpoint/batch - delete multiple entities.
         * 
         * <p>Deletes multiple entities identified by their IDs in a single request:
         * <pre>
         * {
         *   "ids": [1, 2, 3, 4, 5]
         * }
         * </pre>
         * 
         * <p>Features:
         * <ul>
         *   <li>Validates entity existence before deletion</li>
         *   <li>Respects maxBatchSize configuration limit</li>
         *   <li>Continues processing even if individual deletions fail</li>
         *   <li>Returns list of successfully deleted IDs</li>
         * </ul>
         * 
         * @param request the HTTP request containing IDs array in JSON body
         * @return Response with deleted IDs and detailed operation results
         */
        public Response deleteBatch(Request request) {
            try {
                Map<String, Object> jsonData = request.parseJson();
                @SuppressWarnings("unchecked")
                List<Object> ids = (List<Object>) jsonData.get("ids");
                
                if (ids == null || ids.isEmpty()) {
                    return Response.json(ApiResponse.error("No IDs provided for batch deletion")).status(400);
                }
                
                if (ids.size() > crudConfig.maxBatchSize()) {
                    return Response.json(ApiResponse.error("Batch size exceeds maximum allowed: " + crudConfig.maxBatchSize())).status(400);
                }
                
                List<Object> deletedIds = new ArrayList<>();
                List<String> errors = new ArrayList<>();
                
                for (int i = 0; i < ids.size(); i++) {
                    try {
                        Object id = convertId(ids.get(i).toString());
                        
                        if (!repository.existsById(id)) {
                            errors.add("ID " + id + ": Entity not found");
                            continue;
                        }
                        
                        repository.deleteById(id);
                        deletedIds.add(id);
                    } catch (Exception e) {
                        errors.add("ID " + ids.get(i) + ": " + e.getMessage());
                    }
                }
                
                ApiResponse apiResponse = createSuccessResponse("Batch delete completed", deletedIds)
                    .withMetadata("successCount", deletedIds.size())
                    .withMetadata("errorCount", errors.size())
                    .withMetadata("errors", errors);
                
                return Response.json(apiResponse);
            } catch (Exception e) {
                logger.severe("Error in deleteBatch: " + e.getMessage());
                ApiResponse errorResponse = createErrorResponse("Batch delete failed", e.getMessage());
                return Response.json(errorResponse).status(500);
            }
        }
        
        /**
         * Converts string ID to appropriate type.
         * 
         * <p>Supports conversion to common ID types including Long, Integer, and String.
         * The target type is determined by the repository's ID type parameter.
         * 
         * @param idString the ID as a string from path parameters
         * @return the converted ID object
         * @throws IllegalArgumentException if the ID type is not supported or conversion fails
         */
        private Object convertId(String idString) {
            if (idType == Long.class || idType == long.class) {
                return Long.parseLong(idString);
            } else if (idType == Integer.class || idType == int.class) {
                return Integer.parseInt(idString);
            } else if (idType == String.class) {
                return idString;
            } else {
                throw new IllegalArgumentException("Unsupported ID type: " + idType);
            }
        }
        
        /**
         * Sets the ID on an entity using reflection.
         * 
         * <p>This method tries to set the entity's ID by first looking for a setId method,
         * and if that fails, directly accessing the id field. This ensures compatibility
         * with different entity design patterns.
         * 
         * @param entity the entity to set the ID on
         * @param id the ID value to set
         */
        private void setEntityId(Object entity, Object id) {
            try {
                // Try to find setId method
                Method setIdMethod = entity.getClass().getMethod("setId", idType);
                setIdMethod.invoke(entity, id);
            } catch (Exception e) {
                // Try to find id field
                try {
                    Field idField = entity.getClass().getDeclaredField("id");
                    idField.setAccessible(true);
                    idField.set(entity, id);
                } catch (Exception ex) {
                    // Silently continue if ID cannot be set
                }
            }
        }
        
        /**
         * Creates a success response using the configured response wrapper.
         */
        private ApiResponse createSuccessResponse(String message, Object data) {
            try {
                if (crudConfig.responseWrapper() != ApiResponse.class) {
                    // Use custom response wrapper
                    Constructor<?> constructor = crudConfig.responseWrapper()
                        .getConstructor(boolean.class, String.class, Object.class);
                    return (ApiResponse) constructor.newInstance(true, message, data);
                } else {
                    return ApiResponse.success(message, data);
                }
            } catch (Exception e) {
                return ApiResponse.success(message, data);
            }
        }
        
        /**
         * Creates an error response using the configured response wrapper.
         */
        private ApiResponse createErrorResponse(String message, Object data) {
            try {
                if (crudConfig.responseWrapper() != ApiResponse.class) {
                    // Use custom response wrapper
                    Constructor<?> constructor = crudConfig.responseWrapper()
                        .getConstructor(boolean.class, String.class, Object.class);
                    return (ApiResponse) constructor.newInstance(false, message, data);
                } else {
                    return ApiResponse.error(message, data);
                }
            } catch (Exception e) {
                return ApiResponse.error(message, data);
            }
        }
        
        // === HELPER METHODS FOR EXTENDED FEATURES ===
        
        /**
         * Applies search filters based on configured searchable fields.
         * 
         * <p>This method filters entities based on query parameters that match
         * the configured searchableFields. Uses case-insensitive contains matching.
         * If no specific field filters are provided, returns all entities.
         * 
         * @param entities the list of entities to filter
         * @param request the HTTP request containing filter parameters
         * @return filtered list of entities
         */
        private List<Object> applySearchFilters(List<Object> entities, Request request) {
            List<Object> filtered = new ArrayList<>();
            String[] searchableFields = crudConfig.searchableFields();
            
            for (Object entity : entities) {
                boolean matches = false;
                
                for (String fieldName : searchableFields) {
                    String queryValue = request.query(fieldName);
                    if (queryValue != null && !queryValue.trim().isEmpty()) {
                        String fieldValue = getFieldValue(entity, fieldName);
                        if (fieldValue != null && fieldValue.toLowerCase().contains(queryValue.toLowerCase())) {
                            matches = true;
                            break;
                        }
                    }
                }
                
                // If no specific field filters provided, include all
                if (!matches) {
                    boolean hasAnyFilter = false;
                    for (String fieldName : searchableFields) {
                        if (request.query(fieldName) != null) {
                            hasAnyFilter = true;
                            break;
                        }
                    }
                    if (!hasAnyFilter) {
                        matches = true;
                    }
                }
                
                if (matches) {
                    filtered.add(entity);
                }
            }
            
            return filtered;
        }
        
        /**
         * Applies generic search across all string fields.
         * 
         * <p>Performs case-insensitive contains search across all fields of entities
         * using reflection. Useful when no specific searchable fields are configured.
         * 
         * @param entities the list of entities to search
         * @param query the search query string
         * @return entities containing the query string in any field
         */
        private List<Object> applyGenericSearch(List<Object> entities, String query) {
            List<Object> filtered = new ArrayList<>();
            String lowerQuery = query.toLowerCase();
            
            for (Object entity : entities) {
                if (entityContainsQuery(entity, lowerQuery)) {
                    filtered.add(entity);
                }
            }
            
            return filtered;
        }
        
        /**
         * Converts a Map to an entity object (simplified implementation).
         * 
         * <p>This is a basic JSON-to-entity converter that uses reflection to set
         * field values. In a production framework, this would be replaced with
         * a more robust JSON mapping library like Jackson or Gson.
         * 
         * @param data the map containing entity field data
         * @return the created entity instance
         * @throws Exception if entity creation or field setting fails
         */
        private Object convertMapToEntity(Map<String, Object> data) throws Exception {
            // This is a simplified implementation
            // In a real framework, you would use a proper JSON mapper like Jackson
            
            Object entity = entityType.getDeclaredConstructor().newInstance();
            
            for (Map.Entry<String, Object> entry : data.entrySet()) {
                try {
                    setFieldValue(entity, entry.getKey(), entry.getValue());
                } catch (Exception e) {
                    // Silently continue if field cannot be set
                }
            }
            
            return entity;
        }
        
        /**
         * Gets field value from entity using reflection.
         * 
         * <p>Safely retrieves the value of a field from an entity instance.
         * Returns null if the field doesn't exist or cannot be accessed.
         * 
         * @param entity the entity to get the field value from
         * @param fieldName the name of the field
         * @return the field value as a string, or null if not accessible
         */
        private String getFieldValue(Object entity, String fieldName) {
            try {
                Field field = entity.getClass().getDeclaredField(fieldName);
                field.setAccessible(true);
                Object value = field.get(entity);
                return value != null ? value.toString() : null;
            } catch (Exception e) {
                return null;
            }
        }
        
        /**
         * Sets field value on entity using reflection.
         * 
         * <p>Directly sets a field value on an entity instance using reflection.
         * The field is made accessible before setting the value.
         * 
         * @param entity the entity to set the field on
         * @param fieldName the name of the field to set
         * @param value the value to set
         * @throws Exception if the field cannot be found or set
         */
        private void setFieldValue(Object entity, String fieldName, Object value) throws Exception {
            Field field = entity.getClass().getDeclaredField(fieldName);
            field.setAccessible(true);
            field.set(entity, value);
        }
        
        /**
         * Checks if entity contains the search query in any of its string fields.
         * 
         * <p>Performs case-insensitive search across all fields of an entity.
         * Only considers fields that can be converted to strings.
         * 
         * @param entity the entity to search in
         * @param query the search query (should be lowercase)
         * @return true if any field contains the query, false otherwise
         */
        private boolean entityContainsQuery(Object entity, String query) {
            try {
                Field[] fields = entity.getClass().getDeclaredFields();
                for (Field field : fields) {
                    field.setAccessible(true);
                    Object value = field.get(entity);
                    if (value != null && value.toString().toLowerCase().contains(query)) {
                        return true;
                    }
                }
            } catch (Exception e) {
                // Silently continue on reflection errors
            }
            return false;
        }
    }
} 