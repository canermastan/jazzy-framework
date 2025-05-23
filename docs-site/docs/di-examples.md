# Dependency Injection Examples

This page provides complete, runnable examples demonstrating the Jazzy Framework 0.2 dependency injection system. Each example builds upon the previous ones, showing progressively more advanced features.

## Basic Example: User Management System

This example demonstrates basic DI with components, constructor injection, and lifecycle management.

### Entity

```java
package examples.di.entity;

import jazzyframework.http.JSON;

public class User {
    private String id;
    private String name;
    private String email;
    private String password;

    public User() {}

    public User(String id, String name, String email, String password) {
        this.id = id;
        this.name = name;
        this.email = email;
        this.password = password;
    }

    // Getters and setters
    public String getId() { return id; }
    public void setId(String id) { this.id = id; }
    
    public String getName() { return name; }
    public void setName(String name) { this.name = name; }
    
    public String getEmail() { return email; }
    public void setEmail(String email) { this.email = email; }
    
    public String getPassword() { return password; }
    public void setPassword(String password) { this.password = password; }

    @Override
    public String toString() {
        return JSON.stringify(this);
    }
}
```

### Repository Component

```java
package examples.di.repository;

import examples.di.entity.User;
import jazzyframework.di.annotations.Component;
import jazzyframework.di.annotations.PostConstruct;

import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

@Component
public class UserRepository {
    private final List<User> users = new ArrayList<>();

    @PostConstruct
    public void init() {
        // Initialize with some sample data
        users.add(new User("1", "John Doe", "john@example.com", "password123"));
        users.add(new User("2", "Jane Smith", "jane@example.com", "password456"));
        System.out.println("UserRepository initialized with " + users.size() + " users");
    }

    public List<User> findAll() {
        return new ArrayList<>(users);
    }

    public Optional<User> findById(String id) {
        return users.stream().filter(u -> u.getId().equals(id)).findFirst();
    }

    public void save(User user) {
        users.removeIf(u -> u.getId().equals(user.getId()));
        users.add(user);
    }

    public boolean deleteById(String id) {
        return users.removeIf(u -> u.getId().equals(id));
    }
}
```

### Service Component

```java
package examples.di.service;

import examples.di.entity.User;
import examples.di.repository.UserRepository;
import jazzyframework.di.annotations.Component;

import java.util.List;
import java.util.Optional;
import java.util.UUID;

@Component
public class UserService {
    private final UserRepository userRepository;

    // Constructor injection - DI container will automatically inject UserRepository
    public UserService(UserRepository userRepository) {
        this.userRepository = userRepository;
        System.out.println("UserService created with injected UserRepository");
    }

    public List<User> getAllUsers() {
        return userRepository.findAll();
    }

    public Optional<User> getUserById(String id) {
        return userRepository.findById(id);
    }

    public User createUser(User user) {
        // Generate a new ID if not provided
        if (user.getId() == null || user.getId().isEmpty()) {
            user.setId(UUID.randomUUID().toString());
        }
        userRepository.save(user);
        return user;
    }

    public Optional<User> updateUser(String id, User updatedUser) {
        Optional<User> existingUser = userRepository.findById(id);
        if (existingUser.isPresent()) {
            updatedUser.setId(id);
            userRepository.save(updatedUser);
            return Optional.of(updatedUser);
        }
        return Optional.empty();
    }

    public boolean deleteUser(String id) {
        return userRepository.deleteById(id);
    }
}
```

### Controller Component

```java
package examples.di.controller;

import examples.di.entity.User;
import examples.di.service.UserService;
import jazzyframework.di.annotations.Component;
import jazzyframework.http.Request;
import jazzyframework.http.Response;

import java.util.Optional;

@Component
public class UserController {
    private final UserService userService;

    // Constructor injection - DI container will automatically inject UserService
    public UserController(UserService userService) {
        this.userService = userService;
        System.out.println("UserController created with injected UserService");
    }

    public Response getUsers(Request request) {
        return Response.json(userService.getAllUsers());
    }

    public Response getUserById(Request request) {
        String id = request.getPathParam("id");
        Optional<User> user = userService.getUserById(id);
        
        if (user.isPresent()) {
            // Hide password in the response
            User responseUser = user.get();
            responseUser.setPassword(null);
            return Response.json(responseUser);
        } else {
            return Response.notFound().json("{\"error\": \"User not found\"}");
        }
    }

    public Response createUser(Request request) {
        try {
            User user = request.getBody(User.class);
            User createdUser = userService.createUser(user);
            // Hide password in the response
            createdUser.setPassword(null);
            return Response.created().json(createdUser);
        } catch (Exception e) {
            return Response.badRequest().json("{\"error\": \"Invalid user data\"}");
        }
    }

    public Response updateUser(Request request) {
        String id = request.getPathParam("id");
        
        try {
            User user = request.getBody(User.class);
            Optional<User> updatedUser = userService.updateUser(id, user);
            
            if (updatedUser.isPresent()) {
                // Hide password in the response
                updatedUser.get().setPassword(null);
                return Response.json(updatedUser.get());
            } else {
                return Response.notFound().json("{\"error\": \"User not found\"}");
            }
        } catch (Exception e) {
            return Response.badRequest().json("{\"error\": \"Invalid user data\"}");
        }
    }

    public Response deleteUser(Request request) {
        String id = request.getPathParam("id");
        boolean deleted = userService.deleteUser(id);
        
        if (deleted) {
            return Response.noContent();
        } else {
            return Response.notFound().json("{\"error\": \"User not found\"}");
        }
    }
}
```

