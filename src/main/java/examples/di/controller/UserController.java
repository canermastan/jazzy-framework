package examples.di.controller;

import examples.di.entity.User;
import examples.di.service.UserService;
import jazzyframework.http.Request;
import jazzyframework.http.Response;
import jazzyframework.http.validation.ValidationResult;

import java.util.List;
import java.util.Map;

import static jazzyframework.http.ResponseFactory.response;

/**
 * Example controller demonstrating dependency injection.
 * UserService will be injected via constructor.
 */
public class UserController {
    
    private final UserService userService;
    
    // Constructor injection - DI container will automatically inject UserService
    public UserController(UserService userService) {
        this.userService = userService;
    }
    
    public Response getUserById(Request request) {
        try {
            String id = request.path("id");
            User user = userService.getUserById(id);
            
            return response().json(
                "status", "success",
                "user", user
            );
        } catch (RuntimeException e) {
            return response().json(
                "status", "error",
                "message", e.getMessage()
            ).status(404);
        }
    }
    
    public Response getAllUsers(Request request) {
        List<User> users = userService.getAllUsers();
        long total = userService.getUserCount();
        
        return response().json(
            "status", "success",
            "users", users,
            "total", total
        );
    }
    
    public Response createUser(Request request) {
        // Validate the request
        ValidationResult result = request.validator()
            .field("name").required().minLength(3).maxLength(50)
            .field("email").required().email()
            .field("age").required().min(18).max(100)
            .validate();
        
        if (!result.isValid()) {
            return response().json(
                "status", "error",
                "message", "Validation failed",
                "errors", result.getAllErrors()
            ).status(400);
        }
        
        try {
            Map<String, Object> userData = request.parseJson();
            User user = new User();
            user.setName((String) userData.get("name"));
            user.setEmail((String) userData.get("email"));
            user.setAge(((Number) userData.get("age")).intValue());
            
            User createdUser = userService.createUser(user);
            
            return response().json(
                "status", "success",
                "message", "User created successfully",
                "user", createdUser
            ).status(201);
        } catch (Exception e) {
            return response().json(
                "status", "error",
                "message", "Failed to create user: " + e.getMessage()
            ).status(500);
        }
    }
    
    public Response updateUser(Request request) {
        try {
            String id = request.path("id");
            
            // For update operations, we'll validate only the fields that are present
            Map<String, Object> userData = request.parseJson();
            
            // Validate only present fields
            if (userData.containsKey("name")) {
                ValidationResult nameValidation = request.validator()
                    .field("name").required().minLength(3).maxLength(50)
                    .validate();
                if (!nameValidation.isValid()) {
                    return response().json(
                        "status", "error",
                        "message", "Validation failed",
                        "errors", nameValidation.getAllErrors()
                    ).status(400);
                }
            }
            
            if (userData.containsKey("email")) {
                ValidationResult emailValidation = request.validator()
                    .field("email").required().email()
                    .validate();
                if (!emailValidation.isValid()) {
                    return response().json(
                        "status", "error",
                        "message", "Validation failed",
                        "errors", emailValidation.getAllErrors()
                    ).status(400);
                }
            }
            
            if (userData.containsKey("age")) {
                ValidationResult ageValidation = request.validator()
                    .field("age").required().min(18).max(100)
                    .validate();
                if (!ageValidation.isValid()) {
                    return response().json(
                        "status", "error",
                        "message", "Validation failed",
                        "errors", ageValidation.getAllErrors()
                    ).status(400);
                }
            }
            
            User user = new User();
            if (userData.containsKey("name")) {
                user.setName((String) userData.get("name"));
            }
            if (userData.containsKey("email")) {
                user.setEmail((String) userData.get("email"));
            }
            if (userData.containsKey("age")) {
                user.setAge(((Number) userData.get("age")).intValue());
            }
            
            User updatedUser = userService.updateUser(id, user);
            
            return response().json(
                "status", "success",
                "message", "User updated successfully",
                "user", updatedUser
            );
        } catch (RuntimeException e) {
            return response().json(
                "status", "error",
                "message", e.getMessage()
            ).status(404);
        } catch (Exception e) {
            return response().json(
                "status", "error",
                "message", "Failed to update user: " + e.getMessage()
            ).status(500);
        }
    }
    
    public Response deleteUser(Request request) {
        try {
            String id = request.path("id");
            userService.deleteUser(id);
            
            return response().json(
                "status", "success",
                "message", "User deleted successfully"
            );
        } catch (RuntimeException e) {
            return response().json(
                "status", "error",
                "message", e.getMessage()
            ).status(404);
        } catch (Exception e) {
            return response().json(
                "status", "error",
                "message", "Failed to delete user: " + e.getMessage()
            ).status(500);
        }
    }
} 