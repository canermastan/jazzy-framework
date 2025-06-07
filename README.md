# 🎷 Jazzy Framework

> **A modern, developer-friendly Java web framework that eliminates boilerplate code**  
> *Spring Boot simplicity + Laravel elegance = Jazzy Framework*

[![Java](https://img.shields.io/badge/Java-17+-orange.svg)](https://www.oracle.com/java/)
[![Maven Central](https://img.shields.io/badge/Maven-Central-blue.svg)](https://search.maven.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](https://opensource.org/licenses/MIT)

## ⚡ Why Jazzy?

**Turn this complexity:**
```java
// Traditional Spring Boot setup
@RestController
@RequestMapping("/api/users")
public class UserController {
    @Autowired private UserService userService;
    
    @GetMapping
    public ResponseEntity<List<User>> getUsers() {
        // ... validation, error handling, response building
    }
    
    @PostMapping
    public ResponseEntity<User> createUser(@RequestBody User user) {
        // ... validation, error handling, response building
    }
    // ... 40+ more lines
}

// Plus: separate configuration classes, security setup, route registration...
```

**Into this simplicity:**
```java
// Jazzy Framework - Complete REST API with real syntax!
@Component
@Crud(
    entity = Product.class,
    endpoint = "/api/products",
    enablePagination = true,
    enableSearch = true,
    searchableFields = {"name", "description"}
)
public class ProductController {
    private final ProductRepository productRepository;
    
    public ProductController(ProductRepository productRepository) {
        this.productRepository = productRepository;
    }
    
    // 🎉 That's it! 5+ endpoints auto-generated + DI + validation
}
```

## 🚀 Quick Start (60 seconds)

### 1️⃣ Secure Authentication App
```java
// User Entity
@Entity
public class User {
    @Id @GeneratedValue
    private Long id;
    private String email;
    private String username;
    private String password;
    private String role = "USER";
    // getters/setters...
}

// Repository
@Component
public interface UserRepository extends BaseRepository<User, Long> {
    Optional<User> findByEmail(String email);
}

// Main App - Full JWT authentication in 1 annotation!
@EnableJazzyAuth(
    userClass = User.class,
    repositoryClass = UserRepository.class,
    loginMethod = LoginMethod.EMAIL,
    jwtExpirationHours = 24,
    authBasePath = "/api/auth"
)
public class App {
    public static void main(String[] args) {
        Router router = new Router();
        Server server = new Server(router, new Config());
        server.start(8080);
    }
}
```
**Result:** Full JWT authentication with `/api/auth/register`, `/api/auth/login`, `/api/auth/me` endpoints! 🔐

### 2️⃣ Complete CRUD API
```java
// Entity
@Entity
public class Product {
    @Id @GeneratedValue
    private Long id;
    private String name;
    private String description;
    private Double price;
    private Integer stock;
    // getters/setters...
}

// Repository - Query methods auto-generated!
@Component
public interface ProductRepository extends BaseRepository<Product, Long> {
    List<Product> findByName(String name);
    List<Product> findByPriceGreaterThan(Double price);
}

// Controller - Complete REST API in 3 lines!
@Component
@Crud(
    entity = Product.class,
    endpoint = "/api/products",
    enablePagination = true,
    enableSearch = true,
    searchableFields = {"name", "description"}
)
public class ProductController {
    private final ProductRepository productRepository;
    
    public ProductController(ProductRepository productRepository) {
        this.productRepository = productRepository;
    }
    
    // Optional: Override any auto-generated method
    @CrudOverride
    public Response findAll(Request request) {
        return Response.json(ApiResponse.success("Custom logic here", 
            productRepository.findAll()));
    }
}

// Main App
public class App {
    public static void main(String[] args) {
        Router router = new Router();
        
        // Only register overridden methods (others are auto-generated!)
        router.GET("/api/products", "findAll", ProductController.class);
        
        Server server = new Server(router, new Config());
        server.start(8080);
    }
}
```
**Result:** 5+ REST endpoints with search, pagination, validation! 📊

## ✨ Key Features

| Feature | Description | Status |
|---------|-------------|--------|
| 🔐 **Zero-Config Auth** | JWT authentication in 1 annotation | ✅ v0.5 |
| ⚡ **Auto-CRUD** | Complete REST APIs without code | ✅ v0.4 |
| 🗄️ **Smart Database** | JPA repositories with query parsing | ✅ v0.3 |
| 💉 **Dependency Injection** | Constructor injection with auto-discovery | ✅ v0.2 |
| 🛣️ **Clean Routing** | Simple router.GET/POST syntax | ✅ v0.1 |

## 📖 Documentation

- 📚 **[Complete Documentation](https://canermastan.github.io/jazzy-framework/)**

## 🛠️ Installation

```xml
<dependency>
    <groupId>com.jazzyframework</groupId>
    <artifactId>jazzy-core</artifactId>
    <version>0.5.0</version>
</dependency>
```

## 🎯 Real-World Example

```java
// Task Management System - Complete app in ~50 lines!

// Entity
@Entity
public class Task {
    @Id @GeneratedValue private Long id;
    private String title;
    private String description;
    private boolean completed = false;
    private LocalDateTime createdAt;
    // getters/setters...
}

// Repository - Query methods auto-generated!
@Component
public interface TaskRepository extends BaseRepository<Task, Long> {
    List<Task> findByCompleted(boolean completed);
    List<Task> findByTitleContaining(String title);
}

// Controller - Full REST API with validation!
@Component
@Crud(
    entity = Task.class,
    endpoint = "/api/tasks",
    enablePagination = true,
    enableSearch = true,
    searchableFields = {"title", "description"}
)
public class TaskController {
    private final TaskRepository taskRepository;
    
    public TaskController(TaskRepository taskRepository) {
        this.taskRepository = taskRepository;
    }
}

// Security Config
@Component
public class SecurityConfig extends jazzyframework.security.SecurityConfig {
    @Override
    public void configure() {
        publicEndpoints("/", "/api/auth/**");
        requireAuth("/api/tasks/**");
    }
}

// Main App - Complete task management system!
@EnableJazzyAuth(userClass = User.class, repositoryClass = UserRepository.class)
public class TaskApp {
    public static void main(String[] args) {
        Router router = new Router();
        
        // Add public route
        router.GET("/", "welcome", HomeController.class);
        
        Server server = new Server(router, new Config());
        server.start(8080);
        
        // 🎉 You now have:
        // - User registration/login (/api/auth/*)
        // - Complete task CRUD (/api/tasks/*)
        // - JWT protection with roles
        // - Search & pagination
        // - Input validation
        // - Constructor injection
    }
}

// Simple controller with Request/Response
public class HomeController {
    public Response welcome(Request request) {
        return Response.json(
            JSON.of(
                "message", "Welcome to Task Manager!",
                "endpoints", new String[]{
                    "POST /api/auth/register",
                    "POST /api/auth/login",
                    "GET /api/tasks",
                    "POST /api/tasks"
                }
            )
        );
    }
}
```

**Available Endpoints:**
```bash
POST /api/auth/register    # User registration
POST /api/auth/login      # User login  
GET  /api/auth/me         # Current user info

GET    /api/tasks         # List tasks (paginated)
POST   /api/tasks         # Create task
GET    /api/tasks/{id}    # Get specific task
PUT    /api/tasks/{id}    # Update task
DELETE /api/tasks/{id}    # Delete task
GET    /api/tasks/search?title=urgent  # Search tasks
```

## 🔍 Why Developers Love Jazzy

```java
// ❌ Traditional approach: Complex setup
@RestController
@RequestMapping("/api/users")
public class UserController {
    @Autowired private UserService service;
    
    @GetMapping
    public ResponseEntity<Page<User>> getUsers(
        @RequestParam(defaultValue = "0") int page,
        @RequestParam(defaultValue = "10") int size) {
        
        try {
            Page<User> users = service.findAll(PageRequest.of(page, size));
            return ResponseEntity.ok(users);
        } catch (Exception e) {
            return ResponseEntity.status(500)
                .body(new ErrorResponse("Failed to fetch users"));
        }
    }
    // ... 40+ more lines for basic CRUD + validation + error handling
}

// ✅ Jazzy approach: Clean & simple
public class UserController {
    public Response getAllUsers(Request request) {
        int page = request.queryInt("page", 1);
        int limit = request.queryInt("limit", 10);
        
        return response().json(
            "users", userService.findAll(),
            "page", page,
            "limit", limit
        );
    }
}

// Or even simpler with @Crud:
@Component
@Crud(entity = User.class, endpoint = "/api/users", enablePagination = true)
public class UserController { } // That's it! 🎉
```

## 💝 Real Developer Feedback

> *"I showed Jazzy to a few friends - everyone loved it! They say it looks very simple and serves the purpose directly."*

> *"My friends who were afraid of writing Java say they can now quickly develop applications without dealing with long Java code."*

**What developers say:**
- 🎯 **"Serves the purpose directly"** - No unnecessary complexity
- ⚡ **"Looks incredibly simple"** - Minimal learning curve  
- 🚀 **"No more Java fear"** - Makes Java development fun again
- 💼 **"Developing apps quickly"** - From idea to running app in minutes

## 📊 Framework Comparison

| Feature | Spring Boot | Jazzy Framework | Developer Experience |
|---------|-------------|-----------------|---------------------|
| Basic CRUD API | ~100 lines | ~3 lines | **Java is no longer scary!** |
| JWT Authentication | ~200 lines | 1 annotation | **Serves the purpose directly** |
| Database Setup | Manual config | Auto-discovery | **No setup complexity** |
| Route Definition | Annotations | Simple router calls | **Clear and simple** |

## 🚀 Getting Started

1. **Clone & Run:**
```bash
   git clone https://github.com/canermastan/jazzy-framework.git
   cd jazzy-framework
mvn clean install
mvn exec:java -Dexec.mainClass="examples.simple_crud.SimpleCrudApp"
```

2. **Visit:** `http://localhost:8080`

3. **Explore:** Check out `/examples` folder for real implementations

---

## 📋 Version History

<details>
<summary>Click to expand version history</summary>

| Version | Release Date | Key Features |
|---------|-------------|--------------|
| **0.5.0** | 2025 | 🆕 **Security & Authentication** - JWT authentication, @EnableJazzyAuth annotation, role-based access control |
| **0.4.0** | 2025 | 🆕 **Auto-CRUD System** - @Crud annotation, zero-boilerplate REST APIs, automatic endpoint generation |
| **0.3.0** | 2025 | 🆕 **Database Integration** - Hibernate/JPA, Spring Data JPA-like repositories, automatic query generation |
| **0.2.0** | 2025 | 🆕 **Dependency Injection System** - Spring-like annotations, automatic component discovery |
| **0.1.0** | 2025 | Core framework with routing, request/response handling, JSON utilities, validation system |

</details>

---

⭐ **Found Jazzy useful?** Give us a star and help other developers discover it!

**License:** MIT | **Author:** [@canermastan](https://github.com/canermastan) 

