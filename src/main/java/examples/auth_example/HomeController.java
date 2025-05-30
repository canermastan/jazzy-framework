package examples.auth_example;

import jazzyframework.http.Request;
import jazzyframework.http.Response;
import jazzyframework.http.JSON;

/**
 * Home Controller for Auth Example
 */
public class HomeController {
    
    /**
     * Welcome endpoint
     * GET /
     */
    public Response home(Request request) {
        return Response.json(
            JSON.of(
                "message", "Welcome to Jazzy Auth Example!",
                "endpoints", new String[]{
                    "POST /api/auth/register",
                    "POST /api/auth/login", 
                    "GET /api/auth/me",
                    "GET /api/protected (requires Bearer token)"
                }
            )
        );
    }
    
    /**
     * Protected endpoint example - JWT validation handled automatically by SecurityInterceptor
     * GET /api/protected
     */
    public Response protectedEndpoint(Request request) {
        return Response.json(
            JSON.of(
                "message", "This is a protected endpoint!",
                "note", "You successfully accessed a protected endpoint with JWT!",
                "info", "JWT validation was handled automatically by SecurityInterceptor"
            )
        );
    }
} 