### Application

```java
package examples.di;

import examples.di.controller.UserController;
import jazzyframework.core.Config;
import jazzyframework.core.Server;
import jazzyframework.routing.Router;

public class App {
    public static void main(String[] args) {
        // Create simple configuration
        Config config = new Config();
        config.setEnableMetrics(true);

        // Create router and define routes
        Router router = new Router();

        // Define user routes
        // Controllers will automatically get dependencies injected
        router.GET("/users", "getUsers", UserController.class);
        router.GET("/users/{id}", "getUserById", UserController.class);
        router.POST("/users", "createUser", UserController.class);
        router.PUT("/users/{id}", "updateUser", UserController.class);
        router.DELETE("/users/{id}", "deleteUser", UserController.class);

        // Create and start server
        // DI will automatically discover and register all @Component classes
        Server server = new Server(router, config);

        System.out.println("🚀 Jazzy Framework DI Example Server starting...");
        System.out.println("📊 Metrics available at: http://localhost:8088/metrics");
        System.out.println("👤 User API available at: http://localhost:8088/users");
        System.out.println();
        System.out.println("Example API calls:");
        System.out.println("  curl http://localhost:8088/users");
        System.out.println("  curl http://localhost:8088/users/1");
        System.out.println("  curl -X POST -H \"Content-Type: application/json\" \\");
        System.out.println("       -d '{\"name\":\"Alice\",\"email\":\"alice@example.com\",\"password\":\"secret\"}' \\");
        System.out.println("       http://localhost:8088/users");

        server.start(8088);
    }
}
```

When you run this application, you'll see DI in action:

```
UserRepository initialized with 2 users
UserService created with injected UserRepository
UserController created with injected UserService
🚀 Jazzy Framework DI Example Server starting...
Server started on port 8088 with dependency injection
```

## Advanced Example: Multiple Implementations with Named Injection

This example shows how to handle multiple implementations of the same interface using `@Named` and `@Primary` annotations.

### Interface

```java
package examples.advanced.service;

public interface NotificationService {
    void send(String recipient, String message);
}
```

### Multiple Implementations

```java
package examples.advanced.service;

import jazzyframework.di.annotations.Component;
import jazzyframework.di.annotations.Named;
import jazzyframework.di.annotations.PostConstruct;

@Component
@Named("emailService")
public class EmailNotificationService implements NotificationService {
    
    @PostConstruct
    public void init() {
        System.out.println("EmailNotificationService initialized");
    }

    @Override
    public void send(String recipient, String message) {
        // Simulate email sending
        System.out.println("📧 Sending email to: " + recipient);
        System.out.println("   Message: " + message);
    }
}
```

```java
package examples.advanced.service;

import jazzyframework.di.annotations.Component;
import jazzyframework.di.annotations.Named;
import jazzyframework.di.annotations.PostConstruct;

@Component
@Named("smsService")
public class SmsNotificationService implements NotificationService {
    
    @PostConstruct
    public void init() {
        System.out.println("SmsNotificationService initialized");
    }

    @Override
    public void send(String recipient, String message) {
        // Simulate SMS sending
        System.out.println("📱 Sending SMS to: " + recipient);
        System.out.println("   Message: " + message);
    }
}
```

```java
package examples.advanced.service;

import jazzyframework.di.annotations.Component;
import jazzyframework.di.annotations.Primary;
import jazzyframework.di.annotations.PostConstruct;

@Component
@Primary
public class PushNotificationService implements NotificationService {
    
    @PostConstruct
    public void init() {
        System.out.println("PushNotificationService initialized (PRIMARY)");
    }

    @Override
    public void send(String recipient, String message) {
        // Simulate push notification sending
        System.out.println("🔔 Sending push notification to: " + recipient);
        System.out.println("   Message: " + message);
    }
}
```

