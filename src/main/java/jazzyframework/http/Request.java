/**
 * Represents an HTTP request in the Jazzy framework.
 * Provides convenient access to request parameters, headers, path, query, and body.
 */
package jazzyframework.http;

import java.util.Collections;
import java.util.HashMap;
import java.util.Map;

import jazzyframework.http.validation.ValidationResult;
import jazzyframework.http.validation.ValidationRules;
import jazzyframework.http.validation.Validator;

public class Request {
    private final String method;
    private final String path;
    private final Map<String, String> headers;
    private final Map<String, String> pathParams;
    private final Map<String, String> queryParams;
    private final String body;
    
    /**
     * Creates a new Request object.
     * 
     * @param method The HTTP method (GET, POST, etc.)
     * @param path The request path
     * @param headers The request headers
     * @param pathParams The path parameters
     * @param queryParams The query parameters
     * @param body The request body
     */
    public Request(String method, String path, Map<String, String> headers, 
                  Map<String, String> pathParams, Map<String, String> queryParams, String body) {
        this.method = method;
        this.path = path;
        this.headers = headers != null ? new HashMap<>(headers) : new HashMap<>();
        this.pathParams = pathParams != null ? new HashMap<>(pathParams) : new HashMap<>();
        this.queryParams = queryParams != null ? new HashMap<>(queryParams) : new HashMap<>();
        this.body = body;
    }
    
    /**
     * Gets the HTTP method.
     * 
     * @return The HTTP method
     */
    public String getMethod() {
        return method;
    }
    
    /**
     * Gets the request path.
     * 
     * @return The request path
     */
    public String getPath() {
        return path;
    }
    
    /**
     * Gets a request header.
     * 
     * @param name The header name
     * @return The header value, or null if not found
     */
    public String header(String name) {
        return headers.get(name.toLowerCase());
    }
    
    /**
     * Gets a request header with a default value.
     * 
     * @param name The header name
     * @param defaultValue The default value to return if the header is not found
     * @return The header value, or the default value if not found
     */
    public String header(String name, String defaultValue) {
        return headers.getOrDefault(name.toLowerCase(), defaultValue);
    }
    
    /**
     * Gets all request headers.
     * 
     * @return An unmodifiable map of all headers
     */
    public Map<String, String> getHeaders() {
        return Collections.unmodifiableMap(headers);
    }
    
    /**
     * Gets a path parameter.
     * 
     * @param name The parameter name
     * @return The parameter value, or null if not found
     */
    public String path(String name) {
        return pathParams.get(name);
    }
    
    /**
     * Gets all path parameters.
     * 
     * @return An unmodifiable map of all path parameters
     */
    public Map<String, String> getPathParams() {
        return Collections.unmodifiableMap(pathParams);
    }
    
    /**
     * Gets a query parameter.
     * 
     * @param name The parameter name
     * @return The parameter value, or null if not found
     */
    public String query(String name) {
        return queryParams.get(name);
    }
    
    /**
     * Gets a query parameter with a default value.
     * 
     * @param name The parameter name
     * @param defaultValue The default value to return if the parameter is not found
     * @return The parameter value, or the default value if not found
     */
    public String query(String name, String defaultValue) {
        return queryParams.getOrDefault(name, defaultValue);
    }
    
    /**
     * Gets a query parameter as an integer.
     * 
     * @param name The parameter name
     * @param defaultValue The default value to return if the parameter is not found or invalid
     * @return The parameter value as an integer, or the default value
     */
    public int queryInt(String name, int defaultValue) {
        String value = queryParams.get(name);
        if (value == null) {
            return defaultValue;
        }
        try {
            return Integer.parseInt(value);
        } catch (NumberFormatException e) {
            return defaultValue;
        }
    }
    
    /**
     * Gets a query parameter as a boolean.
     * 
     * @param name The parameter name
     * @param defaultValue The default value to return if the parameter is not found
     * @return The parameter value as a boolean, or the default value
     */
    public boolean queryBoolean(String name, boolean defaultValue) {
        String value = queryParams.get(name);
        if (value == null) {
            return defaultValue;
        }
        return Boolean.parseBoolean(value);
    }
    
    /**
     * Gets all query parameters.
     * 
     * @return An unmodifiable map of all query parameters
     */
    public Map<String, String> getQueryParams() {
        return Collections.unmodifiableMap(queryParams);
    }
    
    /**
     * Gets the request body as a string.
     * 
     * @return The request body
     */
    public String getBody() {
        return body;
    }
    
    /**
     * Parses the request body as JSON and returns it as a Map.
     * 
     * @return The parsed JSON as a Map, or an empty Map if the body is empty or not valid JSON
     */
    public Map<String, Object> parseJson() {
        if (body == null || body.isEmpty()) {
            return Collections.emptyMap();
        }
        
        try {
            return JsonParser.parseMap(body);
        } catch (Exception e) {
            throw new IllegalArgumentException("Invalid JSON body: " + e.getMessage());
        }
    }
    
    /**
     * Parses the request body as JSON and returns it as a Map.
     * This is an alias for parseJson() method.
     * 
     * @return The parsed JSON as a Map, or an empty Map if the body is empty or not valid JSON
     */
    public Map<String, Object> json() {
        return parseJson();
    }
    
    /**
     * Parses the request body as JSON and returns it as an object of the specified class.
     * 
     * @param <T> The type to convert to
     * @param clazz The class of the target object
     * @return The parsed JSON as an object
     */
    public <T> T toObject(Class<T> clazz) {
        if (body == null || body.isEmpty()) {
            throw new IllegalArgumentException("Request body is empty");
        }
        
        try {
            return JsonParser.parse(body, clazz);
        } catch (Exception e) {
            throw new IllegalArgumentException("Invalid JSON body: " + e.getMessage());
        }
    }
    
    /**
     * Creates a validator for this request.
     * 
     * @return A new validator
     */
    public Validator validator() {
        return new Validator(this);
    }
    
    /**
     * Creates a validator for this request.
     * 
     * @return A new validator
     */
    public Validator validate() {
        return new Validator(this);
    }
    
    /**
     * Validates this request using the specified validation rules.
     * 
     * @param rules The validation rules to apply
     * @return The validation result
     */
    public ValidationResult validate(ValidationRules rules) {
        Validator validator = validator();
        rules.setValidator(validator);
        return rules.validate();
    }
    
    /**
     * Validates this request and throws an exception if validation fails.
     * 
     * @param rules The validation rules to apply
     * @throws IllegalArgumentException if validation fails
     */
    public void validateOrFail(ValidationRules rules) {
        ValidationResult result = validate(rules);
        if (!result.isValid()) {
            throw new IllegalArgumentException("Validation failed: " + result.getFirstErrors());
        }
    }
} 