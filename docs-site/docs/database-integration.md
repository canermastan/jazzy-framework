# Database Integration

Jazzy Framework 0.3 introduces comprehensive database integration with Spring Data JPA-like functionality. The framework provides automatic entity discovery, repository pattern implementation, and zero-configuration database setup.

## Overview

The database integration system provides:

- **Hibernate/JPA Integration**: Full ORM support with automatic configuration
- **Spring Data JPA-like Repositories**: Familiar repository pattern with automatic implementation
- **Method Name Parsing**: Automatic query generation from method names
- **Custom Query Support**: @Query annotation for HQL/JPQL and native SQL
- **Transaction Management**: Automatic transaction handling with proper rollback
- **Entity Discovery**: Automatic entity scanning and configuration
- **Connection Pooling**: HikariCP for production-ready database connections
- **Multiple Database Support**: H2, PostgreSQL, MySQL, Oracle support

## Quick Start

### 1. Configuration

Create `application.properties` in your `src/main/resources` folder:

```properties
# Database Configuration
jazzy.datasource.url=jdbc:h2:mem:testdb
jazzy.datasource.username=sa
jazzy.datasource.password=
jazzy.datasource.driver-class-name=org.h2.Driver

# JPA/Hibernate Configuration
jazzy.jpa.hibernate.ddl-auto=create-drop
jazzy.jpa.show-sql=true
jazzy.jpa.hibernate.dialect=org.hibernate.dialect.H2Dialect

# H2 Console (for development)
jazzy.h2.console.enabled=true
jazzy.h2.console.path=/h2-console
```

### 2. Create an Entity

```java
package com.example.entity;

import jakarta.persistence.*;

@Entity
@Table(name = "users")
public class User {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    
    @Column(unique = true, nullable = false)
    private String email;
    
    @Column(nullable = false)
    private String name;
    
    private String password;
    private boolean active = true;
    
    // Constructors
    public User() {}
    
    public User(String name, String email, String password) {
        this.name = name;
        this.email = email;
        this.password = password;
    }
    
    // Getters and setters
    public Long getId() { return id; }
    public void setId(Long id) { this.id = id; }
    
    public String getEmail() { return email; }
    public void setEmail(String email) { this.email = email; }
    
    public String getName() { return name; }
    public void setName(String name) { this.name = name; }
    
    public String getPassword() { return password; }
    public void setPassword(String password) { this.password = password; }
    
    public boolean isActive() { return active; }
    public void setActive(boolean active) { this.active = active; }
}
```

### 3. Create a Repository

```java
package com.example.repository;

import com.example.entity.User;
import jazzyframework.data.BaseRepository;
import jazzyframework.data.annotations.Query;
import jazzyframework.data.annotations.Modifying;

import java.util.List;
import java.util.Optional;

public interface UserRepository extends BaseRepository<User, Long> {
    
    // Automatic query generation from method names
    Optional<User> findByEmail(String email);
    List<User> findByActive(boolean active);
    List<User> findByNameContaining(String name);
    long countByActive(boolean active);
    boolean existsByEmail(String email);
    
    // Custom HQL/JPQL queries
    @Query("SELECT u FROM User u WHERE u.email = :email AND u.active = true")
    Optional<User> findActiveUserByEmail(String email);
    
    @Query("SELECT u FROM User u WHERE u.name LIKE %:name% ORDER BY u.name")
    List<User> searchByName(String name);
    
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

### 4. Create a Service

```java
package com.example.service;

import com.example.entity.User;
import com.example.repository.UserRepository;
import jazzyframework.di.annotations.Component;

import java.util.List;
import java.util.Optional;

@Component
public class UserService {
    private final UserRepository userRepository;
    
    public UserService(UserRepository userRepository) {
        this.userRepository = userRepository;
    }
    
    public User createUser(String name, String email, String password) {
        // Business logic validation
        if (userRepository.existsByEmail(email)) {
            throw new IllegalArgumentException("User with email " + email + " already exists");
        }
        
        User user = new User(name, email, password);
        return userRepository.save(user);
    }
    
    public Optional<User> findByEmail(String email) {
        return userRepository.findByEmail(email);
    }
    
    public List<User> findActiveUsers() {
        return userRepository.findByActive(true);
    }
    
    public List<User> searchUsers(String name) {
        return userRepository.findByNameContaining(name);
    }
    
    public boolean deactivateUser(String email) {
        int updated = userRepository.updateUserActiveStatus(email, false);
        return updated > 0;
    }
    
    public long getActiveUserCount() {
        return userRepository.countByActive(true);
    }
}
```

### 5. Use in Controller

```java
package com.example.controller;

import com.example.entity.User;
import com.example.service.UserService;
import jazzyframework.di.annotations.Component;
import jazzyframework.http.Request;
import jazzyframework.http.Response;
import jazzyframework.http.JSON;

import java.util.List;
import java.util.Map;
import java.util.Optional;

