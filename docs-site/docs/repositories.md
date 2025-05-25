# Repository Pattern

The Repository Pattern in Jazzy Framework provides a Spring Data JPA-like abstraction for data access. It automatically generates implementations for repository interfaces, eliminating the need for boilerplate code while providing powerful query capabilities.

## Overview

Jazzy's repository system provides:

- **Automatic Implementation**: No need to write repository implementations
- **Type Safety**: Generic type parameters ensure compile-time safety
- **Method Name Parsing**: Automatic query generation from method names
- **Custom Queries**: Support for HQL/JPQL and native SQL
- **Transaction Management**: Automatic transaction handling
- **Caching**: Built-in repository instance caching

## BaseRepository Interface

All repository interfaces must extend `BaseRepository<T, ID>`:

```java
public interface BaseRepository<T, ID> {
    // Save operations
    T save(T entity);
    List<T> saveAll(Iterable<T> entities);
    T saveAndFlush(T entity);
    
    // Find operations
    Optional<T> findById(ID id);
    List<T> findAll();
    List<T> findAllById(Iterable<ID> ids);
    
    // Existence checks
    boolean existsById(ID id);
    long count();
    
    // Delete operations
    void deleteById(ID id);
    void delete(T entity);
    void deleteAllById(Iterable<ID> ids);
    void deleteAll(Iterable<T> entities);
    void deleteAll();
    void deleteInBatch(Iterable<T> entities);
    void deleteAllInBatch();
    
    // Utility operations
    void flush();
}
```

## Creating Repository Interfaces

### Basic Repository

```java
package com.example.repository;

import com.example.entity.User;
import jazzyframework.data.BaseRepository;

public interface UserRepository extends BaseRepository<User, Long> {
    // Inherits all basic CRUD operations
    // Additional methods can be added here
}
```

### Repository with Custom Methods

```java
package com.example.repository;

import com.example.entity.User;
import jazzyframework.data.BaseRepository;
import jazzyframework.data.annotations.Query;
import jazzyframework.data.annotations.Modifying;

import java.util.List;
import java.util.Optional;

public interface UserRepository extends BaseRepository<User, Long> {
    
    // Method name parsing - automatically generates queries
    Optional<User> findByEmail(String email);
    List<User> findByActive(boolean active);
    List<User> findByNameContaining(String name);
    List<User> findByAgeGreaterThan(int age);
    List<User> findByEmailAndActive(String email, boolean active);
    
    // Count operations
    long countByActive(boolean active);
    long countByAgeGreaterThan(int age);
    
    // Existence checks
    boolean existsByEmail(String email);
    boolean existsByEmailAndActive(String email, boolean active);
    
    // Custom HQL/JPQL queries
    @Query("SELECT u FROM User u WHERE u.email = :email AND u.active = true")
    Optional<User> findActiveUserByEmail(String email);
    
    @Query("SELECT u FROM User u WHERE u.name LIKE %:name% ORDER BY u.name")
    List<User> searchByNameSorted(String name);
    
    // Native SQL queries
    @Query(value = "SELECT * FROM users WHERE email = ?1", nativeQuery = true)
    Optional<User> findByEmailNative(String email);
    
    // Update operations
    @Query("UPDATE User u SET u.active = :active WHERE u.email = :email")
    @Modifying
    int updateUserActiveStatus(String email, boolean active);
    
    @Query("DELETE FROM User u WHERE u.active = false")
    @Modifying
    int deleteInactiveUsers();
}
```

## Method Name Query Generation

Jazzy automatically generates queries based on method names following Spring Data JPA conventions:

### Supported Keywords

