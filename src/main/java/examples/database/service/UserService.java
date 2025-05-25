package examples.database.service;

import examples.database.entity.User;
import examples.database.repository.UserRepository;
import jazzyframework.di.annotations.Component;

import java.util.List;
import java.util.Optional;
import java.util.logging.Logger;

/**
 * Service layer for User operations.
 * 
 * <p>This service demonstrates:
 * <ul>
 *   <li>Dependency injection with automatically generated repository</li>
 *   <li>Business logic separation from controller layer</li>
 *   <li>Transaction management through repository layer</li>
 *   <li>Data validation and processing</li>
 * </ul>
 * 
 * @since 0.3.0
 * @author Caner Mastan
 */
@Component
public class UserService {
    private static final Logger logger = Logger.getLogger(UserService.class.getName());
    
    private final UserRepository userRepository;

    /**
     * Creates a new UserService.
     * UserRepository will be automatically injected by the DI container.
     * 
     * @param userRepository the user repository
     */
    public UserService(UserRepository userRepository) {
        this.userRepository = userRepository;
        logger.info("UserService created with injected UserRepository");
    }

    /**
     * Creates a new user.
     * 
     * @param name the user's name
     * @param email the user's email
     * @param password the user's password
     * @return the created user
     * @throws IllegalArgumentException if email already exists
     */
    public User createUser(String name, String email, String password) {
        logger.info("Creating user with email: " + email);
        
        // Check if email already exists
        Optional<User> existingUser = userRepository.findByEmail(email);
        if (existingUser.isPresent()) {
            throw new IllegalArgumentException("User with email " + email + " already exists");
        }
        
        // Create and save the user
        User user = new User(name, email, password);
        User savedUser = userRepository.save(user);
        
        logger.info("User created successfully with ID: " + savedUser.getId());
        return savedUser;
    }

    /**
     * Creates a new user with age.
     * 
     * @param name the user's name
     * @param email the user's email
     * @param password the user's password
     * @param age the user's age
     * @return the created user
     * @throws IllegalArgumentException if email already exists or age is invalid
     */
    public User createUser(String name, String email, String password, Integer age) {
        if (age != null && (age < 0 || age > 150)) {
            throw new IllegalArgumentException("Age must be between 0 and 150");
        }
        
        logger.info("Creating user with email: " + email + " and age: " + age);
        
        // Check if email already exists
        Optional<User> existingUser = userRepository.findByEmail(email);
        if (existingUser.isPresent()) {
            throw new IllegalArgumentException("User with email " + email + " already exists");
        }
        
        // Create and save the user
        User user = new User(name, email, password, age);
        User savedUser = userRepository.save(user);
        
        logger.info("User created successfully with ID: " + savedUser.getId());
        return savedUser;
    }

    /**
     * Finds a user by ID.
     * 
     * @param id the user ID
     * @return Optional containing the user if found
     */
    public Optional<User> findById(Long id) {
        logger.fine("Finding user by ID: " + id);
        return userRepository.findById(id);
    }

    /**
     * Finds a user by email.
     * 
     * @param email the email address
     * @return Optional containing the user if found
     */
    public Optional<User> findByEmail(String email) {
        logger.fine("Finding user by email: " + email);
        return userRepository.findByEmail(email);
    }

    /**
     * Finds all users.
     * 
     * @return List of all users
     */
    public List<User> findAllUsers() {
        logger.fine("Finding all users");
        return userRepository.findAll();
    }

    /**
     * Updates a user.
     * 
     * @param id the user ID
     * @param name the new name
     * @param email the new email
     * @param age the new age
     * @return Optional containing the updated user if found
     * @throws IllegalArgumentException if email already exists for another user
     */
    public Optional<User> updateUser(Long id, String name, String email, Integer age) {
        logger.info("Updating user with ID: " + id);
        
        Optional<User> userOpt = userRepository.findById(id);
        if (userOpt.isEmpty()) {
            logger.warning("User not found with ID: " + id);
            return Optional.empty();
        }
        
        User user = userOpt.get();
        
        // Check if email is being changed and if new email already exists
        if (!user.getEmail().equals(email)) {
            Optional<User> existingUser = userRepository.findByEmail(email);
            if (existingUser.isPresent() && !existingUser.get().getId().equals(id)) {
                throw new IllegalArgumentException("Email " + email + " is already in use by another user");
            }
        }
        
        // Validate age if provided
        if (age != null && (age < 0 || age > 150)) {
            throw new IllegalArgumentException("Age must be between 0 and 150");
        }
        
        // Update user fields
        user.setName(name);
        user.setEmail(email);
        user.setAge(age);
        
        User updatedUser = userRepository.save(user);
        logger.info("User updated successfully with ID: " + updatedUser.getId());
        
        return Optional.of(updatedUser);
    }

    /**
     * Deactivates a user (sets active to false).
     * 
     * @param id the user ID
     * @return true if user was deactivated, false if not found
     */
    public boolean deactivateUser(Long id) {
        logger.info("Deactivating user with ID: " + id);
        
        Optional<User> userOpt = userRepository.findById(id);
        if (userOpt.isEmpty()) {
            logger.warning("User not found with ID: " + id);
            return false;
        }
        
        User user = userOpt.get();
        user.setActive(false);
        userRepository.save(user);
        
        logger.info("User deactivated successfully with ID: " + id);
        return true;
    }

    /**
     * Permanently deletes a user.
     * 
     * @param id the user ID
     * @return true if user was deleted, false if not found
     */
    public boolean deleteUser(Long id) {
        logger.info("Deleting user with ID: " + id);
        
        if (!userRepository.existsById(id)) {
            logger.warning("User not found with ID: " + id);
            return false;
        }
        
        userRepository.deleteById(id);
        logger.info("User deleted successfully with ID: " + id);
        return true;
    }

    /**
     * Gets the total number of users.
     * 
     * @return the user count
     */
    public long getUserCount() {
        return userRepository.count();
    }

    /**
     * Checks if a user exists by email.
     * 
     * @param email the email address
     * @return true if user exists with the given email
     */
    public boolean existsByEmail(String email) {
        return userRepository.findByEmail(email).isPresent();
    }
} 