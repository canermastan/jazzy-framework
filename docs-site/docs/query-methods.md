# Query Methods

Jazzy Framework provides powerful query method capabilities that automatically generate database queries from method names, similar to Spring Data JPA. This feature eliminates the need to write SQL for common query patterns while maintaining type safety and readability.

## Overview

Query methods in Jazzy support:

- **Method Name Parsing**: Automatic query generation from method names
- **Custom Queries**: @Query annotation for complex HQL/JPQL and native SQL
- **Parameter Binding**: Automatic parameter mapping and type conversion
- **Return Type Flexibility**: Support for Optional, List, primitives, and custom types
- **Performance Optimization**: Database-level filtering instead of memory operations

## Method Name Query Generation

### Basic Syntax

Query methods follow the pattern: `<operation>By<property><condition>`

```java
// Basic pattern examples
Optional<User> findByEmail(String email);           // SELECT u FROM User u WHERE u.email = ?1
List<User> findByActive(boolean active);            // SELECT u FROM User u WHERE u.active = ?1
long countByActive(boolean active);                 // SELECT COUNT(u) FROM User u WHERE u.active = ?1
boolean existsByEmail(String email);               // SELECT COUNT(u) FROM User u WHERE u.email = ?1 > 0
void deleteByActive(boolean active);               // DELETE FROM User u WHERE u.active = ?1
```

### Supported Operations

| Operation | Description | Example | Generated Query |
|-----------|-------------|---------|-----------------|
| `find` | Retrieve entities | `findByEmail` | `SELECT u FROM User u WHERE u.email = ?1` |
| `count` | Count entities | `countByActive` | `SELECT COUNT(u) FROM User u WHERE u.active = ?1` |
| `exists` | Check existence | `existsByEmail` | `SELECT COUNT(u) FROM User u WHERE u.email = ?1 > 0` |
| `delete` | Delete entities | `deleteByActive` | `DELETE FROM User u WHERE u.active = ?1` |

### Property Conditions

#### Equality

```java
// Simple equality
Optional<User> findByEmail(String email);
List<User> findByName(String name);
List<User> findByActive(boolean active);

// Generated queries
// SELECT u FROM User u WHERE u.email = :email
// SELECT u FROM User u WHERE u.name = :name
// SELECT u FROM User u WHERE u.active = :active
```

#### Comparison Operations

```java
// Numeric comparisons
List<User> findByAgeGreaterThan(int age);
List<User> findByAgeLessThan(int age);
List<User> findByAgeGreaterThanEqual(int age);
List<User> findByAgeLessThanEqual(int age);
List<User> findByAgeBetween(int minAge, int maxAge);

// Date comparisons
List<User> findByCreatedDateAfter(Date date);
List<User> findByCreatedDateBefore(Date date);
List<User> findByCreatedDateBetween(Date start, Date end);

// Generated queries
// SELECT u FROM User u WHERE u.age > :age
// SELECT u FROM User u WHERE u.age < :age
// SELECT u FROM User u WHERE u.age >= :age
// SELECT u FROM User u WHERE u.age <= :age
// SELECT u FROM User u WHERE u.age BETWEEN :minAge AND :maxAge
```

#### String Operations

```java
// String matching
List<User> findByNameLike(String pattern);
List<User> findByNameContaining(String substring);
List<User> findByNameStartingWith(String prefix);
List<User> findByNameEndingWith(String suffix);
List<User> findByNameIgnoreCase(String name);

// Generated queries
// SELECT u FROM User u WHERE u.name LIKE :pattern
// SELECT u FROM User u WHERE u.name LIKE %:substring%
// SELECT u FROM User u WHERE u.name LIKE :prefix%
// SELECT u FROM User u WHERE u.name LIKE %:suffix
// SELECT u FROM User u WHERE UPPER(u.name) = UPPER(:name)
```

#### Null Checks

```java
// Null/Not null checks
List<User> findByLastLoginIsNull();
List<User> findByLastLoginIsNotNull();
List<User> findByEmailNull();
List<User> findByEmailNotNull();

// Generated queries
// SELECT u FROM User u WHERE u.lastLogin IS NULL
// SELECT u FROM User u WHERE u.lastLogin IS NOT NULL
// SELECT u FROM User u WHERE u.email IS NULL
// SELECT u FROM User u WHERE u.email IS NOT NULL
```