| Keyword | Sample | JPQL snippet |
|---------|--------|--------------|
| `And` | `findByLastnameAndFirstname` | `… where x.lastname = ?1 and x.firstname = ?2` |
| `Or` | `findByLastnameOrFirstname` | `… where x.lastname = ?1 or x.firstname = ?2` |
| `Is`, `Equals` | `findByFirstname`, `findByFirstnameIs` | `… where x.firstname = ?1` |
| `Between` | `findByStartDateBetween` | `… where x.startDate between ?1 and ?2` |
| `LessThan` | `findByAgeLessThan` | `… where x.age < ?1` |
| `LessThanEqual` | `findByAgeLessThanEqual` | `… where x.age <= ?1` |
| `GreaterThan` | `findByAgeGreaterThan` | `… where x.age > ?1` |
| `GreaterThanEqual` | `findByAgeGreaterThanEqual` | `… where x.age >= ?1` |
| `After` | `findByStartDateAfter` | `… where x.startDate > ?1` |
| `Before` | `findByStartDateBefore` | `… where x.startDate < ?1` |
| `IsNull`, `Null` | `findByAge(Is)Null` | `… where x.age is null` |
| `IsNotNull`, `NotNull` | `findByAge(Is)NotNull` | `… where x.age not null` |
| `Like` | `findByFirstnameLike` | `… where x.firstname like ?1` |
| `NotLike` | `findByFirstnameNotLike` | `… where x.firstname not like ?1` |
| `StartingWith` | `findByFirstnameStartingWith` | `… where x.firstname like ?1%` |
| `EndingWith` | `findByFirstnameEndingWith` | `… where x.firstname like %?1` |
| `Containing` | `findByFirstnameContaining` | `… where x.firstname like %?1%` |
| `OrderBy` | `findByAgeOrderByLastnameDesc` | `… where x.age = ?1 order by x.lastname desc` |
| `Not` | `findByLastnameNot` | `… where x.lastname <> ?1` |
| `In` | `findByAgeIn(Collection<Age> ages)` | `… where x.age in ?1` |
| `NotIn` | `findByAgeNotIn(Collection<Age> ages)` | `… where x.age not in ?1` |
| `True` | `findByActiveTrue()` | `… where x.active = true` |
| `False` | `findByActiveFalse()` | `… where x.active = false` |
| `IgnoreCase` | `findByFirstnameIgnoreCase` | `… where UPPER(x.firstname) = UPPER(?1)` |

### Query Method Examples

```java
public interface UserRepository extends BaseRepository<User, Long> {
    
    // Simple property queries
    Optional<User> findByEmail(String email);
    List<User> findByActive(boolean active);
    List<User> findByName(String name);
    
    // Comparison queries
    List<User> findByAgeGreaterThan(int age);
    List<User> findByAgeLessThanEqual(int age);
    List<User> findByAgeBetween(int minAge, int maxAge);
    
    // String queries
    List<User> findByNameContaining(String name);
    List<User> findByNameStartingWith(String prefix);
    List<User> findByNameEndingWith(String suffix);
    List<User> findByNameLike(String pattern);
    
    // Boolean queries
    List<User> findByActiveTrue();
    List<User> findByActiveFalse();
    
    // Null checks
    List<User> findByLastLoginIsNull();
    List<User> findByLastLoginIsNotNull();
    
    // Collection queries
    List<User> findByAgeIn(Collection<Integer> ages);
    List<User> findByAgeNotIn(Collection<Integer> ages);
    
    // Combined conditions
    List<User> findByEmailAndActive(String email, boolean active);
    List<User> findByNameOrEmail(String name, String email);
    List<User> findByActiveAndAgeGreaterThan(boolean active, int age);
    
    // Ordering
    List<User> findByActiveOrderByNameAsc(boolean active);
    List<User> findByActiveOrderByNameDesc(boolean active);
    List<User> findByActiveOrderByNameAscAgeDesc(boolean active);
    
    // Count queries
    long countByActive(boolean active);
    long countByAgeGreaterThan(int age);
    long countByEmailContaining(String emailPart);
    
    // Existence queries
    boolean existsByEmail(String email);
    boolean existsByEmailAndActive(String email, boolean active);
    
    // Delete queries
    void deleteByActive(boolean active);
    void deleteByAgeGreaterThan(int age);
    long deleteByEmailContaining(String emailPart);  // Returns count
}
```

## Custom Queries with @Query

For complex queries that can't be expressed through method names, use the `@Query` annotation:

### HQL/JPQL Queries

```java
public interface UserRepository extends BaseRepository<User, Long> {
    
    // Simple HQL query
    @Query("SELECT u FROM User u WHERE u.email = :email")
    Optional<User> findByEmailHql(String email);
    
    // Query with multiple parameters
    @Query("SELECT u FROM User u WHERE u.name = :name AND u.age > :minAge")
    List<User> findByNameAndMinAge(String name, int minAge);
    
    // Query with LIKE operator
    @Query("SELECT u FROM User u WHERE u.name LIKE %:name% ORDER BY u.name")
    List<User> searchByName(String name);
    
    // Aggregate queries
    @Query("SELECT COUNT(u) FROM User u WHERE u.active = :active")
    long countActiveUsers(boolean active);
    
    @Query("SELECT AVG(u.age) FROM User u WHERE u.active = true")
    Double getAverageAgeOfActiveUsers();
    
    // Join queries
    @Query("SELECT u FROM User u JOIN u.posts p WHERE p.title LIKE %:title%")
    List<User> findUsersByPostTitle(String title);
    
    // Subqueries
    @Query("SELECT u FROM User u WHERE u.id IN (SELECT p.user.id FROM Post p WHERE p.published = true)")
    List<User> findUsersWithPublishedPosts();
}
```

