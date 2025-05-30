---
sidebar_position: 4
---

# Authentication & Security

Jazzy Framework provides a comprehensive authentication and security system with JWT tokens, role-based access control, and declarative security configuration. The security system is designed to be both powerful and easy to use, requiring minimal configuration while providing enterprise-grade security features.

## Quick Start

The easiest way to add authentication to your Jazzy application is with the `@EnableJazzyAuth` annotation:

```java
@EnableJazzyAuth(
    userClass = User.class,
    repositoryClass = UserRepository.class,
    loginMethod = LoginMethod.EMAIL,
    jwtSecret = "your-secret-key",
    jwtExpirationHours = 24,
    authBasePath = "/api/auth"
)
public class MyApp {
    public static void main(String[] args) {
        Config config = new Config();
        Router router = new Router();
        
        Server server = new Server(router, config);
        server.start(8080);
        
        // Automatically provides:
        // POST /api/auth/register - User registration
        // POST /api/auth/login    - User login  
        // GET  /api/auth/me       - Current user info
    }
}
```

This single annotation automatically:
- ✅ Creates authentication endpoints (`/register`, `/login`, `/me`)
- ✅ Configures JWT token generation and validation
- ✅ Sets up security interceptors for protected routes
- ✅ Integrates with your user entity and repository
- ✅ Provides role-based access control

## User Entity Requirements

Your user entity must have specific fields for authentication to work:

```java
@Entity
@Table(name = "users")
public class User {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    
    // Required for EMAIL login
    @Column(unique = true)
    private String email;
    
    // Required for USERNAME login  
    @Column(unique = true)
    private String username;
    
    // Required - will be hashed automatically
    private String password;
    
    // Optional - defaults to "USER" 
    private String role = "USER";
    
    // Optional fields
    private String firstName;
    private String lastName;
    private boolean active = true;
    
    // getters and setters...
}
```

### Field Requirements by Login Method

| Login Method | Required Fields |
|--------------|-----------------|
| `LoginMethod.EMAIL` | `email`, `password` |
| `LoginMethod.USERNAME` | `username`, `password` |

## Security Configuration

Use `SecurityConfig` to define URL-based security rules:

```java
@Component
public class AppSecurityConfig extends SecurityConfig {
    
    @Override
    public void configure() {
        // Public endpoints (no authentication required)
        publicEndpoints(
            "/",                    // Home page
            "/api/auth/**",         // Authentication endpoints
            "/api/public/**",       // Public API
            "/health"               // Health check
        );
        
        // Secure endpoints (JWT authentication required)
        requireAuth(
            "/api/user/**",         // User-specific endpoints
            "/api/protected",       // Protected resources
            "/api/data/**"          // Data endpoints
        );
        
        // Admin endpoints (JWT + ADMIN role required)
        requireRole("ADMIN", 
            "/api/admin/**",        // Admin panel
            "/api/users/manage",    // User management
            "/api/system/**"        // System administration
        );
    }
}
```

### Wildcard Pattern Support

Security rules support powerful wildcard patterns:

| Pattern | Description | Examples |
|---------|-------------|----------|
| `/path/*` | Matches single level | `/api/users/123` ✅<br/>`/api/users/123/profile` ❌ |
| `/path/**` | Matches all levels | `/api/users/123` ✅<br/>`/api/users/123/profile` ✅ |
| `/exact` | Exact match only | `/exact` ✅<br/>`/exact/sub` ❌ |

## Authentication Endpoints

When you use `@EnableJazzyAuth`, these endpoints are automatically created:

### POST /api/auth/register

Register a new user account.

**Request:**
```json
{
    "email": "user@example.com",
    "username": "john_doe",
    "password": "securePassword123",
    "firstName": "John",
    "lastName": "Doe"
}
```

**Response (Success):**
```json
{
    "success": true,
    "message": "User registered successfully",
    "data": {
        "user": {
            "id": 1,
            "email": "user@example.com",
            "username": "john_doe",
            "firstName": "John",
            "lastName": "Doe",
            "role": "USER",
            "active": true
        },
        "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
    }
}
```

### POST /api/auth/login

Authenticate and receive JWT token.

**Request (Email Login):**
```json
{
    "email": "user@example.com",
    "password": "securePassword123"
}
```

**Request (Username Login):**
```json
{
    "username": "john_doe", 
    "password": "securePassword123"
}
```

