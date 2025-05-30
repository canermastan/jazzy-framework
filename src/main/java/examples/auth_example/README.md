# Jazzy Framework - Authentication Example

Bu örnek uygulama, `@EnableJazzyAuth` annotation'ının nasıl kullanılacağını gösterir.

## Özellikler

- 📧 **Email tabanlı authentication**
- 🔐 **JWT token sistemi** 
- 🚀 **Zero-configuration setup**
- 📝 **Otomatik endpoint'ler**

## Otomatik Oluşturulan Endpoint'ler

`@EnableJazzyAuth` annotation'ı otomatik olarak şu endpoint'leri oluşturur:

### 1. Kullanıcı Kaydı
```
POST /api/auth/register
Content-Type: application/json

{
    "email": "user@example.com",
    "password": "password123",
    "name": "John Doe"
}
```

**Başarılı Yanıt:**
```json
{
    "message": "User registered successfully",
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "user": {
        "id": "1",
        "email": "user@example.com"
    }
}
```

### 2. Kullanıcı Girişi
```
POST /api/auth/login
Content-Type: application/json

{
    "email": "user@example.com", 
    "password": "password123"
}
```

**Başarılı Yanıt:**
```json
{
    "message": "Login successful",
    "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "user": {
        "id": "1",
        "email": "user@example.com"
    }
}
```

### 3. Mevcut Kullanıcı Bilgisi
```
GET /api/auth/me
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

**Başarılı Yanıt:**
```json
{
    "user": {
        "id": "1",
        "email": "user@example.com",
        "username": null
    }
}
```

## Nasıl Çalıştırılır

1. **Uygulamayı başlatın:**
   ```bash
   javac -cp "lib/*" src/main/java/examples/auth_example/*.java
   java -cp "lib/*:src/main/java" examples.auth_example.AuthExampleApp
   ```

2. **Test edin:**
   ```bash
   # Kullanıcı kaydı
   curl -X POST http://localhost:8080/api/auth/register \
     -H "Content-Type: application/json" \
     -d '{"email":"test@example.com","password":"123456","name":"Test User"}'

   # Giriş yapın
   curl -X POST http://localhost:8080/api/auth/login \
     -H "Content-Type: application/json" \
     -d '{"email":"test@example.com","password":"123456"}'

   # Token ile kullanıcı bilgisi alın
   curl -X GET http://localhost:8080/api/auth/me \
     -H "Authorization: Bearer YOUR_TOKEN_HERE"
   ```

## Configuration

`@EnableJazzyAuth` annotation'ı şu parametreleri destekler:

```java
@EnableJazzyAuth(
    userClass = User.class,              // Kullanıcı entity class'ı
    repositoryClass = UserRepository.class, // Kullanıcı repository interface'i
    loginMethod = LoginMethod.EMAIL,     // EMAIL, USERNAME, veya BOTH
    jwtExpirationHours = 24,            // JWT token süresi (saat)
    authBasePath = "/api/auth"          // Auth endpoint'lerinin base path'i
)
```

## Gereksinimler

### User Entity

User class'ınız şu field'lara sahip olmalı:

- `id` (Long) - Kullanıcı ID'si
- `email` (String) - Email adresi (EMAIL veya BOTH login method için)
- `username` (String) - Kullanıcı adı (USERNAME veya BOTH login method için)  
- `password` (String) - Şifre (otomatik hash'lenir)

### User Repository

User repository interface'iniz `BaseRepository`'yi extend etmelidir:

```java
public interface UserRepository extends BaseRepository<User, Long> {
    // İsteğe bağlı özel query methodları ekleyebilirsiniz
    // Optional<User> findByEmail(String email);
    // Optional<User> findByUsername(String username);
}
```

**Not:** Repository interface'i otomatik olarak Jazzy Framework'ün DI container'ında register edilir.

## Güvenlik Konfigürasyonu (Opsiyonel)

Endpoint'leri korumak için `SecurityConfig` class'ı oluşturabilirsiniz:

```java
@Component
public class AppSecurityConfig extends SecurityConfig {
    
    @Override
    public void configure() {
        // Public endpoint'ler (authentication gerektirmez)
        publicEndpoints(
            "/",                    // Ana sayfa
            "/api/auth/**"          // Tüm auth endpoint'leri
        );
        
        // Secure endpoint'ler (authentication gerektirir)
        requireAuth(
            "/api/protected",       // Korumalı endpoint
            "/api/user/**"          // Kullanıcıya özel endpoint'ler
        );
        
        // Admin endpoint'leri (ADMIN rolü gerektirir)
        requireRole("ADMIN", 
            "/api/admin/**"         // Admin endpoint'leri
        );
    }
}
```

### Wildcard Destek

SecurityConfig şu wildcard'ları destekler:

- `*` - Tek path segment'i ile eşleşir
- `**` - Herhangi sayıda path segment'i ile eşleşir

**Örnekler:**
- `/api/auth/**` → `/api/auth/login`, `/api/auth/register`, `/api/auth/user/profile` ile eşleşir
- `/user/*` → `/user/123` ile eşleşir ama `/user/123/profile` ile eşleşmez

## Avantajları

- ✅ **Zero Configuration** - Sadece annotation ekleyin
- ✅ **Otomatik JWT** - Token üretimi ve doğrulama otomatik
- ✅ **Flexible User Entity** - Kendi User class'ınızı kullanın
- ✅ **Multiple Login Methods** - Email, username veya her ikisi
- ✅ **Standard Java** - External dependency yok 