### Native SQL Queries

```java
public interface UserRepository extends BaseRepository<User, Long> {
    
    // Simple native query
    @Query(value = "SELECT * FROM users WHERE email = ?1", nativeQuery = true)
    Optional<User> findByEmailNative(String email);
    
    // Native query with named parameters
    @Query(value = "SELECT * FROM users WHERE name = :name AND active = :active", nativeQuery = true)
    List<User> findByNameAndActiveNative(String name, boolean active);
    
    // Complex native query
    @Query(value = """
        SELECT u.* FROM users u 
        LEFT JOIN posts p ON u.id = p.user_id 
        WHERE u.active = true 
        GROUP BY u.id 
        HAVING COUNT(p.id) > :minPosts
        ORDER BY COUNT(p.id) DESC
        """, nativeQuery = true)
    List<User> findActiveUsersWithMinimumPosts(int minPosts);
    
    // Native count query
    @Query(value = "SELECT COUNT(*) FROM users WHERE active = ?1", nativeQuery = true)
    long countByActiveNative(boolean active);
}
```

## Modifying Queries

Use `@Modifying` annotation for UPDATE, DELETE, or INSERT operations:

```java
public interface UserRepository extends BaseRepository<User, Long> {
    
    // Update operations
    @Query("UPDATE User u SET u.active = :active WHERE u.email = :email")
    @Modifying
    int updateUserActiveStatus(String email, boolean active);
    
    @Query("UPDATE User u SET u.lastLogin = CURRENT_TIMESTAMP WHERE u.id = :id")
    @Modifying
    int updateLastLogin(Long id);
    
    // Bulk update
    @Query("UPDATE User u SET u.active = false WHERE u.lastLogin < :cutoffDate")
    @Modifying
    int deactivateInactiveUsers(Date cutoffDate);
    
    // Delete operations
    @Query("DELETE FROM User u WHERE u.active = false")
    @Modifying
    int deleteInactiveUsers();
    
    @Query("DELETE FROM User u WHERE u.lastLogin < :cutoffDate")
    @Modifying
    int deleteOldUsers(Date cutoffDate);
    
    // Native modifying queries
    @Query(value = "UPDATE users SET active = false WHERE last_login < ?1", nativeQuery = true)
    @Modifying
    int deactivateOldUsersNative(Date cutoffDate);
}
```

## Repository Implementation Details

### Automatic Proxy Creation

Jazzy automatically creates proxy implementations for repository interfaces:

```java
// Framework automatically creates this implementation
public class UserRepositoryImpl implements UserRepository {
    private final SessionFactory sessionFactory;
    private final BaseRepositoryImpl<User, Long> baseImpl;
    
    // All methods are automatically implemented
    public Optional<User> findByEmail(String email) {
        // Generated query: SELECT u FROM User u WHERE u.email = :email
        // Automatic parameter binding and result mapping
    }
}
```

### Transaction Management

Each repository method automatically runs in a transaction:

```java
// Each method call is wrapped in a transaction
userRepository.save(user);           // Transaction: BEGIN -> SAVE -> COMMIT
userRepository.findByEmail(email);   // Transaction: BEGIN -> SELECT -> COMMIT
userRepository.deleteById(id);       // Transaction: BEGIN -> DELETE -> COMMIT
```

### Error Handling

Repository methods provide automatic error handling:

```java
try {
    User user = userRepository.save(user);
    return user;
} catch (IllegalArgumentException e) {
    // Validation errors (null parameters, etc.)
    throw e;
} catch (Exception e) {
    // Database errors are wrapped in RuntimeException
    throw new RuntimeException("Database operation failed", e);
}
```

## Advanced Repository Patterns

### Repository with Custom Base

```java
// Custom base repository with additional methods
public interface CustomBaseRepository<T, ID> extends BaseRepository<T, ID> {
    List<T> findAllActive();
    void softDelete(ID id);
    void restore(ID id);
}

// Implementation would be provided by extending BaseRepositoryImpl
public interface UserRepository extends CustomBaseRepository<User, Long> {
    Optional<User> findByEmail(String email);
}
```

### Repository Composition

