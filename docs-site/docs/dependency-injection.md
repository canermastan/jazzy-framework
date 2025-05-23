# Dependency Injection

Jazzy Framework 0.2 introduces a powerful Spring-like dependency injection (DI) system that automatically manages object creation, dependency resolution, and lifecycle management. The DI system provides zero-configuration automatic component discovery and enterprise-level features.

## Overview

The DI system is built on top of PicoContainer but provides a much more developer-friendly API with annotations and automatic configuration. Key features include:

- **Automatic Component Discovery**: No manual configuration required
- **Constructor Injection**: Dependencies injected via constructor parameters  
- **Named Injection**: Multiple implementations of same interface
- **Primary Bean Selection**: Conflict resolution with `@Primary`
- **Lifecycle Management**: `@PostConstruct` and `@PreDestroy` callbacks
- **Scope Management**: Singleton and Prototype scopes
- **Zero Configuration**: Works out of the box

## Quick Start

### 1. Create a Component

```java
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
```

### 2. Create a Repository

```java
@Component
public class UserRepository {
    private final List<User> users = new ArrayList<>();
    
    @PostConstruct
    public void init() {
        // Called after bean creation
        System.out.println("UserRepository initialized");
    }
    
    public List<User> findAll() {
        return new ArrayList<>(users);
    }
}
```

### 3. Create a Controller

```java
@Component
public class UserController {
    private final UserService userService;
    
    public UserController(UserService userService) {
        this.userService = userService;
    }
    
    public Response getUsers(Request request) {
        return Response.json(userService.getAllUsers());
    }
}
```

### 4. Use in Your Application

```java
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

## Annotations

### @Component

Marks a class as a component that should be managed by the DI container.

```java
@Component
public class EmailService {
    // Component logic
}

// With custom name
@Component("customEmailService")
public class EmailService {
    // Component logic
}
```

### @Named

Provides a specific name for a component, useful when you have multiple implementations:

```java
@Component
@Named("emailService")
public class EmailNotificationService implements NotificationService {
    // Email implementation
}

@Component  
@Named("smsService")
public class SmsNotificationService implements NotificationService {
    // SMS implementation
}

// Inject specific implementation
@Component
public class UserService {
    public UserService(@Named("emailService") NotificationService notificationService) {
        // Will inject EmailNotificationService
    }
}
```

### @Primary

Marks a bean as primary when multiple candidates exist:

```java
@Component
@Primary
public class DatabaseUserRepository implements UserRepository {
    // Primary implementation
}

@Component
public class InMemoryUserRepository implements UserRepository {
    // Alternative implementation  
}

// UserService will get DatabaseUserRepository injected automatically
@Component
public class UserService {
    public UserService(UserRepository repository) {
        // DatabaseUserRepository will be injected due to @Primary
    }
}
```

### @PostConstruct

Method called after the bean is created and dependencies are injected:

```java
@Component
public class DatabaseService {
    private Connection connection;
    
    @PostConstruct
    public void initialize() {
        // Initialization code here
        connection = DriverManager.getConnection("...");
        // Load default data, connect to external services, etc.
    }
}
```

**Requirements:**
- Method must have no parameters
- Method must return void
- Can have multiple `@PostConstruct` methods

### @PreDestroy

Method called before the bean is destroyed (when server shuts down):

```java
@Component
public class DatabaseService {
    private Connection connection;
    
    @PreDestroy
    public void cleanup() {
        // Cleanup code here
        if (connection != null) {
            connection.close();
        }
    }
}
```

**Requirements:**
- Method must have no parameters  
- Method must return void
- Can have multiple `@PreDestroy` methods

### @Singleton (Default)

Ensures only one instance of the component exists:

```java
@Component
@Singleton  // This is the default behavior
public class ConfigurationService {
    // Only one instance will be created
}
```

### @Prototype

Creates a new instance every time the component is requested:

```java
@Component
@Prototype
public class RequestProcessor {
    // New instance created for each injection
}

@Component
public class RequestHandler {
    public RequestHandler(
        RequestProcessor processor1,  // New instance
        RequestProcessor processor2   // Different new instance
    ) {
        // processor1 != processor2
    }
}
```

## Advanced Usage

### Multiple Implementations with Named Injection

```java
// Define interface
public interface NotificationService {
    void send(String recipient, String message);
}

// Multiple implementations
@Component
@Named("emailService")
public class EmailNotificationService implements NotificationService {
    @Override
    public void send(String recipient, String message) {
        System.out.println("Sending email to: " + recipient);
    }
}

