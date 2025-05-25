package jazzyframework.data;

import java.lang.reflect.Method;
import java.lang.reflect.ParameterizedType;
import java.lang.reflect.Type;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Parses repository method names and generates corresponding HQL queries.
 * 
 * <p>This class implements Spring Data JPA-like method name parsing to automatically
 * generate queries from method names. Supported patterns include:
 * 
 * <ul>
 *   <li>findBy* - SELECT queries</li>
 *   <li>countBy* - COUNT queries</li>
 *   <li>existsBy* - EXISTS queries</li>
 *   <li>deleteBy* - DELETE queries</li>
 * </ul>
 * 
 * <p>Supported keywords:
 * <ul>
 *   <li>And, Or - logical operators</li>
 *   <li>GreaterThan, LessThan, GreaterThanEqual, LessThanEqual - comparison</li>
 *   <li>Like, NotLike, Containing, StartingWith, EndingWith - string matching</li>
 *   <li>IsNull, IsNotNull - null checks</li>
 *   <li>In, NotIn - collection membership</li>
 *   <li>True, False - boolean values</li>
 * </ul>
 * 
 * @since 0.3.0
 * @author Caner Mastan
 */
public class QueryMethodParser {
    
    private static final Pattern METHOD_PATTERN = Pattern.compile(
        "^(find|count|exists|delete)By(.+)$"
    );
    
    private static final String[] KEYWORDS = {
        "And", "Or", "GreaterThan", "LessThan", "GreaterThanEqual", "LessThanEqual",
        "Like", "NotLike", "Containing", "StartingWith", "EndingWith",
        "IsNull", "IsNotNull", "In", "NotIn", "True", "False", "Between"
    };
    
    /**
     * Checks if a method name can be parsed into a query.
     * 
     * @param methodName the method name to check
     * @return true if the method name follows a parseable pattern
     */
    public boolean canParseMethodName(String methodName) {
        return METHOD_PATTERN.matcher(methodName).matches();
    }
    
    /**
     * Parses a method and generates the corresponding HQL query.
     * 
     * @param method the method to parse
     * @param entityClass the entity class for the repository
     * @return the generated query information
     */
    public QueryInfo parseMethod(Method method, Class<?> entityClass) {
        String methodName = method.getName();
        Matcher matcher = METHOD_PATTERN.matcher(methodName);
        
        if (!matcher.matches()) {
            throw new IllegalArgumentException("Cannot parse method name: " + methodName);
        }
        
        String operation = matcher.group(1);
        String criteria = matcher.group(2);
        
        String entityName = entityClass.getSimpleName();
        String alias = entityName.toLowerCase().charAt(0) + "";
        
        QueryInfo queryInfo = new QueryInfo();
        queryInfo.setEntityClass(entityClass);
        queryInfo.setOperation(operation);
        
        // Parse criteria and build query
        List<String> conditions = new ArrayList<>();
        List<String> parameterNames = new ArrayList<>();
        
        parseCriteria(criteria, conditions, parameterNames, alias);
        
        // Build the query based on operation
        String query = buildQuery(operation, entityName, alias, conditions);
        queryInfo.setQuery(query);
        queryInfo.setParameterNames(parameterNames);
        
        // Determine return type
        Class<?> returnType = method.getReturnType();
        if (returnType == Optional.class) {
            Type genericType = ((ParameterizedType) method.getGenericReturnType()).getActualTypeArguments()[0];
            queryInfo.setReturnType((Class<?>) genericType);
            queryInfo.setOptionalReturn(true);
        } else {
            queryInfo.setReturnType(returnType);
        }
        
        return queryInfo;
    }
    
    /**
     * Parses the criteria part of the method name.
     */
    private void parseCriteria(String criteria, List<String> conditions, List<String> parameterNames, String alias) {
        String remaining = criteria;
        
        while (!remaining.isEmpty()) {
            boolean found = false;
            
            // Try to match keywords
            for (String keyword : KEYWORDS) {
                if (remaining.startsWith(keyword)) {
                    String beforeKeyword = remaining.substring(0, remaining.indexOf(keyword));
                    if (!beforeKeyword.isEmpty()) {
                        String fieldName = camelToSnake(beforeKeyword);
                        String condition = buildCondition(fieldName, keyword, alias, parameterNames);
                        conditions.add(condition);
                    }
                    remaining = remaining.substring(keyword.length());
                    found = true;
                    break;
                }
            }
            
            if (!found) {
                // No keyword found, treat as simple field equality
                String fieldName = camelToSnake(remaining);
                String paramName = fieldName.replace(".", "_");
                conditions.add(alias + "." + fieldName + " = :" + paramName);
                parameterNames.add(paramName);
                break;
            }
        }
    }
    
