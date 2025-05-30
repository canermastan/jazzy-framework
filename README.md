# Jazzy Framework

Jazzy is a lightweight web framework for Java. It provides a minimal and easy-to-understand API for developing fast web applications with a structure inspired by Laravel and Spring Boot.

## 🚀 Latest Updates (v0.4.0)

**NEW: Auto-CRUD System with Zero Boilerplate!**

Jazzy Framework 0.4 introduces revolutionary auto-CRUD capabilities that generate complete REST APIs with just annotations:

- 🎯 **@Crud Annotation**: Automatically generates all CRUD endpoints (GET, POST, PUT, DELETE)
- 🔍 **Smart Search**: Built-in search functionality with configurable fields
- 📊 **Pagination Support**: Automatic pagination with customizable page sizes
- 🔄 **Batch Operations**: Support for bulk create, update, delete operations
- 🎨 **Method Override**: Custom logic with @CrudOverride annotation
- 📝 **Standardized Responses**: Consistent API response format with ApiResponse
- ⚡ **Zero Configuration**: Complete REST API with 3 lines of code
- 🔧 **Highly Configurable**: Fine-tune behavior with comprehensive options

## Version History

| Version | Release Date | Key Features |
|---------|-------------|--------------|
| **0.4.0** | 2025 | 🆕 **Auto-CRUD System** - @Crud annotation, zero-boilerplate REST APIs, automatic endpoint generation, search & pagination |
| **0.3.0** | 2025 | 🆕 **Database Integration** - Hibernate/JPA, Spring Data JPA-like repositories, automatic query generation, transaction management |
| **0.2.0** | 2025 | 🆕 **Dependency Injection System**, Spring-like annotations, automatic component discovery, lifecycle management |
| **0.1.0** | 2025 | Core framework with routing, request/response handling, JSON utilities, validation system, metrics |

### 🔮 Upcoming Features (Roadmap)

| Planned Version | Features |
|----------------|----------|
| **0.5.0** | 🔐 **Security & Authentication** - JWT support, role-based access control, security filters |

## Features

### Core Framework (v0.1+)
- Simple and intuitive API
- Routing system with HTTP method support (GET, POST, PUT, DELETE, PATCH)
- URL path parameter support
- Request validation with comprehensive rules
- JSON response generation with fluent API
- Metrics collection and reporting

### Dependency Injection (v0.2+)
- **Zero Configuration**: Automatic component discovery with no setup
- **Constructor Injection**: Dependencies injected via constructor parameters
- **Named Injection**: Multiple implementations of same interface with @Named
- **Primary Bean Selection**: Conflict resolution with @Primary annotation
- **Lifecycle Management**: @PostConstruct and @PreDestroy callbacks
- **Scope Management**: @Singleton (default) and @Prototype scopes
- **Framework Integration**: DI works seamlessly with controllers and routing

### Database Integration (v0.3+)
- **Hibernate/JPA Integration**: Full ORM support with automatic configuration
- **Spring Data JPA-like Repositories**: Familiar repository pattern with automatic implementation
- **Method Name Parsing**: Automatic query generation from method names
- **Custom Queries**: @Query annotation for HQL/JPQL and native SQL queries
- **Transaction Management**: Automatic transaction handling with proper rollback
- **Entity Discovery**: Automatic entity scanning and configuration
- **Connection Pooling**: HikariCP for production-ready database connections

### Auto-CRUD System (v0.4+)
- **@Crud Annotation**: Automatically generates complete REST APIs with zero boilerplate
- **Instant Endpoints**: GET, POST, PUT, DELETE endpoints created automatically
- **Smart Search**: Built-in search functionality with configurable searchable fields
- **Pagination Support**: Automatic pagination with customizable page sizes and limits
- **Batch Operations**: Bulk create, update, delete operations for performance
- **Method Override**: Custom business logic with @CrudOverride annotation
- **Standardized Responses**: Consistent ApiResponse format across all endpoints
- **Highly Configurable**: Fine-tune behavior with extensive configuration options
- **Validation Integration**: Built-in input validation for create/update operations
- **Audit Logging**: Optional audit trail for all CRUD operations