@Component
@Named("smsService") 
public class SmsNotificationService implements NotificationService {
    @Override
    public void send(String recipient, String message) {
        System.out.println("Sending SMS to: " + recipient);
    }
}

@Component
@Primary
public class PushNotificationService implements NotificationService {
    @Override
    public void send(String recipient, String message) {
        System.out.println("Sending push notification to: " + recipient);
    }
}

// Usage in components
@Component
public class NotificationManager {
    private final NotificationService defaultService;  // Gets @Primary (Push)
    private final NotificationService emailService;    // Gets @Named("emailService")
    private final NotificationService smsService;      // Gets @Named("smsService")
    
    public NotificationManager(
        NotificationService defaultService,              // @Primary injection
        @Named("emailService") NotificationService emailService,
        @Named("smsService") NotificationService smsService
    ) {
        this.defaultService = defaultService;
        this.emailService = emailService;
        this.smsService = smsService;
    }
    
    public void sendAll(String recipient, String message) {
        defaultService.send(recipient, message);
        emailService.send(recipient, message);
        smsService.send(recipient, message);
    }
}
```

### Lifecycle Management Example

```java
@Component
public class DatabaseService {
    private Connection connection;
    private boolean initialized = false;
    
    @PostConstruct
    public void initialize() {
        System.out.println("Initializing database connection...");
        // connection = DriverManager.getConnection(...);
        initialized = true;
        System.out.println("Database service initialized");
    }
    
    @PostConstruct
    public void loadDefaultData() {
        System.out.println("Loading default data...");
        // Load initial data
    }
    
    @PreDestroy
    public void cleanup() {
        System.out.println("Cleaning up database service...");
        if (connection != null) {
            // connection.close();
        }
        System.out.println("Database service cleaned up");
    }
    
    public boolean isReady() {
        return initialized;
    }
}
```

### Prototype Scope Example

```java
@Component
@Prototype
public class RequestProcessor {
    private final String instanceId;
    private int requestCount = 0;
    
    public RequestProcessor() {
        this.instanceId = UUID.randomUUID().toString();
        System.out.println("Created RequestProcessor: " + instanceId);
    }
    
    @PostConstruct
    public void init() {
        System.out.println("Initializing RequestProcessor: " + instanceId);
    }
    
    public void processRequest(String data) {
        requestCount++;
        System.out.println("Processing request #" + requestCount + " in " + instanceId);
    }
    
    public String getInstanceId() {
        return instanceId;
    }
}

@Component
public class RequestHandler {
    private final RequestProcessor processor1;
    private final RequestProcessor processor2;
    
    public RequestHandler(
        RequestProcessor processor1,  // New instance
        RequestProcessor processor2   // Different new instance  
    ) {
        this.processor1 = processor1;
        this.processor2 = processor2;
        
        // These will be different instances
        System.out.println("Processor 1 ID: " + processor1.getInstanceId());
        System.out.println("Processor 2 ID: " + processor2.getInstanceId());
    }
}
```

## How It Works

### 1. Automatic Component Discovery

The DI container automatically discovers components by:

1. **Main Class Detection**: Analyzes the stack trace to find the `main` method
2. **Package Scanning**: Scans the main class package and all sub-packages  
3. **Class Loading**: Loads all `.class` files and checks for `@Component` annotation
4. **Bean Registration**: Creates `BeanDefinition` objects for each component

### 2. Dependency Resolution

When creating instances:

1. **Constructor Analysis**: Examines constructor parameters
2. **Dependency Lookup**: Finds beans for each parameter type
3. **Named Resolution**: Uses `@Named` annotation if present
4. **Primary Selection**: Chooses `@Primary` bean if multiple candidates exist
5. **Recursive Creation**: Creates dependencies first, then the requesting bean

### 3. Lifecycle Management

1. **Creation Order**: Dependencies created before dependent beans
2. **PostConstruct**: Called after all dependencies are injected
3. **Singleton Caching**: Singleton instances stored for reuse
4. **PreDestroy**: Called when server shuts down

## Integration with Framework

The DI system is seamlessly integrated with the Jazzy Framework:

### Router Integration

Controllers are automatically created with dependency injection:

```java
// Define routes
router.GET("/users", "getUsers", UserController.class);
router.POST("/users", "createUser", UserController.class);

