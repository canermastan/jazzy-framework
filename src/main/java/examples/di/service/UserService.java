package examples.di.service;

import examples.di.entity.User;
import examples.di.repository.UserRepository;
import jazzyframework.di.annotations.Component;

import java.util.List;

/**
 * Example service for User entity demonstrating dependency injection.
 * This service depends on UserRepository which will be injected via constructor.
 */
@Component
public class UserService {
    
    private final UserRepository userRepository;
    
    // Constructor injection - PicoContainer will automatically inject UserRepository
    public UserService(UserRepository userRepository) {
        this.userRepository = userRepository;
    }
    
    public User getUserById(String id) {
        User user = userRepository.findById(id);
        if (user == null) {
            throw new RuntimeException("User not found with id: " + id);
        }
        return user;
    }
    
    public List<User> getAllUsers() {
        return userRepository.findAll();
    }
    
    public User createUser(User user) {
        // Generate a new ID if not provided
        if (user.getId() == null || user.getId().isEmpty()) {
            user.setId(String.valueOf(System.currentTimeMillis()));
        }
        
        return userRepository.saveUser(user);
    }
    
    public User updateUser(String id, User updatedUser) {
        if (!userRepository.existsById(id)) {
            throw new RuntimeException("User not found with id: " + id);
        }
        
        updatedUser.setId(id);
        return userRepository.saveUser(updatedUser);
    }
    
    public void deleteUser(String id) {
        if (!userRepository.existsById(id)) {
            throw new RuntimeException("User not found with id: " + id);
        }
        
        userRepository.deleteUser(id);
    }
    
    public long getUserCount() {
        return userRepository.count();
    }
} 