package examples.di;

import examples.di.controller.UserController;
import jazzyframework.core.Config;
import jazzyframework.core.Server;
import jazzyframework.routing.Router;

/**
 * Example application demonstrating dependency injection features.
 * DI is automatically enabled and components are auto-discovered.
 * No configuration needed - just annotate your classes with @Component!
 */
public class App {
    
    public static void main(String[] args) {
        Config config = new Config();
        config.setServerPort(8088);
        config.setEnableMetrics(true);
        
        Router router = new Router();
        
        router.GET("/users/{id}", "getUserById", UserController.class);
        router.GET("/users", "getAllUsers", UserController.class);
        router.POST("/users", "createUser", UserController.class);
        router.PUT("/users/{id}", "updateUser", UserController.class);
        router.DELETE("/users/{id}", "deleteUser", UserController.class);
        
        Server server = new Server(router, config);
        
        System.out.println("🚀 Starting Jazzy Framework with Automatic Dependency Injection");
        System.out.println("📦 Components are auto-discovered - no configuration needed!");
        System.out.println("🌐 Server will start on port " + config.getServerPort());
        System.out.println();
        System.out.println("📋 Available endpoints:");
        System.out.println("  GET    /users      - Get all users");
        System.out.println("  GET    /users/{id} - Get user by ID");
        System.out.println("  POST   /users      - Create new user");
        System.out.println("  PUT    /users/{id} - Update user");
        System.out.println("  DELETE /users/{id} - Delete user");
        System.out.println("  GET    /metrics    - View metrics");
        System.out.println();
        System.out.println("🧪 Example requests:");
        System.out.println("  curl http://localhost:8088/users");
        System.out.println("  curl http://localhost:8088/users/1");
        System.out.println("  curl -X POST -H 'Content-Type: application/json' \\");
        System.out.println("       -d '{\"name\":\"Alice\",\"email\":\"alice@example.com\",\"age\":25}' \\");
        System.out.println("       http://localhost:8088/users");
        System.out.println();
        System.out.println("✨ Auto-discovered components:");
        System.out.println("   @Component UserRepository (data layer)");
        System.out.println("   @Component UserService (business layer)");
        System.out.println("   UserController (web layer - gets dependencies injected)");
        System.out.println();
        
        server.start(config.getServerPort());
    }
} 