    /**
     * Builds a condition based on the field name and keyword.
     */
    private String buildCondition(String fieldName, String keyword, String alias, List<String> parameterNames) {
        String paramName = fieldName.replace(".", "_");
        String field = alias + "." + fieldName;
        
        switch (keyword) {
            case "GreaterThan":
                parameterNames.add(paramName);
                return field + " > :" + paramName;
            case "LessThan":
                parameterNames.add(paramName);
                return field + " < :" + paramName;
            case "GreaterThanEqual":
                parameterNames.add(paramName);
                return field + " >= :" + paramName;
            case "LessThanEqual":
                parameterNames.add(paramName);
                return field + " <= :" + paramName;
            case "Like":
                parameterNames.add(paramName);
                return field + " LIKE :" + paramName;
            case "NotLike":
                parameterNames.add(paramName);
                return field + " NOT LIKE :" + paramName;
            case "Containing":
                parameterNames.add(paramName);
                return "LOWER(" + field + ") LIKE LOWER(:" + paramName + ")";
            case "StartingWith":
                parameterNames.add(paramName);
                return "LOWER(" + field + ") LIKE LOWER(:" + paramName + ")";
            case "EndingWith":
                parameterNames.add(paramName);
                return "LOWER(" + field + ") LIKE LOWER(:" + paramName + ")";
            case "IsNull":
                return field + " IS NULL";
            case "IsNotNull":
                return field + " IS NOT NULL";
            case "In":
                parameterNames.add(paramName);
                return field + " IN (:" + paramName + ")";
            case "NotIn":
                parameterNames.add(paramName);
                return field + " NOT IN (:" + paramName + ")";
            case "True":
                return field + " = true";
            case "False":
                return field + " = false";
            case "Between":
                parameterNames.add(paramName + "Start");
                parameterNames.add(paramName + "End");
                return field + " BETWEEN :" + paramName + "Start AND :" + paramName + "End";
            default:
                parameterNames.add(paramName);
                return field + " = :" + paramName;
        }
    }
    
    /**
     * Builds the complete query based on operation and conditions.
     */
    private String buildQuery(String operation, String entityName, String alias, List<String> conditions) {
        String whereClause = conditions.isEmpty() ? "" : " WHERE " + String.join(" AND ", conditions);
        
        switch (operation) {
            case "find":
                return "SELECT " + alias + " FROM " + entityName + " " + alias + whereClause;
            case "count":
                return "SELECT COUNT(" + alias + ") FROM " + entityName + " " + alias + whereClause;
            case "exists":
                return "SELECT COUNT(" + alias + ") FROM " + entityName + " " + alias + whereClause;
            case "delete":
                return "DELETE FROM " + entityName + " " + alias + whereClause;
            default:
                throw new IllegalArgumentException("Unsupported operation: " + operation);
        }
    }
    
    /**
     * Converts camelCase to snake_case for field names.
     */
    private String camelToSnake(String camelCase) {
        return camelCase.replaceAll("([a-z])([A-Z])", "$1_$2").toLowerCase();
    }
    
    /**
     * Information about a parsed query method.
     */
    public static class QueryInfo {
        private String query;
        private List<String> parameterNames = new ArrayList<>();
        private Class<?> returnType;
        private Class<?> entityClass;
        private String operation;
        private boolean optionalReturn = false;
        
        // Getters and setters
        public String getQuery() { return query; }
        public void setQuery(String query) { this.query = query; }
        
        public List<String> getParameterNames() { return parameterNames; }
        public void setParameterNames(List<String> parameterNames) { this.parameterNames = parameterNames; }
        
        public Class<?> getReturnType() { return returnType; }
        public void setReturnType(Class<?> returnType) { this.returnType = returnType; }
        
        public Class<?> getEntityClass() { return entityClass; }
        public void setEntityClass(Class<?> entityClass) { this.entityClass = entityClass; }
        
        public String getOperation() { return operation; }
        public void setOperation(String operation) { this.operation = operation; }
        
        public boolean isOptionalReturn() { return optionalReturn; }
        public void setOptionalReturn(boolean optionalReturn) { this.optionalReturn = optionalReturn; }
    }
} 