@Component
public class UserController {
    private final UserService userService;
    
    public UserController(UserService userService) {
        this.userService = userService;
    }
    
    public Response createUser(Request request) {
        User user = request.toObject(User.class);
        User createdUser = userService.createUser(user.getName(), user.getEmail(), user.getPassword());
        return Response.json(JSON.of("user", createdUser));
    }
    
    public Response getUserByEmail(Request request) {
        String email = request.query("email");
        Optional<User> user = userService.findByEmail(email);
        
        if (user.isPresent()) {
            return Response.json(JSON.of("user", user.get()));
        } else {
            return Response.json(JSON.of("error", "User not found")).status(404);
        }
    }
    
    public Response getActiveUsers(Request request) {
        List<User> users = userService.findActiveUsers();
        return Response.json(JSON.of("users", users, "count", users.size()));
    }
    
    public Response searchUsers(Request request) {
        String name = request.query("name");
        List<User> users = userService.searchUsers(name);
        return Response.json(JSON.of("users", users));
    }
}
```

## Configuration Options

### Database Configuration

```properties
# Database Connection
jazzy.datasource.url=jdbc:h2:mem:testdb
jazzy.datasource.username=sa
jazzy.datasource.password=
jazzy.datasource.driver-class-name=org.h2.Driver

# Connection Pool (HikariCP)
jazzy.datasource.hikari.maximum-pool-size=10
jazzy.datasource.hikari.minimum-idle=5
jazzy.datasource.hikari.connection-timeout=30000
jazzy.datasource.hikari.idle-timeout=600000
jazzy.datasource.hikari.max-lifetime=1800000
```

### JPA/Hibernate Configuration

```properties
# Schema Management
jazzy.jpa.hibernate.ddl-auto=create-drop  # create, update, validate, none

# SQL Logging
jazzy.jpa.show-sql=true
jazzy.jpa.hibernate.format_sql=true

# Dialect (auto-detected if not specified)
jazzy.jpa.hibernate.dialect=org.hibernate.dialect.H2Dialect

# Performance Settings
jazzy.jpa.properties.hibernate.jdbc.batch_size=20
jazzy.jpa.properties.hibernate.order_inserts=true
jazzy.jpa.properties.hibernate.order_updates=true
```

### H2 Console Configuration

```properties
# H2 Console (Development Only)
jazzy.h2.console.enabled=true
jazzy.h2.console.path=/h2-console
jazzy.h2.console.port=8082
```

## Supported Databases

### H2 (Development)

```properties
jazzy.datasource.url=jdbc:h2:mem:testdb
jazzy.datasource.driver-class-name=org.h2.Driver
jazzy.jpa.hibernate.dialect=org.hibernate.dialect.H2Dialect
```

### MySQL (Production)

```properties
jazzy.datasource.url=jdbc:mysql://localhost:3306/myapp
jazzy.datasource.username=myuser
jazzy.datasource.password=mypassword
jazzy.datasource.driver-class-name=com.mysql.cj.jdbc.Driver
jazzy.jpa.hibernate.dialect=org.hibernate.dialect.MySQL8Dialect
```

### PostgreSQL (Production)

```properties
jazzy.datasource.url=jdbc:postgresql://localhost:5432/myapp
jazzy.datasource.username=myuser
jazzy.datasource.password=mypassword
jazzy.datasource.driver-class-name=org.postgresql.Driver
jazzy.jpa.hibernate.dialect=org.hibernate.dialect.PostgreSQLDialect
```

## Entity Relationships

### One-to-Many

```java
@Entity
public class User {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    
    @OneToMany(mappedBy = "user", cascade = CascadeType.ALL, fetch = FetchType.LAZY)
    private List<Post> posts = new ArrayList<>();
    
    // getters and setters
}

@Entity
public class Post {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "user_id")
    private User user;
    
    // getters and setters
}
```

### Many-to-Many

```java
@Entity
public class User {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    
    @ManyToMany
    @JoinTable(
        name = "user_roles",
        joinColumns = @JoinColumn(name = "user_id"),
        inverseJoinColumns = @JoinColumn(name = "role_id")
    )
    private Set<Role> roles = new HashSet<>();
    
    // getters and setters
}

@Entity
public class Role {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    
    @ManyToMany(mappedBy = "roles")
    private Set<User> users = new HashSet<>();
    
    // getters and setters
}
```

## Transaction Management

Transactions are automatically managed at the repository level. Each repository method runs in its own transaction:

```java
// Automatic transaction management
public User createUser(String name, String email) {
    User user = new User(name, email);
    return userRepository.save(user);  // Automatically wrapped in transaction
}

