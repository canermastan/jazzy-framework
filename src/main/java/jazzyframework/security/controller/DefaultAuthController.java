package jazzyframework.security.controller;

import jazzyframework.di.annotations.Component;
import jazzyframework.http.*;
import jazzyframework.security.annotations.LoginMethod;
import jazzyframework.security.jwt.JwtUtil;
import jazzyframework.security.jwt.JwtClaims;
import jazzyframework.security.validation.UserEntityValidator;
import jazzyframework.data.BaseRepository;

import java.lang.reflect.Constructor;
import java.security.MessageDigest;
import java.nio.charset.StandardCharsets;
import java.util.Map;

/**
 * Default Authentication Controller for Jazzy Framework
 * Automatically provides register, login, and me endpoints
 */
@Component
public class DefaultAuthController {
    
    private final Class<?> userClass;
    private final LoginMethod loginMethod;
    private final JwtUtil jwtUtil;
    private final BaseRepository<Object, Long> userRepository;
    
    public DefaultAuthController(Class<?> userClass, LoginMethod loginMethod, JwtUtil jwtUtil, BaseRepository<Object, Long> userRepository) {
        this.userClass = userClass;
        this.loginMethod = loginMethod;
        this.jwtUtil = jwtUtil;
        this.userRepository = userRepository;
    }
    
    /**
     * Register new user
     * POST /api/auth/register
     */
    public Response register(Request request) {
        try {
            // Parse JSON body
            Map<String, Object> json = request.parseJson();
            
            // Get registration data
            String email = loginMethod == LoginMethod.USERNAME ? null : (String) json.get("email");
            String username = loginMethod == LoginMethod.EMAIL ? null : (String) json.get("username");
            String password = (String) json.get("password");
            
            // Validate input
            if (password == null || password.trim().isEmpty()) {
                return Response.json(JSON.of("error", "Password is required")).status(400);
            }
            
            if (loginMethod == LoginMethod.EMAIL || loginMethod == LoginMethod.BOTH) {
                if (email == null || email.trim().isEmpty()) {
                    return Response.json(JSON.of("error", "Email is required")).status(400);
                }
                if (!isValidEmail(email)) {
                    return Response.json(JSON.of("error", "Invalid email format")).status(400);
                }
            }
            
            if (loginMethod == LoginMethod.USERNAME || loginMethod == LoginMethod.BOTH) {
                if (username == null || username.trim().isEmpty()) {
                    return Response.json(JSON.of("error", "Username is required")).status(400);
                }
            }
            
            // Check if user already exists
            if (userExists(email, username)) {
                return Response.json(JSON.of("error", "User already exists")).status(409);
            }
            
            // Create new user
            Object user = createUser(email, username, password);
            Object savedUser = userRepository.save(user);
            
            // Generate JWT token
            String userId = UserEntityValidator.getFieldValue(savedUser, "id");
            String userEmail = UserEntityValidator.getFieldValue(savedUser, "email");
            String token = jwtUtil.generateToken(userId, userEmail, new String[]{"USER"});
            
            return Response.json(JSON.of(
                "message", "User registered successfully",
                "token", token,
                "user", JSON.of(
                    "id", userId,
                    "email", userEmail
                )
            ));
            
        } catch (Exception e) {
            e.printStackTrace();
            return Response.json(JSON.of("error", "Registration failed: " + e.getMessage())).status(500);
        }
    }
    
    /**
     * Login user
     * POST /api/auth/login
     */
    public Response login(Request request) {
        try {
            // Parse JSON body
            Map<String, Object> json = request.parseJson();
            
            String loginInput = null;
            String password = (String) json.get("password");
            
            // Get login input based on method
            if (loginMethod == LoginMethod.EMAIL) {
                loginInput = (String) json.get("email");
            } else if (loginMethod == LoginMethod.USERNAME) {
                loginInput = (String) json.get("username");
            } else if (loginMethod == LoginMethod.BOTH) {
                loginInput = (String) json.get("email");
                if (loginInput == null) {
                    loginInput = (String) json.get("username");
                }
            }
            
            // Validate input
            if (loginInput == null || loginInput.trim().isEmpty()) {
                return Response.json(JSON.of("error", "Login credential is required")).status(400);
            }
            
            if (password == null || password.trim().isEmpty()) {
                return Response.json(JSON.of("error", "Password is required")).status(400);
            }
            
            // Find user
            Object user = findUserByLoginField(loginInput);
            if (user == null) {
                return Response.json(JSON.of("error", "Invalid credentials")).status(401);
            }
            
            // Verify password
            String storedPassword = UserEntityValidator.getFieldValue(user, "password");
            if (storedPassword == null) {
                storedPassword = UserEntityValidator.getFieldValue(user, "passwordHash");
            }
            
            if (!verifyPassword(password, storedPassword)) {
                return Response.json(JSON.of("error", "Invalid credentials")).status(401);
            }
            
            // Generate JWT token
            String userId = UserEntityValidator.getFieldValue(user, "id");
            String userEmail = UserEntityValidator.getFieldValue(user, "email");
            String token = jwtUtil.generateToken(userId, userEmail, new String[]{"USER"});
            
            return Response.json(JSON.of(
                "message", "Login successful",
                "token", token,
                "user", JSON.of(
                    "id", userId,
                    "email", userEmail
                )
            ));
            
        } catch (Exception e) {
            e.printStackTrace();
            return Response.json(JSON.of("error", "Login failed: " + e.getMessage())).status(500);
        }
    }
    
