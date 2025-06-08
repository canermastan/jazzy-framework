package jazzyframework.guard;

import java.util.Collection;

/**
 * A utility class providing static methods for performing common validation checks.
 * This class follows the guard clause pattern and throws {@link ValidationException}
 * when validation fails.
 * 
 * <p>All methods return the validated value, allowing for fluent usage in assignments
 * and method chaining scenarios.</p>
 * 
 * <p>Example usage:</p>
 * <pre>{@code
 * String username = Ensure.notBlank(user.getUsername(), "Username cannot be blank");
 * List<Item> items = Ensure.notEmpty(itemList, "Item list cannot be empty");
 * int age = Ensure.inRange(user.getAge(), 0, 150, "Age must be between 0 and 150");
 * }</pre>
 * 
 */
public final class Ensure {
    /**
     * Private constructor to prevent instantiation of this utility class.
     */
    private Ensure() {
        
    }

    /**
     * Ensures that the specified object is not null.
     * 
     * @param <T> the type of the object to check
     * @param obj the object to check for null
     * @param message the detail message for the exception if validation fails
     * @return the validated object (guaranteed to be non-null)
     * @throws ValidationException if the object is null
     */
    public static <T> T notNull(T obj, String message) {
        if (obj == null) {
            throw new ValidationException(message);
        }
        return obj;
    }

    /**
     * Ensures that the specified string is not null and not blank.
     * A string is considered blank if it consists only of whitespace characters.
     * 
     * @param str the string to check
     * @param message the detail message for the exception if validation fails
     * @return the validated string (guaranteed to be non-null and non-blank)
     * @throws ValidationException if the string is null or blank
     */
    public static String notBlank(String str, String message) {
        if (str == null || str.isBlank()) {
            throw new ValidationException(message);
        }
        return str;
    }

    /**
     * Ensures that the specified collection is not null and not empty.
     * 
     * @param <T> the type of the collection
     * @param collection the collection to check
     * @param message the detail message for the exception if validation fails
     * @return the validated collection (guaranteed to be non-null and non-empty)
     * @throws ValidationException if the collection is null or empty
     */
    public static <T extends Collection<?>> T notEmpty(T collection, String message) {
        if (collection == null || collection.isEmpty()) {
            throw new ValidationException(message);
        }
        return collection;
    }

    /**
     * Ensures that the specified array is not null and not empty.
     * 
     * @param <T> the component type of the array
     * @param array the array to check
     * @param message the detail message for the exception if validation fails
     * @return the validated array (guaranteed to be non-null and non-empty)
     * @throws ValidationException if the array is null or has zero length
     */
    public static <T> T[] notEmpty(T[] array, String message) {
        if (array == null || array.length == 0) {
            throw new ValidationException(message);
        }
        return array;
    }

    /**
     * Ensures that the specified integer value is within the given range (inclusive).
     * 
     * @param value the value to check
     * @param min the minimum allowed value (inclusive)
     * @param max the maximum allowed value (inclusive)
     * @param message the detail message for the exception if validation fails
     * @return the validated value (guaranteed to be within the specified range)
     * @throws ValidationException if the value is outside the specified range
     */
    public static int inRange(int value, int min, int max, String message) {
        if (value < min || value > max) {
            throw new ValidationException(message);
        }
        return value;
    }

    /**
     * Ensures that the specified integer value is not negative (greater than or equal to zero).
     * 
     * @param value the value to check
     * @param message the detail message for the exception if validation fails
     * @return the validated value (guaranteed to be non-negative)
     * @throws ValidationException if the value is negative
     */
    public static int notNegative(int value, String message) {
        if (value < 0) {
            throw new ValidationException(message);
        }
        return value;
    }
}