### Manager Component with Named Injection

```java
package examples.advanced.service;

import jazzyframework.di.annotations.Component;
import jazzyframework.di.annotations.Named;

@Component
public class NotificationManager {
    private final NotificationService defaultService;  // Will get @Primary (Push)
    private final NotificationService emailService;    // Will get @Named("emailService")
    private final NotificationService smsService;      // Will get @Named("smsService")

    public NotificationManager(
        NotificationService defaultService,  // @Primary injection
        @Named("emailService") NotificationService emailService,
        @Named("smsService") NotificationService smsService
    ) {
        this.defaultService = defaultService;
        this.emailService = emailService;
        this.smsService = smsService;
        System.out.println("NotificationManager created with all notification services");
    }

    public void sendViaDefault(String recipient, String message) {
        defaultService.send(recipient, message);
    }

    public void sendViaEmail(String recipient, String message) {
        emailService.send(recipient, message);
    }

    public void sendViaSms(String recipient, String message) {
        smsService.send(recipient, message);
    }

    public void sendViaAll(String recipient, String message) {
        System.out.println("\n🚀 Sending via all notification services:");
        defaultService.send(recipient, message);
        emailService.send(recipient, message);
        smsService.send(recipient, message);
    }
}
```

### Prototype Scope Example

```java
package examples.advanced.service;

import jazzyframework.di.annotations.Component;
import jazzyframework.di.annotations.PostConstruct;
import jazzyframework.di.annotations.Prototype;

import java.util.UUID;

@Component
@Prototype
public class RequestProcessor {
    private final String instanceId;
    private int requestCount = 0;

    public RequestProcessor() {
        this.instanceId = UUID.randomUUID().toString().substring(0, 8);
        System.out.println("Created RequestProcessor: " + instanceId);
    }

    @PostConstruct
    public void init() {
        System.out.println("Initializing RequestProcessor: " + instanceId);
    }

    public void processRequest(String data) {
        requestCount++;
        System.out.println("Processing request #" + requestCount + " in processor " + instanceId + ": " + data);
    }

    public String getInstanceId() {
        return instanceId;
    }

    public int getRequestCount() {
        return requestCount;
    }
}
```

### Advanced Controller

```java
package examples.advanced.controller;

import examples.advanced.service.NotificationManager;
import examples.advanced.service.RequestProcessor;
import jazzyframework.di.annotations.Component;
import jazzyframework.di.annotations.Named;
import jazzyframework.http.Request;
import jazzyframework.http.Response;

import java.util.HashMap;
import java.util.Map;

@Component
public class AdvancedController {
    private final NotificationManager notificationManager;
    private final RequestProcessor processor1;
    private final RequestProcessor processor2;

    // Constructor injection with @Named parameters
    public AdvancedController(
        NotificationManager notificationManager,
        RequestProcessor processor1,         // First @Prototype instance
        RequestProcessor processor2,         // Second @Prototype instance (different!)
        @Named("emailService") examples.advanced.service.NotificationService emailService
    ) {
        this.notificationManager = notificationManager;
        this.processor1 = processor1;
        this.processor2 = processor2;
        
        System.out.println("AdvancedController created:");
        System.out.println("  Processor 1 ID: " + processor1.getInstanceId());
        System.out.println("  Processor 2 ID: " + processor2.getInstanceId());
        System.out.println("  Same instances? " + (processor1 == processor2)); // Should be false
        
        // Test the email service directly
        emailService.send("test@example.com", "Direct injection test");
    }

    public Response sendNotification(Request request) {
        String recipient = request.getQueryParam("recipient");
        String message = request.getQueryParam("message");
        String type = request.getQueryParam("type");

        if (recipient == null || message == null) {
            return Response.badRequest().json("{\"error\": \"recipient and message are required\"}");
        }

        // Send via specific services
        switch (type != null ? type : "default") {
            case "email":
                notificationManager.sendViaEmail(recipient, message);
                break;
            case "sms":
                notificationManager.sendViaSms(recipient, message);
                break;
            case "all":
                notificationManager.sendViaAll(recipient, message);
                break;
            default:
                notificationManager.sendViaDefault(recipient, message);
                break;
        }

        return Response.json(Map.of("status", "sent", "type", type != null ? type : "default"));
    }

    public Response processRequests(Request request) {
        String data = request.getQueryParam("data");
        if (data == null) data = "sample data";

        // Use both processor instances
        processor1.processRequest(data + " (processor1)");
        processor2.processRequest(data + " (processor2)");

        Map<String, Object> result = new HashMap<>();
        result.put("processor1", Map.of(
            "id", processor1.getInstanceId(),
            "requestCount", processor1.getRequestCount()
        ));
        result.put("processor2", Map.of(
            "id", processor2.getInstanceId(),
            "requestCount", processor2.getRequestCount()
        ));

        return Response.json(result);
    }

    public Response getInfo(Request request) {
        Map<String, Object> info = new HashMap<>();
        info.put("controller", "AdvancedController");
        info.put("features", new String[]{
            "Multiple interface implementations",
            "Named injection",
            "Primary bean selection",
            "Prototype scope",
            "Constructor injection"
        });
        
        // This endpoint demonstrates what happens without @Named or @Primary
        // In our case, we use @Named injection so no conflict occurs
        
        return Response.json(info);
    }
}
```

