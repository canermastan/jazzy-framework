package examples.auth_example;

import jazzyframework.data.BaseRepository;

/**
 * User repository interface for authentication example
 */
public interface UserRepository extends BaseRepository<User, Long> {
    
    // Additional custom query methods can be added here if needed
    // For example:
    // Optional<User> findByEmail(String email);
    // Optional<User> findByUsername(String username);
} 