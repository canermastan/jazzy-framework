package jazzyframework.security.jwt;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.Base64;
import java.util.HashMap;
import java.util.Map;

/**
 * JWT Token Utility for Jazzy Framework
 * Simple JWT implementation without external dependencies
 */
public class JwtUtil {
    
    private final String secret;
    private final long expirationHours;
    
    public JwtUtil(String secret, long expirationHours) {
        this.secret = secret != null && !secret.isEmpty() ? secret : generateRandomSecret();
        this.expirationHours = expirationHours;
    }
    
    /**
     * Generate JWT token for user
     */
    public String generateToken(String userId, String email, String[] roles) {
        try {
            // Header
            Map<String, Object> header = new HashMap<>();
            header.put("alg", "HS256");
            header.put("typ", "JWT");
            
            // Payload
            Map<String, Object> payload = new HashMap<>();
            payload.put("sub", userId);
            payload.put("email", email);
            payload.put("roles", roles);
            payload.put("iat", Instant.now().getEpochSecond());
            payload.put("exp", Instant.now().plus(expirationHours, ChronoUnit.HOURS).getEpochSecond());
            
            // Encode
            String encodedHeader = base64UrlEncode(toJson(header));
            String encodedPayload = base64UrlEncode(toJson(payload));
            String signature = sign(encodedHeader + "." + encodedPayload);
            
            return encodedHeader + "." + encodedPayload + "." + signature;
            
        } catch (Exception e) {
            throw new RuntimeException("Failed to generate JWT token", e);
        }
    }
    
    /**
     * Validate JWT token and extract claims
     */
    public JwtClaims validateToken(String token) {
        try {
            String[] parts = token.split("\\.");
            if (parts.length != 3) {
                throw new IllegalArgumentException("Invalid JWT format");
            }
            
            String header = parts[0];
            String payload = parts[1];
            String signature = parts[2];
            
            // Verify signature
            String expectedSignature = sign(header + "." + payload);
            if (!signature.equals(expectedSignature)) {
                throw new IllegalArgumentException("Invalid JWT signature");
            }
            
            // Parse payload
            String payloadJson = new String(Base64.getUrlDecoder().decode(payload), StandardCharsets.UTF_8);
            return parseJwtClaims(payloadJson);
            
        } catch (Exception e) {
            throw new RuntimeException("Failed to validate JWT token", e);
        }
    }
    
    /**
     * Extract user ID from token without full validation (for quick checks)
     */
    public String extractUserId(String token) {
        try {
            String[] parts = token.split("\\.");
            if (parts.length != 3) return null;
            
            String payloadJson = new String(Base64.getUrlDecoder().decode(parts[1]), StandardCharsets.UTF_8);
            return extractValueFromJson(payloadJson, "sub");
        } catch (Exception e) {
            return null;
        }
    }
    
    private String sign(String data) throws Exception {
        Mac mac = Mac.getInstance("HmacSHA256");
        SecretKeySpec secretKeySpec = new SecretKeySpec(secret.getBytes(StandardCharsets.UTF_8), "HmacSHA256");
        mac.init(secretKeySpec);
        byte[] signature = mac.doFinal(data.getBytes(StandardCharsets.UTF_8));
        return base64UrlEncode(signature);
    }
    
    private String base64UrlEncode(String input) {
        return base64UrlEncode(input.getBytes(StandardCharsets.UTF_8));
    }
    
    private String base64UrlEncode(byte[] input) {
        return Base64.getUrlEncoder().withoutPadding().encodeToString(input);
    }
    
    private String generateRandomSecret() {
        return "jazzy-framework-secret-" + System.currentTimeMillis() + "-" + Math.random();
    }
    
    private String toJson(Map<String, Object> map) {
        StringBuilder json = new StringBuilder("{");
        boolean first = true;
        for (Map.Entry<String, Object> entry : map.entrySet()) {
            if (!first) json.append(",");
            json.append("\"").append(entry.getKey()).append("\":");
            
            Object value = entry.getValue();
            if (value instanceof String) {
                json.append("\"").append(value).append("\"");
            } else if (value instanceof String[]) {
                json.append("[");
                String[] arr = (String[]) value;
                for (int i = 0; i < arr.length; i++) {
                    if (i > 0) json.append(",");
                    json.append("\"").append(arr[i]).append("\"");
                }
                json.append("]");
            } else {
                json.append(value);
            }
            first = false;
        }
        json.append("}");
        return json.toString();
    }
    
    private JwtClaims parseJwtClaims(String payloadJson) {
        // Simple JSON parsing for JWT claims
        String userId = extractValueFromJson(payloadJson, "sub");
        String email = extractValueFromJson(payloadJson, "email");
        String expStr = extractValueFromJson(payloadJson, "exp");
        
        long exp = expStr != null ? Long.parseLong(expStr) : 0;
        if (exp > 0 && Instant.now().getEpochSecond() > exp) {
            throw new RuntimeException("JWT token expired");
        }
        
        // Parse roles array
        String[] roles = parseRolesArray(payloadJson);
        
        return new JwtClaims(userId, email, roles);
    }
    
    /**
     * Parses roles array from JWT payload JSON
     */
    private String[] parseRolesArray(String json) {
        String pattern = "\"roles\":[";
        int start = json.indexOf(pattern);
        if (start == -1) {
            return new String[0]; // No roles found
        }
        
        start += pattern.length();
        int end = json.indexOf("]", start);
        if (end == -1) {
            return new String[0]; // Malformed array
        }
        
        String rolesStr = json.substring(start, end);
        if (rolesStr.trim().isEmpty()) {
            return new String[0]; // Empty array
        }
        
        // Simple parsing: split by comma and remove quotes
        String[] parts = rolesStr.split(",");
        String[] roles = new String[parts.length];
        for (int i = 0; i < parts.length; i++) {
            roles[i] = parts[i].trim().replace("\"", "");
        }
        
        return roles;
    }
    
    private String extractValueFromJson(String json, String key) {
        String pattern = "\"" + key + "\":\"";
        int start = json.indexOf(pattern);
        if (start == -1) {
            // Try without quotes (for numbers)
            pattern = "\"" + key + "\":";
            start = json.indexOf(pattern);
            if (start == -1) return null;
            start += pattern.length();
            int end = json.indexOf(",", start);
            if (end == -1) end = json.indexOf("}", start);
            return end > start ? json.substring(start, end) : null;
        }
        
        start += pattern.length();
        int end = json.indexOf("\"", start);
        return end > start ? json.substring(start, end) : null;
    }
} 