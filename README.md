# Jazzy Framework

Jazzy is a lightweight web framework for Java. It provides a minimal and easy-to-understand API for developing fast web applications with a structure inspired by Laravel and Spring Boot.

## 🚀 Latest Updates (v0.2.0)

**NEW: Enterprise-Level Dependency Injection System!**

Jazzy Framework 0.2 introduces a comprehensive Spring-like dependency injection system with zero configuration:

- 🔧 **Zero Configuration DI**: Automatic component discovery
- 📦 **Spring-like Annotations**: @Component, @Named, @Primary, @PostConstruct, @PreDestroy
- 🔌 **Constructor Injection**: Clean, testable dependency injection  
- ⚖️ **Multiple Implementations**: Handle conflicts with @Named and @Primary
- 🔄 **Lifecycle Management**: Proper initialization and cleanup
- 📊 **Scope Management**: @Singleton and @Prototype support
- 🔗 **Framework Integration**: Seamless integration with routing and controllers

## Version History

| Version | Release Date | Key Features |
|---------|-------------|--------------|
| **0.2.0** | 2025 | 🆕 **Dependency Injection System**, Spring-like annotations, automatic component discovery, lifecycle management |
| **0.1.0** | 2025 | Core framework with routing, request/response handling, JSON utilities, validation system, metrics |

### 🔮 Upcoming Features (Roadmap)

| Planned Version | Features |
|----------------|----------|
| **0.3.0** | 🗄️ **Database Integration** - jOOQ integration, connection pooling, transaction management |

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

## Quick Start

### Basic Application (v0.1 style)

```java
// App.java
package examples.basic;

import jazzyframework.core.Config;
import jazzyframework.core.Server;
import jazzyframework.routing.Router;

public class App 
{
    public static void main( String[] args )
    {
        Config config = new Config();
        config.setEnableMetrics(true); // "/metrics" endpoint is automatically added
        config.setServerPort(8088);

        Router router = new Router();
        
        // User routes
        router.GET("/users/{id}", "getUserById", UserController.class);
        router.GET("/users", "getAllUsers", UserController.class);
        router.POST("/users", "createUser", UserController.class);
        router.PUT("/users/{id}", "updateUser", UserController.class);
        router.DELETE("/users/{id}", "deleteUser", UserController.class);
        
        // Start the server
        Server server = new Server(router, config);
        server.start(config.getServerPort());
    }
}
```

### With Dependency Injection (v0.2 style)

```java
// Repository Component
@Component
public class UserRepository {
    private final List<User> users = new ArrayList<>();
    
    @PostConstruct
    public void init() {
        System.out.println("UserRepository initialized");
    }
    
    public List<User> findAll() {
        return new ArrayList<>(users);
    }
}

// Service Component  
@Component
public class UserService {
    private final UserRepository repository;
    
    // Constructor injection - DI container automatically injects UserRepository
    public UserService(UserRepository repository) {
        this.repository = repository;
    }
    
    public List<User> getAllUsers() {
        return repository.findAll();
    }
}

// Controller Component
@Component
public class UserController {
    private final UserService userService;
    
    // Constructor injection - DI container automatically injects UserService
    public UserController(UserService userService) {
        this.userService = userService;
    }

    public Response getUsers(Request request) {
        return Response.json(userService.getAllUsers());
    }
}

// Application - DI works automatically!
public class App {
    public static void main(String[] args) {
        Config config = new Config();
        Router router = new Router();
        
        // Define routes - controllers will be created with DI
        router.GET("/users", "getUsers", UserController.class);
        
        // DI is automatically enabled and configured
        Server server = new Server(router, config);
        server.start(8080);
    }
}
```

That's it! The DI container automatically:
- Discovers all `@Component` classes
- Resolves dependencies between them  
- Creates instances with proper injection
- Manages lifecycle callbacks

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
```

## Project Structure

- `core/`: Core framework components
  - `Server.java`: HTTP server with automatic DI initialization
  - `RequestHandler.java`: HTTP request processor with DI integration
  - `Config.java`: Configuration management
  - `Metrics.java`: Performance metrics
- `routing/`: Routing system
  - `Router.java`: Route management with DI container support
  - `Route.java`: Route data structure
- `http/`: HTTP handling
  - `Request.java`: Request handling
  - `Response.java`: Response building
  - `ResponseFactory.java`: Factory for creating responses
  - `JSON.java`: JSON creation utilities
  - `validation/`: Validation system
- `di/`: Dependency injection system (v0.2+)
  - `DIContainer.java`: Main DI container with automatic discovery
  - `ComponentScanner.java`: Automatic component scanning
  - `BeanDefinition.java`: Bean metadata and lifecycle management
  - `annotations/`: DI annotations (@Component, @Named, @Primary, etc.)
- `controllers/`: System controllers
  - `MetricsController.java`: Metrics reporting
- `examples/`: Example applications
  - `basic/`: A simple web API example (v0.1 style)
  - `di/`: Dependency injection example (v0.2 style)

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

### Getting Started

1. Fork the project
2. Clone your fork (`git clone https://github.com/canermastan/jazzy-framework.git`)
3. Create a feature branch (`git checkout -b feature/amazing-feature`)
4. Make your changes (don't forget to add tests if applicable)
5. Run tests to make sure everything works (`mvn test`)
6. Commit your changes (`git commit -m 'Add some amazing feature'`)
7. Push to the branch (`git push origin feature/amazing-feature`)
8. Open a Pull Request

### Pull Request Guidelines

- Keep your changes focused on a single issue
- Make sure all tests pass
- Update documentation if needed
- Follow existing code style

No contribution is too small, and we're happy to help newcomers get started!

## License

MIT License 