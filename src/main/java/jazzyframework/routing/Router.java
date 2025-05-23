package jazzyframework.routing;

import jazzyframework.di.DIContainer;

import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Set;

/**
 * Manages HTTP routes in the Jazzy Framework.
 * 
 * <p>This class is responsible for:
 * <ul>
 *   <li>Registering routes with HTTP methods and controller methods</li>
 *   <li>Finding the appropriate route for incoming requests</li>
 *   <li>Extracting path parameters from URLs</li>
 *   <li>Integrating with dependency injection for controller instantiation</li>
 * </ul>
 * 
 * <p>The router supports all standard HTTP methods (GET, POST, PUT, DELETE, PATCH)
 * and provides path parameter extraction for dynamic routes like {@code /user/{id}}.
 * 
 * @since 0.1
 * @author Caner Mastan
 */
public class Router {
    private final Map<String, Route> routes = new HashMap<>();
    private static final Set<String> ALLOWED_METHODS = Set.of("GET", "POST", "PUT", "DELETE", "PATCH");
    private DIContainer diContainer;

    /**
     * Creates a new Router instance.
     */
    public Router() {
    }

    /**
     * Creates a new Router instance with dependency injection support.
     * 
     * @param diContainer the DI container to use for creating controller instances
     */
    public Router(DIContainer diContainer) {
        this.diContainer = diContainer;
    }

    /**
     * Sets the DI container for this router.
     * 
     * @param diContainer the DI container
     */
    public void setDIContainer(DIContainer diContainer) {
        this.diContainer = diContainer;
    }

    /**
     * Gets the DI container used by this router.
     * 
     * @return the DI container, or null if not set
     */
    public DIContainer getDIContainer() {
        return diContainer;
    }

    /**
     * Registers a new GET route.
     * 
     * @param path The URL path pattern (can include path parameters like {id})
     * @param methodName The name of the controller method to invoke
     * @param controllerClass The controller class containing the method
     */
    public void GET(String path, String methodName, Class<?> controllerClass) {
        routes.put("GET:" + path, new Route("GET", path, methodName, controllerClass));
    }

    /**
     * Registers a new POST route.
     * 
     * @param path The URL path pattern (can include path parameters like {id})
     * @param methodName The name of the controller method to invoke
     * @param controllerClass The controller class containing the method
     */
    public void POST(String path, String methodName, Class<?> controllerClass) {
        routes.put("POST:" + path, new Route("POST", path, methodName, controllerClass));
    }

    /**
     * Registers a new PUT route.
     * 
     * @param path The URL path pattern (can include path parameters like {id})
     * @param methodName The name of the controller method to invoke
     * @param controllerClass The controller class containing the method
     */
    public void PUT(String path, String methodName, Class<?> controllerClass) {
        routes.put("PUT:" + path, new Route("PUT", path, methodName, controllerClass));
    }

    /**
     * Registers a new DELETE route.
     * 
     * @param path The URL path pattern (can include path parameters like {id})
     * @param methodName The name of the controller method to invoke
     * @param controllerClass The controller class containing the method
     */
    public void DELETE(String path, String methodName, Class<?> controllerClass) {
        routes.put("DELETE:" + path, new Route("DELETE", path, methodName, controllerClass));
    }

    /**
     * Registers a new route with the specified HTTP method.
     * 
     * @param method The HTTP method (GET, POST, PUT, DELETE, PATCH)
     * @param path The URL path pattern (can include path parameters like {id})
     * @param methodName The name of the controller method to invoke
     * @param controllerClass The controller class containing the method
     * @throws IllegalArgumentException if the HTTP method is not supported
     */
    public void addRoute(String method, String path, String methodName, Class<?> controllerClass) {
        method = method.toUpperCase();
        if (!isSupportedMethod(method)) {
            throw new IllegalArgumentException("Unsupported HTTP method: " + method);
        }
        routes.put(method + ":" + path, new Route(method, path, methodName, controllerClass));
    }

    /**
     * Finds a route that matches the specified HTTP method and path.
     * 
     * @param method The HTTP method of the request
     * @param path The URL path of the request
     * @return The matching Route, or null if no route matches
     */
    public Route findRoute(String method, String path) {
        for (Route route : routes.values()) {
            if (!route.getMethod().equalsIgnoreCase(method)) continue;
            
            String pattern = route.getPath().replaceAll("\\{[^/]+}", "([^/]+)");
            if (path.matches(pattern)) {
                return route;
            }
        }
        return null;
    }

    /**
     * Extracts path parameters from the URL path based on the route pattern.
     * For example, if the route pattern is "/user/{id}" and the actual path is "/user/123",
     * this method will return a map with "id" -> "123".
     * 
     * @param routePath The route pattern (can include path parameters like {id})
     * @param actualPath The actual URL path of the request
     * @return A map of parameter names to parameter values
     */
    public Map<String, String> extractPathParams(String routePath, String actualPath) {
        Map<String, String> params = new LinkedHashMap<>();

        String[] routeParts = routePath.split("/");
        String[] pathParts = actualPath.split("/");

        for (int i = 0; i < routeParts.length; i++) {
            if (routeParts[i].startsWith("{") && routeParts[i].endsWith("}")) {
                String paramName = routeParts[i].substring(1, routeParts[i].length() - 1);
                params.put(paramName, pathParts[i]);
            }
        }
        return params;
    }

    /**
     * Checks if the specified HTTP method is supported by the router.
     * 
     * @param method The HTTP method to check
     * @return true if the method is supported, false otherwise
     */
    public boolean isSupportedMethod(String method) {
        return ALLOWED_METHODS.contains(method.toUpperCase());
    }
}