#### Boolean Operations

```java
// Boolean values
List<User> findByActiveTrue();
List<User> findByActiveFalse();

// Generated queries
// SELECT u FROM User u WHERE u.active = true
// SELECT u FROM User u WHERE u.active = false
```

#### Collection Operations

```java
// In/Not in collections
List<User> findByAgeIn(Collection<Integer> ages);
List<User> findByAgeNotIn(Collection<Integer> ages);
List<User> findByStatusIn(List<String> statuses);

// Generated queries
// SELECT u FROM User u WHERE u.age IN :ages
// SELECT u FROM User u WHERE u.age NOT IN :ages
// SELECT u FROM User u WHERE u.status IN :statuses
```

### Logical Operators

#### AND Operations

```java
// Multiple conditions with AND
Optional<User> findByEmailAndActive(String email, boolean active);
List<User> findByNameAndAgeGreaterThan(String name, int age);
List<User> findByActiveAndCreatedDateAfter(boolean active, Date date);

// Generated queries
// SELECT u FROM User u WHERE u.email = :email AND u.active = :active
// SELECT u FROM User u WHERE u.name = :name AND u.age > :age
// SELECT u FROM User u WHERE u.active = :active AND u.createdDate > :date
```

#### OR Operations

```java
// Multiple conditions with OR
List<User> findByNameOrEmail(String name, String email);
List<User> findByActiveOrVerified(boolean active, boolean verified);

// Generated queries
// SELECT u FROM User u WHERE u.name = :name OR u.email = :email
// SELECT u FROM User u WHERE u.active = :active OR u.verified = :verified
```

#### Complex Combinations

```java
// Complex logical combinations
List<User> findByActiveAndNameContainingOrEmailContaining(
    boolean active, String namePattern, String emailPattern);

// Generated query
// SELECT u FROM User u WHERE u.active = :active AND 
// (u.name LIKE %:namePattern% OR u.email LIKE %:emailPattern%)
```

### Ordering

```java
// Single property ordering
List<User> findByActiveOrderByNameAsc(boolean active);
List<User> findByActiveOrderByNameDesc(boolean active);
List<User> findByActiveOrderByCreatedDateDesc(boolean active);

// Multiple property ordering
List<User> findByActiveOrderByNameAscAgeDesc(boolean active);
List<User> findByDepartmentOrderByNameAscCreatedDateDesc(String department);

// Generated queries
// SELECT u FROM User u WHERE u.active = :active ORDER BY u.name ASC
// SELECT u FROM User u WHERE u.active = :active ORDER BY u.name DESC
// SELECT u FROM User u WHERE u.active = :active ORDER BY u.name ASC, u.age DESC
```

### Return Types

#### Optional for Single Results

```java
// Single result that might not exist
Optional<User> findByEmail(String email);
Optional<User> findByIdAndActive(Long id, boolean active);

// Framework automatically wraps single results in Optional
```

#### Lists for Multiple Results

```java
// Multiple results
List<User> findByActive(boolean active);
List<User> findByAgeGreaterThan(int age);
List<User> findByNameContaining(String pattern);

// Empty list returned if no results found
```

#### Primitive Types for Counts and Checks

```java
// Count operations
long countByActive(boolean active);
long countByAgeGreaterThan(int age);

// Existence checks
boolean existsByEmail(String email);
boolean existsByEmailAndActive(String email, boolean active);

// Delete operations (returns count of deleted entities)
long deleteByActive(boolean active);
int deleteByAgeGreaterThan(int age);
```

## Custom Queries with @Query

For complex queries that can't be expressed through method names:

### HQL/JPQL Queries