### Advanced Application

```java
package examples.advanced;

import examples.advanced.controller.AdvancedController;
import jazzyframework.core.Config;
import jazzyframework.core.Server;
import jazzyframework.routing.Router;

public class AdvancedDIApp {
    public static void main(String[] args) {
        // Create configuration
        Config config = new Config();
        config.setEnableMetrics(true);

        // Create router and define routes
        Router router = new Router();

        // Advanced DI demonstration routes
        router.GET("/advanced/notification", "sendNotification", AdvancedController.class);
        router.GET("/advanced/process", "processRequests", AdvancedController.class);
        router.GET("/advanced/info", "getInfo", AdvancedController.class);

        // Create and start server
        Server server = new Server(router, config);

        System.out.println("🚀 Advanced Jazzy Framework DI Example starting...");
        System.out.println("📊 Metrics: http://localhost:8090/metrics");
        System.out.println("🔧 Advanced DI Demo: http://localhost:8090/advanced/info");
        System.out.println();
        System.out.println("Example API calls:");
        System.out.println("  curl http://localhost:8090/advanced/info");
        System.out.println("  curl \"http://localhost:8090/advanced/notification?recipient=test@example.com&message=Hello&type=email\"");
        System.out.println("  curl \"http://localhost:8090/advanced/notification?recipient=test@example.com&message=Hello&type=all\"");
        System.out.println("  curl \"http://localhost:8090/advanced/process?data=TestData\"");

        // Add shutdown hook to demonstrate @PreDestroy
        Runtime.getRuntime().addShutdownHook(new Thread(() -> {
            System.out.println("\n🛑 Shutting down server...");
            server.getDIContainer().dispose(); // This will call @PreDestroy methods
        }));

        server.start(8090);
    }
}
```

## Running the Examples

### Basic Example

1. Compile: `javac -cp "lib/*" src/main/java/examples/di/*.java src/main/java/examples/di/**/*.java`
2. Run: `java -cp "lib/*:src/main/java" examples.di.App`

Output will show DI initialization:
```
UserRepository initialized with 2 users
UserService created with injected UserRepository  
UserController created with injected UserService
🚀 Jazzy Framework DI Example Server starting...
```

### Advanced Example

1. Compile: `javac -cp "lib/*" src/main/java/examples/advanced/*.java src/main/java/examples/advanced/**/*.java`
2. Run: `java -cp "lib/*:src/main/java" examples.advanced.AdvancedDIApp`

Output will show advanced DI features:
```
EmailNotificationService initialized
SmsNotificationService initialized  
PushNotificationService initialized (PRIMARY)
Created RequestProcessor: abc12345
Initializing RequestProcessor: abc12345
Created RequestProcessor: def67890
Initializing RequestProcessor: def67890
NotificationManager created with all notification services
AdvancedController created:
  Processor 1 ID: abc12345
  Processor 2 ID: def67890
  Same instances? false
📧 Sending email to: test@example.com
   Message: Direct injection test
🚀 Advanced Jazzy Framework DI Example starting...
```

## Key Takeaways

1. **Zero Configuration**: No XML or manual setup required
2. **Constructor Injection**: Clean, testable dependency injection
3. **Multiple Implementations**: Use `@Named` and `@Primary` for flexibility
4. **Lifecycle Management**: `@PostConstruct` and `@PreDestroy` for proper initialization/cleanup
5. **Scope Management**: `@Singleton` (default) vs `@Prototype` for different use cases
6. **Framework Integration**: DI works seamlessly with routing and request handling

The DI system makes Jazzy Framework enterprise-ready while maintaining its simplicity and ease of use. 