    /**
     * Get current user info
     * GET /api/auth/me
     */
    public Response getCurrentUser(Request request) {
        try {
            // Extract JWT token from Authorization header
            String authHeader = request.header("Authorization");
            if (authHeader == null || !authHeader.startsWith("Bearer ")) {
                return Response.json(JSON.of("error", "Authorization token required")).status(401);
            }
            
            String token = authHeader.substring(7);
            JwtClaims claims = jwtUtil.validateToken(token);
            
            // Find user by ID
            Object user = userRepository.findById(Long.parseLong(claims.getUserId())).orElse(null);
            if (user == null) {
                return Response.json(JSON.of("error", "User not found")).status(404);
            }
            
            String userId = UserEntityValidator.getFieldValue(user, "id");
            String userEmail = UserEntityValidator.getFieldValue(user, "email");
            String username = UserEntityValidator.getFieldValue(user, "username");
            
            return Response.json(JSON.of(
                "user", JSON.of(
                    "id", userId,
                    "email", userEmail,
                    "username", username
                )
            ));
            
        } catch (Exception e) {
            return Response.json(JSON.of("error", "Unauthorized")).status(401);
        }
    }
    
    private Object createUser(String email, String username, String password) throws Exception {
        Constructor<?> constructor = userClass.getDeclaredConstructor();
        Object user = constructor.newInstance();
        
        if (email != null) {
            UserEntityValidator.setFieldValue(user, "email", email);
        }
        if (username != null) {
            UserEntityValidator.setFieldValue(user, "username", username);
        }
        
        // Hash password
        String hashedPassword = hashPassword(password);
        try {
            UserEntityValidator.setFieldValue(user, "passwordHash", hashedPassword);
        } catch (Exception e) {
            UserEntityValidator.setFieldValue(user, "password", hashedPassword);
        }
        
        return user;
    }
    
    private boolean userExists(String email, String username) {
        try {
            if (email != null) {
                Object existingUser = findUserByLoginField(email);
                if (existingUser != null) return true;
            }
            if (username != null) {
                Object existingUser = findUserByLoginField(username);
                if (existingUser != null) return true;
            }
            return false;
        } catch (Exception e) {
            return false;
        }
    }
    
    private Object findUserByLoginField(String loginInput) {
        // TODO: This needs proper repository query implementation
        // For now, we'll use findAll and filter (not efficient for production)
        try {
            var allUsers = userRepository.findAll();
            for (Object user : allUsers) {
                String userEmail = UserEntityValidator.getFieldValue(user, "email");
                String userName = UserEntityValidator.getFieldValue(user, "username");
                
                if ((userEmail != null && userEmail.equals(loginInput)) ||
                    (userName != null && userName.equals(loginInput))) {
                    return user;
                }
            }
            return null;
        } catch (Exception e) {
            return null;
        }
    }
    
    private String hashPassword(String password) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            byte[] hash = digest.digest(password.getBytes(StandardCharsets.UTF_8));
            StringBuilder hexString = new StringBuilder();
            for (byte b : hash) {
                String hex = Integer.toHexString(0xff & b);
                if (hex.length() == 1) {
                    hexString.append('0');
                }
                hexString.append(hex);
            }
            return hexString.toString();
        } catch (Exception e) {
            throw new RuntimeException("Failed to hash password", e);
        }
    }
    
    private boolean verifyPassword(String inputPassword, String storedPassword) {
        String hashedInput = hashPassword(inputPassword);
        return hashedInput.equals(storedPassword);
    }
    
    private boolean isValidEmail(String email) {
        return email.contains("@") && email.contains(".");
    }
} 