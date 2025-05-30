# Changelog

All notable changes to Jazzy Framework will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.5.0] - 2025-01-27

### Added
- **🔐 Comprehensive Security & Authentication System**
  - `@EnableJazzyAuth` annotation for one-line authentication setup
  - JWT token system with secure generation and validation
  - `SecurityConfig` abstract class for declarative URL-based security rules
  - Built-in authentication endpoints: `/register`, `/login`, `/me`
  - Role-based access control with USER and ADMIN roles
  - `SecurityInterceptor` for automatic request validation and protection

- **🎟️ JWT Token Management**
  - Configurable JWT secrets and expiration times
  - Secure token generation with BCrypt password hashing
  - Automatic token validation in protected endpoints
  - Token structure with user ID, email, roles, and timestamps

- **🛡️ SecurityConfig System**
  - Wildcard pattern support (`*`, `**`) for endpoint matching
  - Three security levels: public, secure (JWT required), admin (JWT + ADMIN role)
  - Flexible configuration with method-based security rules
  - Integration with existing DI container and routing system

- **🚦 Authentication Endpoints**
  - `POST /api/auth/register` - User registration with automatic password hashing
  - `POST /api/auth/login` - Authentication with JWT token response
  - `GET /api/auth/me` - Current user information retrieval
  - Standardized JSON responses with success/error handling

- **👤 User Entity Validation**
  - `UserEntityValidator` for automatic entity field validation
  - Support for EMAIL and USERNAME login methods
  - Required field checking and entity structure validation
  - Integration with existing repository pattern

- **🔄 Framework Integration**
  - `AuthProcessor` for automatic authentication configuration
  - Enhanced `RequestHandler` with SecurityInterceptor support
  - Enhanced `Server` with AuthProcessor integration
  - Enhanced `DIContainer` with component scanning methods

### Changed
- Updated framework version to 0.5.0
- Enhanced README.md with comprehensive security documentation
- Updated project structure documentation with security components
- Enhanced documentation site with authentication guide

### Technical Details
- Added 9 new security-related classes in `jazzyframework.security` package
- Automatic password hashing using BCrypt with secure salts
- JWT implementation without external dependencies for minimal footprint
- Pattern-based URL matching with efficient wildcard support
- Seamless integration with existing CRUD and DI systems

## [0.3.1] - 2025-01-27

### Fixed
- **BREAKING**: Fixed deprecated Hibernate API usage in BaseRepositoryImpl
  - Replaced deprecated `session.createQuery()` with `session.createMutationQuery()` for DELETE operations
  - This ensures compatibility with future Hibernate versions and removes deprecation warnings

### Changed
- Updated Hibernate ORM from 6.4.1.Final to 6.4.10.Final for better performance and security
- Updated H2 database from 2.2.224 to 2.2.232 for latest bug fixes

### Added
- Enhanced transaction management in BaseRepositoryImpl with new helper methods:
  - `executeInTransaction()` for operations that return values
  - `executeInTransactionVoid()` for void operations
  - Both methods include proper rollback handling for improved reliability

### Technical Details
- Improved error handling in repository operations
- Better transaction safety with automatic rollback on exceptions
- Removed FIXME comments related to deprecated API usage

## [0.3.0] - 2025-01-26

### Added
- Comprehensive Spring Data JPA-like query system
- Method name parsing for automatic query generation
- Support for @Query, @Modifying, and @QueryHint annotations
- Enhanced RepositoryFactory with query method support
- Database-level query execution for improved performance

### Fixed
- Resolved "socket hang up" errors in exception handling
- Fixed excessive logging in ORM components
- Improved code quality and reduced duplication in repository implementations

### Changed
- Migrated from memory-based filtering to database-level queries
- Enhanced query method parser with support for complex operations
- Improved error messages and debugging capabilities

## [0.2.0] - 2025-01-25

### Added
- Comprehensive dependency injection system
- Spring-like annotations (@Component, @Named, @Primary, @PostConstruct, @PreDestroy)
- Zero-configuration DI container
- Automatic component scanning and registration

### Changed
- Enhanced framework architecture with DI support
- Improved documentation and examples

## [0.1.0] - 2025-01-24

### Added
- Initial release of Jazzy Framework
- Basic web framework functionality
- Fluent API for request/response handling
- Simple routing system
- JSON operations support
- Basic validation system 