**Response (Success):**
```json
{
    "success": true,
    "message": "Login successful",
    "data": {
        "user": {
            "id": 1,
            "email": "user@example.com",
            "username": "john_doe",
            "role": "USER"
        },
        "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
    }
}
```

### GET /api/auth/me

Get current user information using JWT token.

**Request Headers:**
```
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

**Response:**
```json
{
    "success": true,
    "data": {
        "user": {
            "id": 1,
            "email": "user@example.com",
            "username": "john_doe",
            "firstName": "John",
            "lastName": "Doe",
            "role": "USER",
            "active": true
        }
    }
}
```

## JWT Token Usage

### Client-Side Usage

Include the JWT token in the `Authorization` header for protected requests:

```javascript
// JavaScript example
const token = localStorage.getItem('authToken');

fetch('/api/protected/data', {
    headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json'
    }
})
.then(response => response.json())
.then(data => console.log(data));
```

```java
// Java client example
HttpURLConnection connection = (HttpURLConnection) url.openConnection();
connection.setRequestProperty("Authorization", "Bearer " + token);
connection.setRequestProperty("Content-Type", "application/json");
```

### Token Structure

JWT tokens contain the following claims:

```json
{
    "sub": "1",                    // User ID
    "email": "user@example.com",   // User email
    "roles": ["USER"],             // User roles
    "iat": 1640995200,             // Issued at timestamp
    "exp": 1641081600              // Expiration timestamp
}
```

## Role-Based Access Control

### Built-in Roles

| Role | Description | Usage |
|------|-------------|-------|
| `USER` | Standard user | Default role for registered users |
| `ADMIN` | Administrator | Can access admin endpoints |

### Custom Roles

You can extend the role system by using custom role values:

```java
// In your User entity
private String role = "MODERATOR"; // Custom role

// In SecurityConfig
@Override
public void configure() {
    requireRole("ADMIN", "/api/admin/**");
    requireRole("MODERATOR", "/api/moderate/**");
    // Note: Currently only ADMIN role is fully supported
    // Custom roles are stored but not enforced by SecurityInterceptor
}
```

## Advanced Configuration

### Custom JWT Configuration

```java
@EnableJazzyAuth(
    userClass = User.class,
    repositoryClass = UserRepository.class,
    loginMethod = LoginMethod.EMAIL,
    
    // JWT Configuration
    jwtSecret = "your-256-bit-secret-key-here",
    jwtExpirationHours = 168,        // 7 days
    
    // Endpoint Configuration  
    authBasePath = "/auth",          // Changes to /auth/* instead of /api/auth/*
)
public class MyApp {
    // ...
}
```

### Multiple Login Methods

Currently, you can choose one login method per application:

```java
// Email-based login
@EnableJazzyAuth(
    loginMethod = LoginMethod.EMAIL,
    // ... other config
)

// Username-based login  
@EnableJazzyAuth(
    loginMethod = LoginMethod.USERNAME,
    // ... other config
)
```

### Password Security

Passwords are automatically hashed using BCrypt with a secure salt:

- ✅ Passwords are never stored in plain text
- ✅ BCrypt with automatic salt generation
- ✅ Secure password verification during login
- ✅ Protection against rainbow table attacks

## Error Handling

### Authentication Errors

**401 Unauthorized** - Missing or invalid JWT token:
```json
{
    "error": "Authentication required"
}
```

**403 Forbidden** - Valid token but insufficient permissions:
```json
{
    "error": "Admin access required"
}
```

### Registration Errors

**400 Bad Request** - Validation errors:
```json
{
    "success": false,
    "message": "User with email user@example.com already exists"
}
```

### Login Errors

**401 Unauthorized** - Invalid credentials:
```json
{
    "success": false,
    "message": "Invalid credentials"
}
```

## Integration Examples

### With Auto-CRUD System

Combine authentication with CRUD for secure APIs:

```java
@EnableJazzyAuth(
    userClass = User.class,
    repositoryClass = UserRepository.class,
    loginMethod = LoginMethod.EMAIL
)
public class SecureApp {
    public static void main(String[] args) {
        // Authentication endpoints: /api/auth/*
        // CRUD endpoints will respect SecurityConfig rules
        
        Config config = new Config();
        Router router = new Router();
        
        Server server = new Server(router, config);
        server.start(8080);
    }
}

