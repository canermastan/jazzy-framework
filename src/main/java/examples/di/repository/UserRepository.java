package examples.di.repository;

import examples.di.entity.User;
import jazzyframework.di.annotations.Component;

import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

/**
 * Example repository for User entity demonstrating dependency injection.
 */
@Component
public class UserRepository {
    
    private final Map<String, User> users = new HashMap<>();
    
    public UserRepository() {
        // Initialize with some sample data
        saveUser(new User("1", "John Doe", "john@example.com", 30));
        saveUser(new User("2", "Jane Smith", "jane@example.com", 28));
        saveUser(new User("3", "Bob Johnson", "bob@example.com", 35));
    }
    
    public User findById(String id) {
        return users.get(id);
    }
    
    public List<User> findAll() {
        return users.values().stream().collect(Collectors.toList());
    }
    
    public User saveUser(User user) {
        users.put(user.getId(), user);
        return user;
    }
    
    public boolean deleteUser(String id) {
        return users.remove(id) != null;
    }
    
    public boolean existsById(String id) {
        return users.containsKey(id);
    }
    
    public long count() {
        return users.size();
    }
} 