## Quick Start

### Auto-CRUD Application (v0.4 style) - Recommended

```java
// 1. Entity
@Entity
@Table(name = "products")
public class Product {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    
    private String name;
    private String description;
    private Double price;
    private Integer stock;
    
    // getters and setters...
}

// 2. Repository
@Component
public interface ProductRepository extends BaseRepository<Product, Long> {
    // Framework handles all basic operations automatically
}

// 3. Controller - That's it! Full REST API with 3 lines!
@Component
@Crud(
    entity = Product.class,
    endpoint = "/api/products",
    enablePagination = true,
    enableSearch = true,
    searchableFields = {"name", "description"}
)
public class ProductController {
    // Instantly get all these endpoints:
    // GET    /api/products       - List all products (with pagination)
    // GET    /api/products/{id}  - Get product by ID
    // POST   /api/products       - Create new product
    // PUT    /api/products/{id}  - Update product
    // DELETE /api/products/{id}  - Delete product
    // GET    /api/products/search?name=laptop - Search products
}

// 4. Main Application
public class App {
    public static void main(String[] args) {
        Config config = new Config();
        Router router = new Router();
        
        // No manual route registration needed!
        // @Crud annotation handles everything automatically
        
        Server server = new Server(router, config);
        server.start(8080);
    }
}
```

**🎉 Result**: You now have a complete REST API with 5+ endpoints, pagination, search, and standardized responses!

### Database Application (v0.3 style)

```java
// Entity
@Entity
@Table(name = "users")
public class User {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    
    @Column(unique = true)
    private String email;
    
    private String name;
    private String password;
    private boolean active = true;
    
    // getters and setters...
}

// Repository with automatic query generation
public interface UserRepository extends BaseRepository<User, Long> {
    // Automatic query: SELECT u FROM User u WHERE u.email = :email
    Optional<User> findByEmail(String email);
    
    // Automatic query: SELECT u FROM User u WHERE u.active = :active
    List<User> findByActive(boolean active);
    
    // Automatic query: SELECT COUNT(u) FROM User u WHERE u.active = :active
    long countByActive(boolean active);
    
    // Custom query with @Query annotation
    @Query("SELECT u FROM User u WHERE u.email = :email AND u.active = true")
    Optional<User> findActiveUserByEmail(String email);
    
    // Native SQL query
    @Query(value = "SELECT * FROM users WHERE email = ?1", nativeQuery = true)
    Optional<User> findByEmailNative(String email);
    
    // Update query
    @Query("UPDATE User u SET u.active = :active WHERE u.email = :email")
    @Modifying
    int updateUserActiveStatus(String email, boolean active);
}

// Service
@Component
public class UserService {
    private final UserRepository userRepository;
    
    public UserService(UserRepository userRepository) {
        this.userRepository = userRepository;
    }
    
    public User createUser(String name, String email, String password) {
        // Check if user already exists
        if (userRepository.findByEmail(email).isPresent()) {
            throw new IllegalArgumentException("User with email " + email + " already exists");
        }
        
        User user = new User();
        user.setName(name);
        user.setEmail(email);
        user.setPassword(password);
        
        return userRepository.save(user);
    }
    
    public Optional<User> findByEmail(String email) {
        return userRepository.findByEmail(email);
    }
    
    public List<User> findAllUsers() {
        return userRepository.findAll();
    }
}

// Controller
@Component
public class UserController {
    private final UserService userService;
    
    public UserController(UserService userService) {
        this.userService = userService;
    }
    
    public Response createUser(Request request) {
        User user = request.toObject(User.class);
        User createdUser = userService.createUser(user.getName(), user.getEmail(), user.getPassword());
        return Response.json(JSON.of("result", createdUser));
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
}

// Main class
public class App {
    public static void main(String[] args) {
        Config config = new Config();
        config.setEnableMetrics(true);
        config.setServerPort(8080);
        
        Router router = new Router();
        
        // User routes
        router.GET("/users", "getAllUsers", UserController.class);
        router.GET("/users/search", "getUserByEmail", UserController.class);
        router.POST("/users", "createUser", UserController.class);
        
        Server server = new Server(router, config);
        server.start(config.getServerPort());
    }
}
```

