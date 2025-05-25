# Jazzy Framework

Jazzy is a lightweight, fast, and easy-to-use web framework developed in Java. Inspired by Laravel's elegant syntax, Jazzy brings modern, fluent APIs to the Java world with enterprise-level dependency injection capabilities and comprehensive database integration.

## 🚀 What's New in v0.3.0

**Major Database Integration Update!**

- 🗄️ **Full Database Integration**: Hibernate/JPA support with zero configuration
- 🔍 **Spring Data JPA-like Repositories**: Automatic query generation from method names
- 📝 **Custom Query Support**: @Query annotation for HQL/JPQL and native SQL
- 🔄 **Transaction Management**: Automatic transaction handling with proper rollback
- 🏗️ **Entity Discovery**: Automatic entity scanning and configuration
- 📊 **Connection Pooling**: HikariCP for production-ready database connections

## Key Features

- **Lightweight Architecture**: Provides core functionality with minimal dependencies
- **Fluent API**: Easy and readable coding with Laravel-like fluent interfaces
- **Request Processing**: Easily process request parameters, body, and headers
- **Response Generation**: Create JSON, HTML, and other response types
- **JSON Operations**: Easy JSON creation and processing capabilities
- **Validation System**: Built-in request validation with custom rules
- **Dependency Injection**: Enterprise-level DI container with automatic component scanning
- **Database Integration**: Full ORM support with Spring Data JPA-like repositories
- **Entity Management**: Automatic entity discovery and configuration
- **Query Generation**: Automatic query generation from method names
- **Custom Queries**: Support for complex HQL/JPQL and native SQL queries
- **Transaction Management**: Automatic transaction handling
- **Connection Pooling**: Production-ready database connection management

## Quick Start

### 1. Add Dependency

```xml
<dependency>
    <groupId>com.jazzyframework</groupId>
    <artifactId>jazzy-framework</artifactId>
    <version>0.3.0</version>
</dependency>
```

### 2. Create Your First Application

```java
import jazzyframework.core.Config;
import jazzyframework.core.Server;
import jazzyframework.routing.Router;
import jazzyframework.http.Request;
import jazzyframework.http.Response;
import jazzyframework.http.JSON;
import jazzyframework.di.annotations.Component;

public class MyApp {
    public static void main(String[] args) {
        Config config = new Config();
        config.setEnableMetrics(true);  // Enables "/metrics" endpoint automatically
        config.setServerPort(8080);
        
        Router router = new Router();
        
        // Controller-based routes with dependency injection
        router.GET("/users", "getAllUsers", UserController.class);
        router.GET("/users/{id}", "getUserById", UserController.class);
        router.POST("/users", "createUser", UserController.class);
        router.PUT("/users/{id}", "updateUser", UserController.class);
        router.DELETE("/users/{id}", "deleteUser", UserController.class);
        
        Server server = new Server(router, config);
        server.start(config.getServerPort());
    }
}

// Example Controller with Dependency Injection
@Component
public class UserController {
    private final UserService userService;
    
    public UserController(UserService userService) {
        this.userService = userService;
    }
    
    public Response getAllUsers(Request request) {
        List<User> users = userService.findAllUsers();
        return Response.json(JSON.of(
            "users", users, 
            "count", users.size()
            ));
    }
    
    public Response createUser(Request request) {
        User user = request.toObject(User.class);
        User createdUser = userService.createUser(user.getName(), user.getEmail());
        return Response.json(JSON.of("user", createdUser)).status(201);
    }

    public Response getUserById(Request request) {
        Long id = Long.parseLong(request.path("id"));
        Optional<User> user = userService.findById(id);
        
        if (user.isPresent()) {
            return Response.json(JSON.of("user", user.get()));
        }
        return Response.json(JSON.of("error", "User not found")).status(404);
    }
    
    public Response updateUser(Request request) {
        Long id = Long.parseLong(request.path("id"));
        User user = request.toObject(User.class);
        User updatedUser = userService.updateUser(id, user);
        return Response.json(JSON.of("user", updatedUser));
    }
    
    public Response deleteUser(Request request) {
        Long id = Long.parseLong(request.path("id"));
        userService.deleteUser(id);
        return Response.json(JSON.of("message", "User deleted successfully"));
    }
}

### 3. Database Integration (NEW!)

**Configure Database:**
```properties
# application.properties
jazzy.datasource.url=jdbc:h2:mem:testdb
jazzy.datasource.username=sa
jazzy.datasource.password=
jazzy.jpa.hibernate.ddl-auto=create-drop
```

**Create Entity:**
```java
@Entity
public class User {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    
    @Column(unique = true)
    private String email;
    private String name;
    
