# Changelog

All notable changes to Jazzy Framework will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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