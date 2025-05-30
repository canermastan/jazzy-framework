# Simple CRUD Example

This example demonstrates how to use the Jazzy Framework's @Crud annotation in the simplest way possible.

## 📁 File Structure

```
simpleCrud/
├── Product.java              # Entity class (JPA entity)
├── ProductRepository.java    # Repository interface
├── ProductRepositoryImpl.java # Repository implementation
├── ProductController.java    # Controller (one method overridden)
├── SimpleCrudApp.java       # Main application
└── README.md               # This file
```

## 🎯 Features

### ✅ Automatic CRUD Operations
- `GET /api/products/{id}` - Get product by ID
- `POST /api/products` - Create new product  
- `PUT /api/products/{id}` - Update product
- `DELETE /api/products/{id}` - Delete product
- `GET /api/products/search?name=laptop` - Search products

### 🎨 Customized Method
- `GET /api/products` - **Overridden!** Shows only products in stock

## 🔧 How It Works?

### 1. @Crud Annotation
```java
@Crud(
    entity = Product.class,
    endpoint = "/api/products",
    enablePagination = true,
    enableSearch = true,
    searchableFields = {"name", "description"}
)
public class ProductController {
    // ...
}
```

### 2. Overridden Method
```java
@CrudOverride(value = "Custom findAll that filters out-of-stock products", operation = "findAll")
public Response findAll(Request request) {
    // Return only products in stock
    var inStockProducts = allProducts.stream()
        .filter(product -> product.getStock() != null && product.getStock() > 0)
        .toList();
    // ...
}
```

### 3. Manual Route Registration
```java
// Manual registration required for overridden methods!
router.GET("/api/products", "findAll", ProductController.class);
```

## 🚀 Running the Application

```bash
# Compile and run with Maven
mvn compile exec:java -Dexec.mainClass="examples.simple_crud.SimpleCrudApp"

# Or run SimpleCrudApp.main() method from your IDE
```

## 🧪 Test Commands

### Create Product
```bash
curl -X POST -H "Content-Type: application/json" \
     -d '{"name":"Gaming Laptop","description":"High-performance gaming laptop","price":1299.99,"stock":5}' \
     "http://localhost:8080/api/products"
```

### List In-Stock Products (Overridden)
```bash
curl "http://localhost:8080/api/products"
```

### Get Product by ID (Automatic)
```bash
curl "http://localhost:8080/api/products/1"
```

### Search Products (Automatic)
```bash
curl "http://localhost:8080/api/products/search?name=laptop"
```

### Update Product (Automatic)
```bash
curl -X PUT -H "Content-Type: application/json" \
     -d '{"name":"Updated Laptop","description":"Updated description","price":1199.99,"stock":3}' \
     "http://localhost:8080/api/products/1"
```

### Delete Product (Automatic)
```bash
curl -X DELETE "http://localhost:8080/api/products/1"
```

## 💡 Important Notes

1. **Overridden Methods**: Manual route registration is required for overridden methods
2. **Automatic Methods**: All other CRUD operations are automatically generated
3. **Repository Pattern**: A repository extending BaseRepository interface is required
4. **DI Integration**: All components are automatically connected via dependency injection

## 📝 Example Response

### Successful Response
```json
{
  "success": true,
  "message": "In-stock products retrieved successfully",
  "data": [
    {
      "id": 1,
      "name": "Gaming Laptop",
      "description": "High-performance gaming laptop",
      "price": 1299.99,
      "stock": 5
    }
  ],
  "timestamp": "2023-12-07T10:30:00",
  "metadata": {
    "totalProducts": 3,
    "inStockCount": 1,
    "outOfStockCount": 2
  }
}
```

This example demonstrates the power and ease of the @Crud annotation - maximum functionality with minimum code! 