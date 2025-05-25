package examples.database;

import examples.database.controller.UserController;
import examples.database.entity.User;
import examples.database.service.UserService;
import jazzyframework.core.Config;
import jazzyframework.core.Server;
import jazzyframework.routing.Router;

import java.util.List;
import java.util.logging.Logger;

/**
 * Example application demonstrating database integration with JazzyFramework.
 * 
 * <p>This application showcases:
 * <ul>
 *   <li>Zero-configuration database setup with H2</li>
 *   <li>Automatic entity discovery and registration</li>
 *   <li>Automatic repository implementation</li>
 *   <li>Dependency injection with repositories and services</li>
 *   <li>RESTful API endpoints for database operations</li>
 * </ul>
 * 
 * <p>The application automatically:
 * <ol>
 *   <li>Reads configuration from application.properties</li>
 *   <li>Initializes H2 database and Hibernate</li>
 *   <li>Discovers and registers User entity</li>
 *   <li>Creates UserRepository implementation</li>
 *   <li>Injects dependencies into UserService and UserController</li>
 *   <li>Registers REST endpoints for user management</li>
 * </ol>
 * 
 * <p>Available endpoints:
 * <ul>
 *   <li>GET /users - list all users</li>
 *   <li>GET /users/{id} - get user by ID</li>
 *   <li>GET /users/search?email=... - find user by email</li>
 *   <li>GET /users/active - list active users</li>
 *   <li>GET /users/age-range?min=...&max=... - find users by age range</li>
 *   <li>POST /users - create new user</li>
 *   <li>PUT /users/{id} - update user</li>
 *   <li>DELETE /users/{id} - delete user</li>
 *   <li>PUT /users/{id}/deactivate - deactivate user</li>
 * </ul>
 * 
 * <p>H2 Console is available at: http://localhost:8082
 * 
 * @since 0.3.0
 * @author Caner Mastan
 */
public class DatabaseExampleApp {
    private static final Logger logger = Logger.getLogger(DatabaseExampleApp.class.getName());

    public static void main(String[] args) {
        logger.info("Starting JazzyFramework Database Example Application...");
        
        try {
            Config config = new Config();
            config.setServerPort(8080);
            config.setEnableMetrics(true);

            Router router = new Router();

            // User routes - all endpoint definitions for the UserController
            router.GET("/users", "getAllUsers", UserController.class);
            router.GET("/users/{id}", "getUserById", UserController.class);
            router.GET("/users/search", "searchUserByEmail", UserController.class);
            router.GET("/users/active", "getActiveUsers", UserController.class);
            router.GET("/users/age-range", "getUsersByAgeRange", UserController.class);
            router.POST("/users", "createUser", UserController.class);
            router.PUT("/users/{id}", "updateUser", UserController.class);
            router.PUT("/users/{id}/deactivate", "deactivateUser", UserController.class);
            router.DELETE("/users/{id}", "deleteUser", UserController.class);
            
            Server server = new Server(router, config);
                        
            server.start(config.getServerPort());   
        } catch (Exception e) {
            logger.severe("Failed to start application: " + e.getMessage());
            e.printStackTrace();
            System.exit(1);
        }
    }
}