// When a request comes in:
// 1. Router finds the route
// 2. RequestHandler gets the controller class
// 3. DI container creates controller instance with dependencies
// 4. Method is invoked with proper Request object
```

### Server Integration

The server automatically initializes DI:

```java
public class Server {
    public Server(Router router, Config config) {
        // DI is automatically initialized
        this.diContainer = new DIContainer();
        this.router.setDIContainer(diContainer);
        diContainer.initialize();  // Discovers and registers all components
    }
}
```

## Migration from 0.1 to 0.2

If you're upgrading from Jazzy Framework 0.1:

### No Breaking Changes

All existing 0.1 code continues to work without modification. DI is additive.

### Adding DI to Existing Controllers

**Before (0.1):**
```java
public class UserController {
    private UserService userService = new UserService();
    
    public Response getUsers(Request request) {
        return Response.json(userService.getAllUsers());
    }
}
```

**After (0.2):**
```java
@Component
public class UserController {
    private final UserService userService;
    
    public UserController(UserService userService) {
        this.userService = userService;
    }
    
    public Response getUsers(Request request) {
        return Response.json(userService.getAllUsers());
    }
}
```

### Gradual Migration

You can migrate gradually:
- Add `@Component` to classes you want managed by DI
- Keep non-annotated classes as manual instantiation
- Mix DI and manual creation in the same application

## Best Practices

### 1. Constructor Injection

Always use constructor injection for required dependencies:

```java
@Component
public class UserService {
    private final UserRepository repository;
    private final EmailService emailService;
    
    // Good: Constructor injection
    public UserService(UserRepository repository, EmailService emailService) {
        this.repository = repository;
        this.emailService = emailService;
    }
}
```

### 2. Use Interfaces

Design with interfaces for better testability:

```java
public interface UserRepository {
    List<User> findAll();
    User findById(String id);
}

@Component
@Primary
public class DatabaseUserRepository implements UserRepository {
    // Production implementation
}

@Component  
public class InMemoryUserRepository implements UserRepository {
    // Test implementation
}
```

### 3. Named Injection for Multiple Implementations

Use `@Named` when you have multiple implementations:

```java
@Component
public class NotificationService {
    public NotificationService(
        @Named("emailService") EmailService emailService,
        @Named("smsService") SmsService smsService
    ) {
        // Clear which implementation you're getting
    }
}
```

### 4. Lifecycle Methods

Use lifecycle methods for proper initialization:

```java
@Component
public class CacheService {
    private Cache cache;
    
    @PostConstruct
    public void initialize() {
        cache = new Cache();
        cache.preload();
    }
    
    @PreDestroy
    public void cleanup() {
        cache.clear();
    }
}
```

### 5. Prototype for Stateful Objects

Use `@Prototype` for objects that maintain state:

```java
@Component
@Prototype
public class ShoppingCart {
    private List<Item> items = new ArrayList<>();
    
    // Each user gets their own cart instance
}
```

## Troubleshooting

### Multiple Beans Error

**Error:** "Multiple beans found for type X but no @Primary annotation"

**Solution:** Add `@Primary` to one implementation or use `@Named` injection:

```java
@Component
@Primary  // Add this
public class PreferredImplementation implements SomeInterface {
}

// OR use @Named injection
public SomeService(@Named("specific") SomeInterface implementation) {
}
```

### No Bean Found Error

**Error:** "No bean found with name: X"

**Solution:** 
1. Ensure the class has `@Component` annotation
2. Check the component name matches
3. Verify the class is in a scanned package

### Circular Dependencies

**Error:** PicoContainer circular dependency exception

**Solution:** Redesign to avoid circular dependencies:

```java
// Bad: A depends on B, B depends on A
@Component
public class ServiceA {
    public ServiceA(ServiceB serviceB) { }
}

@Component 
public class ServiceB {
    public ServiceB(ServiceA serviceA) { } // Circular!
}

// Good: Use a third service or event-driven approach
@Component
public class ServiceCoordinator {
    public ServiceCoordinator(ServiceA serviceA, ServiceB serviceB) {
        // Coordinate between A and B
    }
}
```

## Performance Considerations

- **Startup Time**: Component scanning happens once at startup
- **Memory Usage**: Singleton beans cached for lifetime of application
- **Thread Safety**: DI container is thread-safe, but your beans should be too
- **Reflection Overhead**: Minimal - only during bean creation, not on each request

The DI system is designed for production use and adds minimal overhead to your application. 