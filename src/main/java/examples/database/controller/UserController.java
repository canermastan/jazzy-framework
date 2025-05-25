package examples.database.controller;

import examples.database.entity.User;
import examples.database.service.UserService;
import jazzyframework.http.JSON;
import jazzyframework.http.Request;
import jazzyframework.http.Response;
import jazzyframework.http.validation.ValidationResult;
import jazzyframework.http.validation.Validator;
import jazzyframework.di.annotations.Component;

import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.logging.Logger;

/**
 * REST controller for User management operations.
 * 
 * <p>This controller demonstrates:
 * <ul>
 *   <li>RESTful API design with proper HTTP methods</li>
 *   <li>Dependency injection with service layer</li>
 *   <li>Request validation using framework validators</li>
 *   <li>JSON responses with proper HTTP status codes</li>
 *   <li>Error handling and user feedback</li>
 * </ul>
 * 
 * <p>Available endpoints (must be registered in main app):
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
 * @since 0.3.0
 * @author Caner Mastan
 */
@Component
public class UserController {
    private static final Logger logger = Logger.getLogger(UserController.class.getName());
    
    private final UserService userService;

    /**
     * Creates a new UserController.
     * UserService will be automatically injected by the DI container.
     * 
     * @param userService the user service
     */
    public UserController(UserService userService) {
        this.userService = userService;
        logger.info("UserController created with injected UserService");
    }

    /**
     * Lists all users.
     * 
     * @param request the HTTP request
     * @return JSON response with user list
     */
    public Response getAllUsers(Request request) {
        logger.info("GET /users - Fetching all users");
        
        try {
            List<User> users = userService.findAllUsers();
            long totalCount = userService.getUserCount();
            
            Map<String, Object> response = Map.of(
                "users", users,
                "total", totalCount,
                "count", users.size()
            );
            
            return Response.json(response);
        } catch (Exception e) {
            logger.severe("Error fetching users: " + e.getMessage());
            return Response.json(Map.of("error", "Failed to fetch users")).status(500);
        }
    }

    /**
     * Gets a user by ID.
     * 
     * @param request the HTTP request
     * @return JSON response with user data or 404 if not found
     */
    public Response getUserById(Request request) {
        String idParam = request.path("id");
        logger.info("GET /users/" + idParam + " - Fetching user by ID");
        
        try {
            Long id = Long.parseLong(idParam);
            Optional<User> user = userService.findById(id);
            
            if (user.isPresent()) {
                return Response.json(Map.of("user", user.get()));
            } else {
                return Response.json(Map.of("error", "User not found with ID: " + id)).status(404);
            }
        } catch (NumberFormatException e) {
            return Response.json(Map.of("error", "Invalid user ID format")).status(400);
        } catch (Exception e) {
            logger.severe("Error fetching user: " + e.getMessage());
            return Response.json(Map.of("error", "Failed to fetch user")).status(500);
        }
    }

    /**
     * Creates a new user.
     * 
     * @param request the HTTP request
     * @return JSON response with created user data
     */
    public Response createUser(Request request) {
        logger.info("POST /users - Creating new user");
        
        User user = request.toObject(User.class);
        User createdUser = userService.createUser(user.getName(), user.getEmail(), user.getPassword());
        return Response.json(JSON.of("result", createdUser));
    }

    /**
     * Searches for a user by email.
     * 
     * @param request the HTTP request
     * @return JSON response with user data or 404 if not found
     */
    public Response searchUserByEmail(Request request) {
        String email = request.query("email");
        logger.info("GET /users/search?email=" + email + " - Searching user by email");
        
        if (email == null || email.trim().isEmpty()) {
            return Response.json(Map.of("error", "Email parameter is required")).status(400);
        }
        
        try {
            Optional<User> user = userService.findByEmail(email.trim());
            
            if (user.isPresent()) {
                return Response.json(Map.of("user", user.get()));
            } else {
                return Response.json(Map.of("error", "User not found with email: " + email)).status(404);
            }
        } catch (Exception e) {
            logger.severe("Error searching user: " + e.getMessage());
            return Response.json(Map.of("error", "Failed to search user")).status(500);
        }
    }

    /**
     * Deactivates a user.
     * 
     * @param request the HTTP request
     * @return JSON response with success message
     */
    public Response deactivateUser(Request request) {
        String idParam = request.path("id");
        logger.info("PUT /users/" + idParam + "/deactivate - Deactivating user");
        
        try {
            Long id = Long.parseLong(idParam);
            boolean success = userService.deactivateUser(id);
            
            if (success) {
                return Response.json(Map.of("message", "User deactivated successfully"));
            } else {
                return Response.json(Map.of("error", "User not found with ID: " + id)).status(404);
            }
        } catch (NumberFormatException e) {
            return Response.json(Map.of("error", "Invalid user ID format")).status(400);
        } catch (Exception e) {
            logger.severe("Error deactivating user: " + e.getMessage());
            return Response.json(Map.of("error", "Failed to deactivate user")).status(500);
        }
    }

    /**
     * Deletes a user.
     * 
     * @param request the HTTP request
     * @return JSON response with success message
     */
    public Response deleteUser(Request request) {
        String idParam = request.path("id");
        logger.info("DELETE /users/" + idParam + " - Deleting user");
        
        try {
            Long id = Long.parseLong(idParam);
            boolean success = userService.deleteUser(id);
            
            if (success) {
                return Response.json(Map.of("message", "User deleted successfully"));
            } else {
                return Response.json(Map.of("error", "User not found with ID: " + id)).status(404);
            }
        } catch (NumberFormatException e) {
            return Response.json(Map.of("error", "Invalid user ID format")).status(400);
        } catch (Exception e) {
            logger.severe("Error deleting user: " + e.getMessage());
            return Response.json(Map.of("error", "Failed to delete user")).status(500);
        }
    }
}