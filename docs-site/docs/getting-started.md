# Getting Started Guide

This guide explains the steps needed to start working with Jazzy Framework. It covers installing Jazzy, creating a basic application, and getting started with using it.

## Requirements

- Java 17 or higher
- Maven

## Installation

Jazzy is designed to be used as a Maven project. You can start by adding the Jazzy dependency to your project's `pom.xml` file:

```xml
<dependency>
    <groupId>com.jazzyframework</groupId>
    <artifactId>jazzy-framework</artifactId>
    <version>0.3.0</version>
</dependency>
```

## Creating Your First Application

Follow these steps to create a simple "Hello World" application with Jazzy:

### 1. Create the Main Application Class

```java
package com.example;

import jazzyframework.core.Config;
import jazzyframework.core.Server;
import jazzyframework.routing.Router;

public class App {
    public static void main(String[] args) {
        // Create Config
        Config config = new Config();
        config.setEnableMetrics(true); // "/metrics" endpoint is automatically added
        config.setServerPort(8088);
        
        // Create Router
        Router router = new Router();
        
        // Define Hello endpoint
        router.GET("/hello", "sayHello", HelloController.class);
        
        // Start the server
        Server server = new Server(router, config);
        server.start(config.getServerPort());
    }
}
```

### 2. Create a Controller Class

```java
package com.example;

import jazzyframework.http.Request;
import jazzyframework.http.Response;
import static jazzyframework.http.ResponseFactory.response;

public class HelloController {
    public Response sayHello(Request request) {
        return response().json(
            "message", "Hello World!",
            "time", System.currentTimeMillis()
        );
    }
}
```

### 3. Define Routes

There are several ways to define routes:

1. **HTTP Method-Based Definition**:
   
   ```java
   router.GET("/hello", "sayHello", HelloController.class);
   router.POST("/users", "createUser", UserController.class);
   router.PUT("/users/{id}", "updateUser", UserController.class);
   router.DELETE("/users/{id}", "deleteUser", UserController.class);
   ```

   This approach provides direct method calls for HTTP methods and is easy to understand.

2. **Using Path Parameters**:

   ```java
   router.GET("/users/{id}", "getUserById", UserController.class);
   ```

   This contains an `id` parameter that you can access in your Controller class with `request.path("id")`.

## Running the Application

Compile and run your application:

```bash
mvn clean compile exec:java -Dexec.mainClass="com.example.App"
```

Visit `http://localhost:8088/hello` in your browser or check with curl:

```bash
curl http://localhost:8088/hello
```

You should see this JSON response:

```json
{
  "message": "Hello World!",
  "time": 1621234567890
}
```

## A Comprehensive Application Example

For a more advanced example, check out the following App.java file that includes scenarios you might encounter in real applications:

```java
package com.example;

import jazzyframework.core.Config;
import jazzyframework.core.Server;
import jazzyframework.routing.Router;

public class App {
    public static void main(String[] args) {
        Config config = new Config();
        config.setServerPort(8088);
        config.setEnableMetrics(true); // "/metrics" endpoint is automatically added
        
        Router router = new Router();
        
        // User routes
        router.GET("/users/{id}", "getUserById", UserController.class);
        router.GET("/users", "getAllUsers", UserController.class);
        router.POST("/users", "createUser", UserController.class);
        router.PUT("/users/{id}", "updateUser", UserController.class);
        router.DELETE("/users/{id}", "deleteUser", UserController.class);
        
        // Product routes
        router.GET("/products/{id}", "getProduct", ProductController.class);
        router.GET("/products", "listProducts", ProductController.class);
        router.POST("/products", "createProduct", ProductController.class);
        
        // Start the server
        Server server = new Server(router, config);
        server.start(config.getServerPort());
    }
}
```

## Next Steps

After running your basic application, you can explore the more advanced features of Jazzy by reviewing these topics:

- [Routing](routing.md) - HTTP methods, parameter definition
- [HTTP Requests](requests.md) - Processing request parameters, body, and headers
- [HTTP Responses](responses.md) - Creating different response types
- [JSON Operations](json.md) - Working with JSON data
- [ResponseFactory](response_factory.md) - Class that simplifies response creation 