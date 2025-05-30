# 🚀 CRUD Operations

Get full REST API with **zero boilerplate code**! The `@Crud` annotation automatically generates all standard CRUD endpoints for your entities.

## ⚡ Quick Start

### 1. Create Your Entity
```java
@Entity
@Table(name = "products")
public class Product {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    
    private String name;
    private String description;
    private Double price;
    private Integer stock;
    
    // Constructors, getters, setters...
}
```

### 2. Create Repository
```java
@Component
public interface ProductRepository extends BaseRepository<Product, Long> {
    // Framework handles all basic operations automatically
}
```

### 3. Add @Crud Controller
```java
@Component
@Crud(
    entity = Product.class,
    endpoint = "/api/products",
    enablePagination = true,
    enableSearch = true,
    searchableFields = {"name", "description"}
)
public class ProductController {
    // That's it! All CRUD endpoints are auto-generated
}
```

### 4. Start Using Your API

**🎉 You instantly get these endpoints:**

| Method | Endpoint | Description |
|--------|----------|-------------|
| `GET` | `/api/products/{id}` | Get product by ID |
| `POST` | `/api/products` | Create new product |
| `PUT` | `/api/products/{id}` | Update product |
| `DELETE` | `/api/products/{id}` | Delete product |
| `GET` | `/api/products/search?name=laptop` | Search products |

## 📋 @Crud Configuration

```java
@Crud(
    entity = Product.class,           // Your JPA entity
    endpoint = "/api/products",       // Base URL path
    enablePagination = true,          // Adds ?page=1&size=10 support
    enableSearch = true,              // Adds /search endpoint
    searchableFields = {"name", "description"}, // Fields to search in
    enableExists = true               // Adds /exists/{id} endpoint
)
```

### Configuration Options

| Option | Default | Description |
|--------|---------|-------------|
| `entity` | **Required** | The JPA entity class |
| `endpoint` | **Required** | Base URL path for endpoints |
| `enablePagination` | `false` | Enable pagination support |
| `enableSearch` | `false` | Enable search functionality |
| `searchableFields` | `{}` | Fields to search in (when search enabled) |
| `enableExists` | `false` | Enable exists check endpoint |

## 🎨 Customizing Methods

Need custom logic? Simply override any method:

```java
@Component
@Crud(entity = Product.class, endpoint = "/api/products")
public class ProductController {
    
    private final ProductRepository productRepository;
    
    public ProductController(ProductRepository productRepository) {
        this.productRepository = productRepository;
    }
    
    // Override findAll to show only in-stock products
    @CrudOverride(value = "Returns only in-stock products")
    public Response findAll(Request request) {
        var inStockProducts = productRepository.findAll().stream()
            .filter(product -> product.getStock() > 0)
            .toList();
        return Response.json(ApiResponse.success("In-stock products retrieved", inStockProducts));
    }
    
    // All other methods (findById, create, update, delete) remain auto-generated
}
```

### Manual Route Registration for Overrides

When you override a method, register its route manually:

```java
public static void main(String[] args) {
    Router router = new Router();
    
    // Manual registration for overridden methods
    router.GET("/api/products", "findAll", ProductController.class);
    
    Server server = new Server(router, config);
    server.start(8080);
}
```

## 🧪 Testing Your API

### Create Product
```bash
curl -X POST -H "Content-Type: application/json" \
     -d '{"name":"Gaming Laptop","description":"High-performance laptop","price":1299.99,"stock":5}' \
     "http://localhost:8080/api/products"
```

### Get All Products
```bash
curl "http://localhost:8080/api/products"
```

### Get Product by ID
```bash
curl "http://localhost:8080/api/products/1"
```

### Search Products
```bash
curl "http://localhost:8080/api/products/search?name=laptop"
```

### Update Product
```bash
curl -X PUT -H "Content-Type: application/json" \
     -d '{"name":"Updated Laptop","description":"Updated description","price":1199.99,"stock":3}' \
     "http://localhost:8080/api/products/1"
```

### Delete Product
```bash
curl -X DELETE "http://localhost:8080/api/products/1"
```

## 📊 Response Format

All CRUD endpoints return standardized responses:

```json
{
  "success": true,
  "message": "Product retrieved successfully",
  "data": {
    "id": 1,
    "name": "Gaming Laptop",
    "description": "High-performance laptop",
    "price": 1299.99,
    "stock": 5
  },
  "timestamp": "2023-12-07T10:30:00"
}
```

## 🔧 Requirements

Before using `@Crud`, ensure you have:

1. **Entity Class**: JPA annotated entity
2. **Repository**: Interface extending `BaseRepository<Entity, ID>`
3. **Component Registration**: Repository marked with `@Component`
4. **Database Configuration**: Hibernate/JPA properly configured

## 💡 Best Practices

### ✅ Do's
- Use meaningful entity and endpoint names
- Enable search for user-facing entities
- Override methods only when you need custom logic
- Use `@CrudOverride` for documentation

### ❌ Don'ts
- Don't forget manual route registration for overrides
- Don't enable unnecessary features (keeps API clean)
- Don't override methods unless you need custom behavior

## 🔍 Complete Example

Check out the [Simple CRUD Example](https://github.com/your-repo/jazzy-framework/tree/main/src/main/java/examples/simple_crud) for a working implementation with:

- ✅ Product entity with validation
- ✅ Repository implementation
- ✅ Controller with one custom method
- ✅ Complete test commands
- ✅ Real-world usage patterns

---

**🎯 Result**: With just a few annotations, you get a complete REST API with all CRUD operations, search, pagination, and standardized responses! 