@Component
@Crud(
    entity = Product.class,
    endpoint = "/api/products",
    enablePagination = true
)
public class ProductController {
    // All endpoints automatically protected by SecurityConfig
    // GET /api/products - public if configured
    // POST /api/products - secure if configured
}
```

### Custom Security Logic

Add custom security logic to your controllers:

```java
@Component
public class UserController {
    
    public Response getProfile(Request request) {
        // Get user from JWT token (automatically validated by SecurityInterceptor)
        String authHeader = request.header("Authorization");
        if (authHeader != null && authHeader.startsWith("Bearer ")) {
            String token = authHeader.substring(7);
            
            // Extract user info from token (optional, for additional checks)
            JwtUtil jwtUtil = // get from DI container
            JwtClaims claims = jwtUtil.validateToken(token);
            String userId = claims.getUserId();
            
            // Your custom logic here
            return Response.json(JSON.of("userId", userId));
        }
        
        return Response.json(JSON.of("error", "No token")).status(401);
    }
}
```

## Best Practices

### Security
- ✅ Use strong JWT secrets (256+ bits)
- ✅ Set appropriate token expiration times
- ✅ Use HTTPS in production
- ✅ Validate input data properly
- ✅ Log authentication attempts
- ❌ Don't store JWT tokens in local storage (use httpOnly cookies)
- ❌ Don't use weak passwords
- ❌ Don't expose JWT secrets in logs

### Architecture
- ✅ Keep SecurityConfig rules simple and clear
- ✅ Use specific patterns over broad wildcards when possible
- ✅ Group related endpoints under common paths
- ✅ Document your security rules
- ✅ Test security configurations thoroughly

### Development
```java
// Good: Clear and organized
publicEndpoints("/", "/api/auth/**", "/health");
requireAuth("/api/user/**", "/api/data/**");
requireRole("ADMIN", "/api/admin/**");

// Avoid: Overlapping or conflicting rules
publicEndpoints("/api/**");           // Too broad
requireAuth("/api/user/**");          // Conflicts with above
```

## Migration Guide

### From No Authentication (v0.4 and earlier)

1. **Add User Entity**
```java
@Entity
public class User {
    @Id @GeneratedValue
    private Long id;
    
    @Column(unique = true)
    private String email;
    
    private String password;
    private String role = "USER";
    
    // getters/setters
}
```

2. **Add User Repository**
```java
@Component
public interface UserRepository extends BaseRepository<User, Long> {
    Optional<User> findByEmail(String email);
}
```

3. **Add Security Config**
```java
@Component 
public class SecurityConfig extends SecurityConfig {
    @Override
    public void configure() {
        publicEndpoints("/", "/api/auth/**");
        requireAuth("/api/**");
    }
}
```

4. **Enable Authentication**
```java
@EnableJazzyAuth(
    userClass = User.class,
    repositoryClass = UserRepository.class,
    loginMethod = LoginMethod.EMAIL
)
public class MyApp {
    // ... rest of your app unchanged
}
```

Your existing endpoints will now be protected according to your SecurityConfig rules!

## Troubleshooting

### Common Issues

**Authentication endpoints not found (404)**
- ✅ Check `@EnableJazzyAuth` annotation is present
- ✅ Verify `authBasePath` configuration  
- ✅ Ensure user repository is registered in DI container

**Security rules not working**
- ✅ Verify SecurityConfig extends `SecurityConfig`
- ✅ Check SecurityConfig is annotated with `@Component`
- ✅ Ensure `configure()` method is implemented
- ✅ Test endpoint patterns with exact URLs

**JWT token validation fails**
- ✅ Check JWT secret configuration
- ✅ Verify token format in Authorization header
- ✅ Check token expiration time
- ✅ Ensure token includes "Bearer " prefix

**Registration/login fails silently**
- ✅ Check database configuration
- ✅ Verify user entity field mappings
- ✅ Check repository method signatures
- ✅ Enable SQL logging to see database queries

### Debugging Tips

Enable debug logging:
```java
// Add to application.properties
logging.level.jazzyframework.security=DEBUG
```

Test authentication manually:
```bash
# Register user
curl -X POST http://localhost:8080/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"test123"}'

# Login
curl -X POST http://localhost:8080/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"test123"}'

# Access protected endpoint
curl http://localhost:8080/api/protected \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
``` 