    // constructors, getters, setters...
}
```

**Create Repository:**
```java
public interface UserRepository extends BaseRepository<User, Long> {
    Optional<User> findByEmail(String email);
    List<User> findByActive(boolean active);
    
    @Query("SELECT u FROM User u WHERE u.name LIKE %:name%")
    List<User> searchByName(String name);
}
```

**Use in Service:**
```java
@Component
public class UserService {
    private final UserRepository userRepository;
    
    public UserService(UserRepository userRepository) {
        this.userRepository = userRepository;
    }
    
    public User createUser(String name, String email) {
        User user = new User(name, email);
        return userRepository.save(user);
    }
}
```

## Architecture Overview

Jazzy Framework follows a clean, modular architecture:

```
┌─────────────────────────────────────────────────────────────┐
│                    Jazzy Framework                          │
├─────────────────────────────────────────────────────────────┤
│  🌐 HTTP Layer                                              │
│  ├── Routing & Request Handling                             │
│  ├── Response Generation                                     │
│  └── Validation System                                      │
├─────────────────────────────────────────────────────────────┤
│  🔧 Dependency Injection                                    │
│  ├── Component Scanning                                     │
│  ├── Automatic Wiring                                       │
│  └── Lifecycle Management                                   │
├─────────────────────────────────────────────────────────────┤
│  🗄️ Database Integration (NEW in 0.3.0)                    │
│  ├── Entity Management                                      │
│  ├── Repository Pattern                                     │
│  ├── Query Generation                                       │
│  └── Transaction Management                                 │
├─────────────────────────────────────────────────────────────┤
│  🛠️ Utilities                                               │
│  ├── JSON Processing                                        │
│  ├── Configuration Management                               │
│  └── Logging & Metrics                                      │
└─────────────────────────────────────────────────────────────┘
```

## Why Choose Jazzy?

### 🚀 **Developer Productivity**
- Minimal boilerplate code
- Intuitive, Laravel-inspired API
- Automatic dependency injection
- Zero-configuration database setup

### 🏗️ **Enterprise Ready**
- Production-ready dependency injection
- Comprehensive database integration
- Automatic transaction management
- Connection pooling with HikariCP

### 🔧 **Modern Java Development**
- Clean, readable code patterns
- Type-safe repository interfaces
- Automatic query generation
- Support for modern Java features

### 📈 **Performance Focused**
- Lightweight core with minimal overhead
- Efficient database operations
- Optimized connection pooling
- Database-level query optimization

## Learning Path

### 🌱 **Beginner**
1. [Getting Started](getting-started.md) - Set up your first Jazzy application
2. [Routing](routing.md) - Learn URL routing and HTTP methods
3. [Requests & Responses](requests.md) - Handle HTTP requests and responses

### 🌿 **Intermediate**
4. [Dependency Injection](dependency-injection.md) - Master the DI container
5. [Database Integration](database-integration.md) - Set up database connectivity
6. [Repository Pattern](repositories.md) - Create data access layers

### 🌳 **Advanced**
7. [Query Methods](query-methods.md) - Advanced database querying
8. [Validation](validation.md) - Request validation and error handling
9. [Examples](examples.md) - Real-world application examples

## Community & Support

- **GitHub**: [JazzyFramework Repository](https://github.com/canermastan/jazzy-framework)
- **Documentation**: Complete guides and API reference
- **Examples**: Working code samples and tutorials
- **Issues**: Bug reports and feature requests

## Version History

- **v0.3.0** (Current) - Database Integration & ORM Support
- **v0.2.0** - Dependency Injection & Component System
- **v0.1.0** - Core HTTP Framework & Routing

---

Ready to build amazing applications with Jazzy? Start with our [Getting Started Guide](getting-started.md)! 