### Configuration (application.properties)

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

That's it! The framework automatically:
- Discovers entities and repositories
- Creates repository implementations with query parsing
- Manages database connections and transactions
- Provides Spring Data JPA-like functionality

## Documentation

Complete documentation for Jazzy Framework is available on our GitHub Pages site:

[Jazzy Framework Documentation](https://canermastan.github.io/jazzy-framework/)

### Documentation Sections

**Core Framework:**
- [Getting Started Guide](https://canermastan.github.io/jazzy-framework/getting-started)
- [Routing](https://canermastan.github.io/jazzy-framework/routing) 
- [HTTP Requests](https://canermastan.github.io/jazzy-framework/requests)
- [HTTP Responses](https://canermastan.github.io/jazzy-framework/responses)
- [JSON Operations](https://canermastan.github.io/jazzy-framework/json)
- [Validation](https://canermastan.github.io/jazzy-framework/validation)

**Dependency Injection (v0.2+):**
- [Dependency Injection Guide](https://canermastan.github.io/jazzy-framework/dependency-injection)
- [DI Examples](https://canermastan.github.io/jazzy-framework/di-examples)

**Database Integration (v0.3+):**
- [Database Integration Guide](https://canermastan.github.io/jazzy-framework/database-integration)
- [Repository Pattern](https://canermastan.github.io/jazzy-framework/repositories)
- [Query Methods](https://canermastan.github.io/jazzy-framework/query-methods)

**Auto-CRUD System (v0.4+):**
- [CRUD Operations Guide](https://canermastan.github.io/jazzy-framework/crud)

## Development

Jazzy is developed with Maven. After cloning the project, you can use the following commands:

```bash
# Install dependencies and build the project
mvn clean install

# Run tests
mvn test

# Run the basic example application
mvn exec:java -Dexec.mainClass="examples.basic.App"

# Run the DI example application (v0.2+)
mvn exec:java -Dexec.mainClass="examples.di.App"

# Run the database example application (v0.3+)
mvn exec:java -Dexec.mainClass="examples.database.DatabaseExampleApp"

# Run the CRUD example application (v0.4+) - RECOMMENDED
mvn exec:java -Dexec.mainClass="examples.simple_crud.SimpleCrudApp"
```

## Project Structure

- `core/`: Core framework components
  - `Server.java`: HTTP server with automatic DI initialization
  - `RequestHandler.java`: HTTP request processor with DI integration
  - `Config.java`: Configuration management
  - `Metrics.java`: Performance metrics
  - `PropertyLoader.java`: Configuration property management (v0.3+)
- `routing/`: Routing system
  - `Router.java`: Route management with DI container support
  - `Route.java`: Route data structure
- `http/`: HTTP handling
  - `Request.java`: Request handling
  - `Response.java`: Response building
  - `ResponseFactory.java`: Factory for creating responses
  - `ApiResponse.java`: Standardized API response format (v0.4+)
  - `JSON.java`: JSON creation utilities
  - `validation/`: Validation system
- `di/`: Dependency injection system (v0.2+)
  - `DIContainer.java`: Main DI container with automatic discovery
  - `ComponentScanner.java`: Automatic component scanning
  - `BeanDefinition.java`: Bean metadata and lifecycle management
  - `annotations/`: DI annotations (@Component, @Named, @Primary, etc.)
- `data/`: Database integration system (v0.3+)
  - `BaseRepository.java`: Base repository interface
  - `BaseRepositoryImpl.java`: Default repository implementation
  - `RepositoryFactory.java`: Repository proxy creation
  - `QueryMethodParser.java`: Method name to query parsing
  - `HibernateConfig.java`: Hibernate/JPA configuration
  - `EntityScanner.java`: Automatic entity discovery
  - `RepositoryScanner.java`: Repository interface scanning
  - `CrudProcessor.java`: Auto-CRUD system processor (v0.4+)
  - `annotations/`: Database annotations (@Query, @Modifying, @QueryHint, @Crud, @CrudOverride)
- `controllers/`: System controllers
  - `MetricsController.java`: Metrics reporting
- `examples/`: Example applications
  - `basic/`: Basic framework usage examples
  - `di/`: Dependency injection examples (v0.2+)
  - `database/`: Database integration examples (v0.3+)
  - `simple_crud/`: Auto-CRUD system examples (v0.4+)

## Tests

Comprehensive unit tests ensure the reliability of the framework. Test coverage includes:

**Core Framework Tests:**
- `RouterTest`: Tests for adding routes, finding routes, and path parameter operations
- `RouteTest`: Tests for the route data structure
- `MetricsTest`: Tests for metric counters and calculations
- `ValidationTest`: Tests for the validation system
- `ResponseFactoryTest`: Tests for response generation

**Dependency Injection Tests (v0.2+):**
- `DIContainerTest`: Tests for DI container functionality and lifecycle
- `ComponentScannerTest`: Tests for automatic component discovery
- `BeanDefinitionTest`: Tests for bean metadata extraction
- `DIIntegrationTest`: Tests for real-world DI scenarios
- `AnnotationTest`: Tests for all DI annotations

**137 total tests** covering all framework features with comprehensive edge case testing.

## Migration Guide

### From 0.1 to 0.2

**Good news: Zero breaking changes!** All existing 0.1 code continues to work without modification.

**To use new DI features:**
1. Add `@Component` annotation to classes you want managed by DI
2. Use constructor injection for dependencies
3. Optionally use `@Named`, `@Primary`, `@PostConstruct`, `@PreDestroy` for advanced features

You can gradually migrate - mix DI and manual instantiation in the same application.

## Contributing

**Jazzy is actively maintained and we welcome contributions of any size!**

We believe that open source thrives with community involvement, and we appreciate all types of contributions, whether you're fixing a typo, improving documentation, adding a new feature, or reporting a bug.

### 📖 Complete Contributing Guide

For detailed contribution guidelines, development setup, and code standards, see our **[Contributing Guide](CONTRIBUTING.md)**.

### 🚀 Quick Start for Contributors

1. **Read our [Contributing Guide](CONTRIBUTING.md)** for detailed instructions
2. **Fork the project** and clone your fork
3. **Check out [good first issues](https://github.com/canermastan/jazzy-framework/issues?q=is%3Aissue+is%3Aopen+label%3A%22good+first+issue%22)** for beginner-friendly tasks
4. **Create a feature branch** (`git checkout -b feature/amazing-feature`)
5. **Make your changes** and add tests if applicable
6. **Run tests** to make sure everything works (`mvn test`)
7. **Commit your changes** following [Conventional Commits](https://www.conventionalcommits.org/)
8. **Push to your branch** and open a Pull Request

### 🤝 Community & Support

- 💬 **[GitHub Discussions](https://github.com/canermastan/jazzy-framework/discussions)** - Community help and general questions
- 🐛 **[Report Issues](https://github.com/canermastan/jazzy-framework/issues/new/choose)** - Bug reports and feature requests
- 📚 **[Documentation](https://canermastan.github.io/jazzy-framework/)** - Complete framework documentation
- 🎯 **[Good First Issues](https://github.com/canermastan/jazzy-framework/issues?q=is%3Aissue+is%3Aopen+label%3A%22good+first+issue%22)** - Perfect for newcomers

### 🏷️ Issue Templates

We have beginner-friendly issue templates to help you contribute:

- 🐛 **Bug Report** - Found something broken?
- 💡 **Feature Request** - Have an idea for improvement?
- ❓ **Question** - Need help with something?

No contribution is too small, and we're happy to help newcomers get started! 🚀

## License

MIT License 