```java
public interface UserRepository extends BaseRepository<User, Long> {
    
    // Simple custom query
    @Query("SELECT u FROM User u WHERE u.email = :email AND u.active = true")
    Optional<User> findActiveUserByEmail(String email);
    
    // Query with joins
    @Query("SELECT u FROM User u JOIN u.department d WHERE d.name = :deptName")
    List<User> findUsersByDepartmentName(String deptName);
    
    // Aggregate queries
    @Query("SELECT COUNT(u) FROM User u WHERE u.createdDate > :date")
    long countUsersCreatedAfter(Date date);
    
    @Query("SELECT AVG(u.age) FROM User u WHERE u.active = true")
    Double getAverageAgeOfActiveUsers();
    
    // Subqueries
    @Query("""
        SELECT u FROM User u 
        WHERE u.id IN (
            SELECT p.user.id FROM Post p 
            WHERE p.published = true AND p.createdDate > :date
        )
        """)
    List<User> findUsersWithRecentPublishedPosts(Date date);
    
    // Complex conditions
    @Query("""
        SELECT u FROM User u 
        WHERE u.active = true 
        AND u.department.name = :dept 
        AND u.createdDate BETWEEN :startDate AND :endDate
        ORDER BY u.name ASC
        """)
    List<User> findActiveUsersByDepartmentAndDateRange(
        String dept, Date startDate, Date endDate);
}
```

### Native SQL Queries

```java
public interface UserRepository extends BaseRepository<User, Long> {
    
    // Simple native query
    @Query(value = "SELECT * FROM users WHERE email = ?1", nativeQuery = true)
    Optional<User> findByEmailNative(String email);
    
    // Complex native query with joins
    @Query(value = """
        SELECT u.*, d.name as dept_name 
        FROM users u 
        LEFT JOIN departments d ON u.department_id = d.id 
        WHERE u.active = true 
        AND d.name = :deptName
        ORDER BY u.name
        """, nativeQuery = true)
    List<User> findActiveUsersByDepartmentNative(String deptName);
    
    // Native aggregate query
    @Query(value = """
        SELECT COUNT(*) 
        FROM users u 
        WHERE u.created_date > :date 
        AND u.active = true
        """, nativeQuery = true)
    long countActiveUsersCreatedAfter(Date date);
    
    // Database-specific features
    @Query(value = """
        SELECT u.* FROM users u 
        WHERE MATCH(u.name, u.email) AGAINST (:searchTerm IN NATURAL LANGUAGE MODE)
        """, nativeQuery = true)
    List<User> fullTextSearch(String searchTerm);  // MySQL specific
}
```

### Modifying Queries

Use `@Modifying` for UPDATE, DELETE, or INSERT operations:

```java
public interface UserRepository extends BaseRepository<User, Long> {
    
    // Update operations
    @Query("UPDATE User u SET u.active = :active WHERE u.email = :email")
    @Modifying
    int updateUserActiveStatus(String email, boolean active);
    
    @Query("UPDATE User u SET u.lastLogin = CURRENT_TIMESTAMP WHERE u.id = :id")
    @Modifying
    int updateLastLogin(Long id);
    
    // Bulk updates
    @Query("UPDATE User u SET u.active = false WHERE u.lastLogin < :cutoffDate")
    @Modifying
    int deactivateInactiveUsers(Date cutoffDate);
    
    @Query("UPDATE User u SET u.verified = true WHERE u.email IN :emails")
    @Modifying
    int verifyUsersByEmails(List<String> emails);
    
    // Delete operations
    @Query("DELETE FROM User u WHERE u.active = false AND u.createdDate < :cutoffDate")
    @Modifying
    int deleteOldInactiveUsers(Date cutoffDate);
    
    // Native modifying queries
    @Query(value = "UPDATE users SET login_count = login_count + 1 WHERE id = ?1", 
           nativeQuery = true)
    @Modifying
    int incrementLoginCount(Long userId);
}
```

## Parameter Binding

### Named Parameters

```java
// HQL with named parameters
@Query("SELECT u FROM User u WHERE u.name = :name AND u.age > :minAge")
List<User> findByNameAndMinAge(String name, int minAge);

// Native SQL with named parameters
@Query(value = "SELECT * FROM users WHERE name = :name AND age > :minAge", 
       nativeQuery = true)
List<User> findByNameAndMinAgeNative(String name, int minAge);
```

### Positional Parameters

