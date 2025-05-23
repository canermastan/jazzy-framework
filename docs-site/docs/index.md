# Jazzy Framework

Jazzy is a lightweight, fast, and easy-to-use web framework developed in Java. Inspired by Laravel's elegant syntax, Jazzy brings modern, fluent APIs to the Java world with enterprise-level dependency injection capabilities.

## Key Features

- **Lightweight Architecture**: Provides core functionality with minimal dependencies
- **Fluent API**: Easy and readable coding with Laravel-like fluent interfaces
- **Simple Routing**: Simple routing mechanism based on HTTP methods
- **Request Processing**: Easily process request parameters, body, and headers
- **Response Generation**: Create JSON, HTML, and other response types
- **JSON Operations**: Easy JSON creation and processing capabilities
- **Validation**: Powerful validation system with Fluent API
- **🆕 Dependency Injection**: Spring-like DI system with zero configuration (v0.2+)
- **🆕 Automatic Component Discovery**: No manual setup required
- **🆕 Advanced Annotations**: @Component, @Named, @Primary, @PostConstruct, @PreDestroy
- **🆕 Lifecycle Management**: Proper initialization and cleanup
- **🆕 Multiple Scopes**: Singleton and Prototype bean management

## What's New in v0.2

Jazzy Framework 0.2 introduces a comprehensive **dependency injection system** that brings enterprise-level capabilities while maintaining the framework's simplicity:

- **Zero Configuration DI**: Automatic component discovery with no XML or manual setup
- **Spring-like Annotations**: Familiar annotations for Spring developers
- **Constructor Injection**: Clean, testable dependency injection
- **Named Injection**: Handle multiple implementations with `@Named`
- **Primary Bean Selection**: Conflict resolution with `@Primary`
- **Lifecycle Management**: `@PostConstruct` and `@PreDestroy` callbacks
- **Scope Management**: `@Singleton` (default) and `@Prototype` scopes
- **Framework Integration**: DI works seamlessly with routing and controllers

## Inspiration

Jazzy Framework is inspired by the elegant and user-friendly APIs of the Laravel PHP framework and Spring Boot's powerful dependency injection. Laravel's fluent method calls like `response()->json()` combined with Spring's annotation-driven DI form the core design philosophy of Jazzy.

## Why Jazzy?

Jazzy provides a modern and clean API for Java web applications with enterprise-ready features. It's simple to use for both beginners and experienced developers and doesn't require detailed configuration. In particular:

- **Quick Start**: Create a working API in minutes with minimal setup
- **Readable Code**: Write code that is easy to read and maintain thanks to fluent APIs
- **Enterprise Ready**: Dependency injection for scalable, maintainable applications
- **Zero Configuration**: DI works out of the box with automatic component discovery
- **Lightweight Structure**: Avoid the burden of complex frameworks
- **Easy Learning**: Familiar for those who know Laravel/Spring-like structures, intuitive for those who don't

## Version

Jazzy Framework is currently at version **0.2.0**. This major release introduces dependency injection capabilities while maintaining full backward compatibility with 0.1.x applications.

## Getting Started

To start working with Jazzy, you can review the [Getting Started Guide](getting-started.md).

## Contents

### Core Framework
1. [Getting Started Guide](getting-started.md) - Installation and basic application
2. [Routing](routing.md) - Route definition and usage
3. [HTTP Requests](requests.md) - Request class and request processing
4. [HTTP Responses](responses.md) - Response class and response generation
5. [JSON Operations](json.md) - Creating and processing JSON data
6. [ResponseFactory](response_factory.md) - Class that simplifies response creation
7. [Validation](validation.md) - Request validation and error handling
8. [Examples](examples.md) - Complete application examples

### Dependency Injection (v0.2+)
9. [Dependency Injection](dependency-injection.md) - Comprehensive DI guide
10. [DI Examples](di-examples.md) - Complete DI examples and patterns

## Migration from 0.1 to 0.2

Upgrading to 0.2 is **seamless** - all existing 0.1 code continues to work without modification. The dependency injection system is purely additive:

- Existing controllers and services work as before
- Add `@Component` annotations to enable DI for specific classes
- Gradually migrate to DI-based architecture
- Mix manual instantiation with DI in the same application 