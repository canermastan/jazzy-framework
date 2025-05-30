package jazzyframework.security.validation;

import jazzyframework.security.annotations.LoginMethod;
import java.lang.reflect.Field;
import java.lang.reflect.Method;
import java.util.ArrayList;
import java.util.List;

/**
 * Validates user entity class for Jazzy Authentication requirements
 */
public class UserEntityValidator {
    
    public static void validateUserClass(Class<?> userClass, LoginMethod loginMethod) {
        List<String> errors = new ArrayList<>();
        
        // Check if class exists and is accessible
        if (userClass == null) {
            throw new IllegalArgumentException("User class cannot be null");
        }
        
        // Check for required fields based on login method
        if (loginMethod == LoginMethod.EMAIL || loginMethod == LoginMethod.BOTH) {
            if (!hasFieldOrGetter(userClass, "email")) {
                errors.add("Email field or getEmail() method is required for EMAIL login method");
            }
        }
        
        if (loginMethod == LoginMethod.USERNAME || loginMethod == LoginMethod.BOTH) {
            if (!hasFieldOrGetter(userClass, "username")) {
                errors.add("Username field or getUsername() method is required for USERNAME login method");
            }
        }
        
        // Password is always required
        if (!hasFieldOrGetter(userClass, "password") && !hasFieldOrGetter(userClass, "passwordHash")) {
            errors.add("Password field (password or passwordHash) or getPassword()/getPasswordHash() method is required");
        }
        
        // Check for ID field (required for entity)
        if (!hasFieldOrGetter(userClass, "id")) {
            errors.add("ID field or getId() method is required for user entity");
        }
        
        if (!errors.isEmpty()) {
            throw new IllegalArgumentException("User class validation failed:\n" + String.join("\n", errors));
        }
    }
    
    private static boolean hasFieldOrGetter(Class<?> clazz, String fieldName) {
        // Check for field
        if (hasField(clazz, fieldName)) {
            return true;
        }
        
        // Check for getter method
        String getterName = "get" + capitalize(fieldName);
        try {
            clazz.getMethod(getterName);
            return true;
        } catch (NoSuchMethodException e) {
            // Try boolean getter for password fields
            if (fieldName.startsWith("password")) {
                return false; // Password should not be boolean
            }
            return false;
        }
    }
    
    private static boolean hasField(Class<?> clazz, String fieldName) {
        try {
            Field field = clazz.getDeclaredField(fieldName);
            return true;
        } catch (NoSuchFieldException e) {
            // Try parent classes
            Class<?> superClass = clazz.getSuperclass();
            if (superClass != null && superClass != Object.class) {
                return hasField(superClass, fieldName);
            }
            return false;
        }
    }
    
    private static String capitalize(String str) {
        if (str == null || str.isEmpty()) {
            return str;
        }
        return str.substring(0, 1).toUpperCase() + str.substring(1);
    }
    
    /**
     * Get the appropriate field value from user object based on login method
     */
    public static String getLoginField(Object user, LoginMethod loginMethod, String loginInput) {
        if (loginMethod == LoginMethod.EMAIL) {
            return getFieldValue(user, "email");
        } else if (loginMethod == LoginMethod.USERNAME) {
            return getFieldValue(user, "username");
        } else if (loginMethod == LoginMethod.BOTH) {
            // Try to determine if input is email or username
            if (loginInput.contains("@")) {
                return getFieldValue(user, "email");
            } else {
                return getFieldValue(user, "username");
            }
        }
        return null;
    }
    
    public static String getFieldValue(Object object, String fieldName) {
        try {
            // Try getter method first
            String getterName = "get" + capitalize(fieldName);
            Method getter = object.getClass().getMethod(getterName);
            Object value = getter.invoke(object);
            return value != null ? value.toString() : null;
        } catch (Exception e) {
            // Try direct field access
            try {
                Field field = object.getClass().getDeclaredField(fieldName);
                field.setAccessible(true);
                Object value = field.get(object);
                return value != null ? value.toString() : null;
            } catch (Exception ex) {
                return null;
            }
        }
    }
    
    public static void setFieldValue(Object object, String fieldName, Object value) {
        try {
            // Try setter method first
            String setterName = "set" + capitalize(fieldName);
            Method[] methods = object.getClass().getMethods();
            for (Method method : methods) {
                if (method.getName().equals(setterName) && method.getParameterCount() == 1) {
                    method.invoke(object, value);
                    return;
                }
            }
            
            // Try direct field access
            Field field = object.getClass().getDeclaredField(fieldName);
            field.setAccessible(true);
            field.set(object, value);
        } catch (Exception e) {
            throw new RuntimeException("Failed to set field value: " + fieldName, e);
        }
    }
} 