// Multiple operations in same transaction
public void transferData() {
    // For complex operations requiring multiple repository calls,
    // consider implementing custom repository methods
    userRepository.updateUserStatus(email, "ACTIVE");
    userRepository.updateLastLogin(email, new Date());
}
```

## Performance Optimization

### Connection Pooling

HikariCP is automatically configured for optimal performance:

```properties
# Optimize for your application
jazzy.datasource.hikari.maximum-pool-size=20
jazzy.datasource.hikari.minimum-idle=5
jazzy.datasource.hikari.connection-timeout=30000
```

### Query Optimization

```java
// Use specific queries instead of findAll()
List<User> findByActive(boolean active);  // Better than findAll() + filter

// Use count queries for existence checks
boolean existsByEmail(String email);  // Better than findByEmail().isPresent()

// Use batch operations for multiple inserts
List<User> saveAll(Iterable<User> users);
```

### Lazy Loading

```java
@Entity
public class User {
    @OneToMany(mappedBy = "user", fetch = FetchType.LAZY)  // Lazy by default
    private List<Post> posts;
    
    @ManyToOne(fetch = FetchType.EAGER)  // Only when always needed
    private Department department;
}
```

## Error Handling

The framework provides automatic error handling for common database scenarios:

```java
try {
    User user = userService.createUser(name, email, password);
    return Response.json(JSON.of("user", user));
} catch (IllegalArgumentException e) {
    // Business logic errors (e.g., duplicate email)
    return Response.json(JSON.of("error", e.getMessage())).status(400);
} catch (Exception e) {
    // Database errors are automatically handled by framework
    return Response.json(JSON.of("error", "Internal server error")).status(500);
}
```

## Migration from Manual Data Handling

If you're migrating from manual data handling to database integration:

### Before (Manual)

```java
@Component
public class UserService {
    private final List<User> users = new ArrayList<>();
    
    public User createUser(String name, String email) {
        User user = new User(name, email);
        users.add(user);
        return user;
    }
    
    public Optional<User> findByEmail(String email) {
        return users.stream()
            .filter(u -> u.getEmail().equals(email))
            .findFirst();
    }
}
```

### After (Database)

```java
@Component
public class UserService {
    private final UserRepository userRepository;
    
    public UserService(UserRepository userRepository) {
        this.userRepository = userRepository;
    }
    
    public User createUser(String name, String email) {
        User user = new User(name, email);
        return userRepository.save(user);  // Automatically persisted
    }
    
    public Optional<User> findByEmail(String email) {
        return userRepository.findByEmail(email);  // Database query
    }
}
```

## Best Practices

### 1. Repository Design

```java
// Good: Specific, focused repository
public interface UserRepository extends BaseRepository<User, Long> {
    Optional<User> findByEmail(String email);
    List<User> findByActive(boolean active);
    long countByDepartment(String department);
}

// Avoid: Generic, unfocused repository
public interface DataRepository extends BaseRepository<Object, Long> {
    // Too generic, hard to maintain
}
```

### 2. Service Layer

```java
// Good: Business logic in service layer
@Component
public class UserService {
    public User createUser(String name, String email) {
        // Validation
        if (userRepository.existsByEmail(email)) {
            throw new IllegalArgumentException("Email already exists");
        }
        
        // Business logic
        User user = new User(name, email);
        user.setCreatedAt(new Date());
        
        return userRepository.save(user);
    }
}

// Avoid: Business logic in controller
@Component
public class UserController {
    public Response createUser(Request request) {
        // Don't put business logic here
        User user = request.toObject(User.class);
        return Response.json(userRepository.save(user));
    }
}
```

### 3. Entity Design

```java
// Good: Proper JPA annotations
@Entity
@Table(name = "users", indexes = {
    @Index(name = "idx_user_email", columnList = "email"),
    @Index(name = "idx_user_active", columnList = "active")
})
public class User {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    
    @Column(unique = true, nullable = false, length = 255)
    private String email;
    
    @Column(nullable = false, length = 100)
    private String name;
    
    // Proper getters and setters
}
```

## Troubleshooting

### Common Issues

**1. "No repository found" error**
- Ensure your repository interface extends `BaseRepository`
- Check that your repository is in a package that gets scanned

**2. "Entity not found" error**
- Verify your entity has `@Entity` annotation
- Check that entity is in a package that gets scanned

**3. Database connection errors**
- Verify `application.properties` configuration
- Check database driver is in classpath
- Ensure database server is running (for external databases)

**4. Query parsing errors**
- Check method name follows naming conventions
- Use `@Query` annotation for complex queries
- Verify parameter names match method parameters

### Debug Mode

Enable debug logging to troubleshoot issues:

```properties
# Enable SQL logging
jazzy.jpa.show-sql=true
jazzy.jpa.hibernate.format_sql=true

# Enable Hibernate logging
logging.level.org.hibernate.SQL=DEBUG
logging.level.org.hibernate.type.descriptor.sql.BasicBinder=TRACE
```

## Next Steps

- [Repository Pattern](repositories.md) - Deep dive into repository interfaces
- [Query Methods](query-methods.md) - Method name parsing and custom queries
- [Database Examples](database-examples.md) - Complete working examples 