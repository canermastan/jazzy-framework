package examples.database.repository;

import examples.database.entity.User;
import jazzyframework.data.BaseRepository;

import java.util.List;
import java.util.Optional;

/**
 * Repository interface for User entity operations.
 * 
 * <p>This interface demonstrates how to create repository interfaces
 * that automatically get implementation through the framework's
 * repository system. Simply extend BaseRepository and the framework
 * will provide all CRUD operations automatically.
 * 
 * <p>You can add custom query methods here if needed:
 * <ul>
 *   <li>findByEmail - find user by email address</li>
 *   <li>findByActiveTrue - find all active users</li>
 *   <li>findByAgeBetween - find users within age range</li>
 * </ul>
 * 
 * <p>Usage example:
 * <pre>
 * &#64;Component
 * public class UserService {
 *     private final UserRepository userRepository;
 *     
 *     public UserService(UserRepository userRepository) {
 *         this.userRepository = userRepository;
 *     }
 *     
 *     public User createUser(String name, String email, String password) {
 *         User user = new User(name, email, password);
 *         return userRepository.save(user);
 *     }
 *     
 *     public Optional&lt;User&gt; findByEmail(String email) {
 *         return userRepository.findByEmail(email);
 *     }
 * }
 * </pre>
 * 
 * @since 0.3.0
 * @author Caner Mastan
 */
public interface UserRepository extends BaseRepository<User, Long> {
    Optional<User> findByEmail(String email);
} 