```java
// HQL with positional parameters
@Query("SELECT u FROM User u WHERE u.name = ?1 AND u.age > ?2")
List<User> findByNameAndMinAge(String name, int minAge);

// Native SQL with positional parameters
@Query(value = "SELECT * FROM users WHERE name = ?1 AND age > ?2", 
       nativeQuery = true)
List<User> findByNameAndMinAgeNative(String name, int minAge);
```

### Collection Parameters

```java
// Collections in queries
@Query("SELECT u FROM User u WHERE u.status IN :statuses")
List<User> findByStatuses(List<String> statuses);

@Query("SELECT u FROM User u WHERE u.id IN :ids")
List<User> findByIds(Set<Long> ids);

// Native SQL with collections
@Query(value = "SELECT * FROM users WHERE status IN (:statuses)", nativeQuery = true)
List<User> findByStatusesNative(List<String> statuses);
```

## Advanced Query Patterns

### Pagination and Limiting

```java
// Top/First keywords for limiting results
List<User> findTop10ByActiveOrderByCreatedDateDesc(boolean active);
List<User> findFirst5ByNameContainingOrderByName(String namePattern);
Optional<User> findFirstByActiveOrderByCreatedDateDesc(boolean active);

// Custom limit with @Query
@Query(value = "SELECT * FROM users WHERE active = ?1 ORDER BY created_date DESC LIMIT ?2", 
       nativeQuery = true)
List<User> findActiveUsersWithLimit(boolean active, int limit);
```

### Distinct Results

```java
// Distinct keyword
List<String> findDistinctNameByActive(boolean active);
List<User> findDistinctByDepartmentName(String departmentName);

// Custom distinct with @Query
@Query("SELECT DISTINCT u.department FROM User u WHERE u.active = true")
List<String> findDistinctActiveDepartments();
```

### Case Insensitive Queries

```java
// IgnoreCase keyword
List<User> findByNameIgnoreCase(String name);
List<User> findByEmailContainingIgnoreCase(String emailPattern);

// Custom case insensitive with @Query
@Query("SELECT u FROM User u WHERE UPPER(u.name) = UPPER(:name)")
List<User> findByNameCaseInsensitive(String name);
```

### Date and Time Queries

```java
// Date comparisons
List<User> findByCreatedDateAfter(Date date);
List<User> findByCreatedDateBefore(Date date);
List<User> findByCreatedDateBetween(Date start, Date end);

// Time-based queries with @Query
@Query("SELECT u FROM User u WHERE u.createdDate >= :startOfDay AND u.createdDate < :endOfDay")
List<User> findUsersCreatedOnDate(Date startOfDay, Date endOfDay);

@Query("SELECT u FROM User u WHERE YEAR(u.createdDate) = :year")
List<User> findUsersCreatedInYear(int year);

// Native SQL for database-specific date functions
@Query(value = "SELECT * FROM users WHERE DATE(created_date) = CURDATE()", nativeQuery = true)
List<User> findUsersCreatedToday();
```

## Performance Considerations

### Index Usage

```java
// Queries that can use indexes effectively
Optional<User> findByEmail(String email);        // If email is indexed
List<User> findByActive(boolean active);         // If active is indexed
List<User> findByCreatedDateAfter(Date date);    // If created_date is indexed

// Compound index usage
List<User> findByActiveAndDepartment(boolean active, String department);
// Effective if there's an index on (active, department)
```

### Query Optimization

```java
// Good: Specific queries
List<User> findByActive(boolean active);
long countByActive(boolean active);
boolean existsByEmail(String email);

// Avoid: Inefficient patterns
// Don't do this - loads all users into memory then filters
// List<User> allUsers = userRepository.findAll();
// List<User> activeUsers = allUsers.stream()
//     .filter(User::isActive)
//     .collect(toList());

// Do this instead - database-level filtering
List<User> activeUsers = userRepository.findByActive(true);
```

### Batch Operations

```java
// Efficient batch operations
List<User> saveAll(Iterable<User> users);
void deleteAllById(Iterable<Long> ids);

// Bulk operations with @Query
@Query("UPDATE User u SET u.active = false WHERE u.id IN :ids")
@Modifying
int deactivateUsers(List<Long> ids);

@Query("DELETE FROM User u WHERE u.id IN :ids")
@Modifying
int deleteUsersByIds(List<Long> ids);
```