```java
// Separate repositories for different concerns
public interface UserRepository extends BaseRepository<User, Long> {
    Optional<User> findByEmail(String email);
    List<User> findByActive(boolean active);
}

public interface UserSecurityRepository extends BaseRepository<User, Long> {
    @Query("UPDATE User u SET u.password = :password WHERE u.id = :id")
    @Modifying
    int updatePassword(Long id, String password);
    
    @Query("UPDATE User u SET u.failedLoginAttempts = :attempts WHERE u.id = :id")
    @Modifying
    int updateFailedLoginAttempts(Long id, int attempts);
}

// Service layer can inject both repositories
@Component
public class UserService {
    private final UserRepository userRepository;
    private final UserSecurityRepository userSecurityRepository;
    
    public UserService(UserRepository userRepository, 
                      UserSecurityRepository userSecurityRepository) {
        this.userRepository = userRepository;
        this.userSecurityRepository = userSecurityRepository;
    }
}
```

## Best Practices

### 1. Repository Naming

```java
// Good: Clear, specific names
public interface UserRepository extends BaseRepository<User, Long> {}
public interface OrderRepository extends BaseRepository<Order, Long> {}
public interface ProductRepository extends BaseRepository<Product, Long> {}

// Avoid: Generic or unclear names
public interface DataRepository extends BaseRepository<Object, Long> {}
public interface Repository extends BaseRepository<Entity, Long> {}
```

### 2. Method Naming

```java
// Good: Descriptive method names
Optional<User> findByEmail(String email);
List<User> findActiveUsersByDepartment(String department);
long countUsersByRegistrationDateAfter(Date date);

// Avoid: Unclear or overly complex names
Optional<User> findByEmailAndActiveAndDepartmentAndRoleAndStatusAndCreatedDateAfter(...);
List<User> getUserStuff(String thing);
```

### 3. Query Complexity

```java
// Good: Simple, focused queries
@Query("SELECT u FROM User u WHERE u.email = :email AND u.active = true")
Optional<User> findActiveUserByEmail(String email);

// Consider breaking down complex queries
@Query("SELECT u FROM User u WHERE u.department.name = :dept AND u.active = true")
List<User> findActiveUsersByDepartment(String dept);

// Avoid: Overly complex single queries
@Query("""
    SELECT u FROM User u 
    JOIN u.department d 
    JOIN u.roles r 
    JOIN u.permissions p 
    WHERE u.active = true 
    AND d.name = :dept 
    AND r.name IN :roles 
    AND p.name IN :permissions 
    AND u.createdDate > :date
    AND u.lastLogin IS NOT NULL
    """)
List<User> findComplexUserCriteria(...);  // Too complex, break it down
```

### 4. Return Types

```java
// Good: Appropriate return types
Optional<User> findByEmail(String email);        // Single result that might not exist
List<User> findByActive(boolean active);         // Multiple results
boolean existsByEmail(String email);             // Existence check
long countByActive(boolean active);              // Count operation

// Avoid: Inappropriate return types
User findByEmail(String email);                  // Might return null
Optional<List<User>> findByActive(boolean active); // Unnecessary Optional wrapping
```

## Testing Repositories

### Unit Testing

```java
@ExtendWith(MockitoExtension.class)
class UserServiceTest {
    
    @Mock
    private UserRepository userRepository;
    
    @InjectMocks
    private UserService userService;
    
    @Test
    void shouldCreateUser() {
        // Given
        User user = new User("John", "john@example.com", "password");
        when(userRepository.existsByEmail("john@example.com")).thenReturn(false);
        when(userRepository.save(any(User.class))).thenReturn(user);
        
        // When
        User result = userService.createUser("John", "john@example.com", "password");
        
        // Then
        assertThat(result.getName()).isEqualTo("John");
        verify(userRepository).existsByEmail("john@example.com");
        verify(userRepository).save(any(User.class));
    }
}
```

### Integration Testing

```java
@Component
public class UserRepositoryTest {
    private final UserRepository userRepository;
    
    public UserRepositoryTest(UserRepository userRepository) {
        this.userRepository = userRepository;
    }
    
    public void testRepositoryOperations() {
        // Create test data
        User user = new User("Test User", "test@example.com", "password");
        User saved = userRepository.save(user);
        
        // Test find operations
        Optional<User> found = userRepository.findByEmail("test@example.com");
        assert found.isPresent();
        assert found.get().getName().equals("Test User");
        
        // Test count operations
        long count = userRepository.countByActive(true);
        assert count > 0;
        
        // Test existence checks
        boolean exists = userRepository.existsByEmail("test@example.com");
        assert exists;
        
        // Cleanup
        userRepository.delete(saved);
    }
}
```

## Next Steps

- [Query Methods](query-methods.md) - Detailed guide to method name parsing
- [Database Examples](database-examples.md) - Complete working examples
- [Database Integration](database-integration.md) - Overall database setup guide 