## Error Handling and Debugging

### Common Errors

```java
// Error: Method name doesn't follow conventions
// List<User> getUsersByEmail(String email);  // Wrong prefix
List<User> findByEmail(String email);          // Correct

// Error: Property doesn't exist
// List<User> findByNonExistentProperty(String value);  // Will fail
List<User> findByName(String name);                     // Correct

// Error: Parameter count mismatch
// List<User> findByEmailAndActive(String email);       // Missing parameter
List<User> findByEmailAndActive(String email, boolean active);  // Correct
```

### Debug Query Generation

Enable SQL logging to see generated queries:

```properties
# Enable SQL logging
jazzy.jpa.show-sql=true
jazzy.jpa.hibernate.format_sql=true

# Enable parameter logging
logging.level.org.hibernate.type.descriptor.sql.BasicBinder=TRACE
```

### Testing Query Methods

```java
@Component
public class UserRepositoryTest {
    private final UserRepository userRepository;
    
    public UserRepositoryTest(UserRepository userRepository) {
        this.userRepository = userRepository;
    }
    
    public void testQueryMethods() {
        // Test data setup
        User user1 = new User("John Doe", "john@example.com", "password");
        User user2 = new User("Jane Smith", "jane@example.com", "password");
        user2.setActive(false);
        
        userRepository.saveAll(List.of(user1, user2));
        
        // Test method name queries
        Optional<User> foundByEmail = userRepository.findByEmail("john@example.com");
        assert foundByEmail.isPresent();
        assert foundByEmail.get().getName().equals("John Doe");
        
        List<User> activeUsers = userRepository.findByActive(true);
        assert activeUsers.size() == 1;
        assert activeUsers.get(0).getName().equals("John Doe");
        
        long activeCount = userRepository.countByActive(true);
        assert activeCount == 1;
        
        boolean exists = userRepository.existsByEmail("john@example.com");
        assert exists;
        
        // Test custom queries
        Optional<User> activeUser = userRepository.findActiveUserByEmail("john@example.com");
        assert activeUser.isPresent();
        
        // Cleanup
        userRepository.deleteAll();
    }
}
```

## Best Practices

### 1. Method Naming

```java
// Good: Clear, descriptive names
Optional<User> findByEmail(String email);
List<User> findActiveUsersByDepartment(String department);
long countUsersByRegistrationDateAfter(Date date);

// Avoid: Unclear or overly complex names
Optional<User> findByEmailAndActiveAndDepartmentAndRole(...);  // Too complex
List<User> getStuff(String thing);                            // Unclear
```

### 2. Return Types

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

### 3. Query Complexity

```java
// Good: Simple, focused queries
@Query("SELECT u FROM User u WHERE u.email = :email AND u.active = true")
Optional<User> findActiveUserByEmail(String email);

// Consider: Breaking down complex queries
@Query("SELECT u FROM User u WHERE u.department.name = :dept")
List<User> findUsersByDepartment(String dept);

// Avoid: Overly complex queries
@Query("""
    SELECT u FROM User u 
    JOIN u.department d 
    JOIN u.roles r 
    WHERE u.active = true 
    AND d.name = :dept 
    AND r.name IN :roles 
    AND u.createdDate > :date
    """)
List<User> findComplexUserCriteria(...);  // Consider breaking this down
```

### 4. Performance

```java
// Good: Use specific queries
boolean existsByEmail(String email);      // Better than findByEmail().isPresent()
long countByActive(boolean active);       // Better than findByActive().size()

// Good: Use appropriate indexes
List<User> findByEmail(String email);     // Ensure email is indexed
List<User> findByActiveAndDepartment(boolean active, String dept);  // Compound index

// Avoid: Inefficient patterns
List<User> findAll();  // Then filter in memory - use specific queries instead
```

## Next Steps

- [Repository Pattern](repositories.md) - Repository interface design
- [Database Examples](database-examples.md) - Complete working examples
- [Database Integration](database-integration.md) - Overall database setup guide 