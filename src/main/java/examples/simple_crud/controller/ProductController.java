package examples.simple_crud.controller;

import examples.simple_crud.entity.Product;
import examples.simple_crud.repository.ProductRepository;
import jazzyframework.data.annotations.Crud;
import jazzyframework.data.annotations.CrudOverride;
import jazzyframework.di.annotations.Component;
import jazzyframework.http.ApiResponse;
import jazzyframework.http.Request;
import jazzyframework.http.Response;

/**
 * Product controller demonstrating @Crud annotation with method override.
 * 
 * This controller will automatically have these endpoints generated:
 * - GET /api/products (findAll - but overridden)
 * - GET /api/products/{id} (findById - auto-generated)
 * - POST /api/products (create - auto-generated)
 * - PUT /api/products/{id} (update - auto-generated)
 * - DELETE /api/products/{id} (delete - auto-generated)
 * 
 * - GET /api/products/search?name=laptop (enableSearch = true)
 * - GET /api/products/exists/{id} (enableExists = true)
 */
@Component
@Crud(
    entity = Product.class,
    endpoint = "/api/products",
    enablePagination = true,
    enableSearch = true,
    searchableFields = {"name", "description"},
    enableExists = true
)
public class ProductController {
    
    private final ProductRepository productRepository;
    
    public ProductController(ProductRepository productRepository) {
        this.productRepository = productRepository;
    }
    
    /**
     * Custom implementation of findAll method.
     * This overrides the auto-generated findAll method.
     * Only returns products that are in stock.
     * 
     * @CrudOverride is a custom annotation that if you want to remember override method name, you can use it.
     * 
     * You can use like this:
     * @CrudOverride(value = "Custom findAll that returns all products", operation = "findAll")
     * or like this:
     * @CrudOverride
     */
    @CrudOverride(value = "Custom findAll that returns all products")    
    public Response findAll(Request request) {
        return Response.json(ApiResponse.success("Products retrieved successfully", productRepository.findAll()));
    }
    
    // All other CRUD methods (findById, create, update, delete) will be auto-generated
    // You don't need to implement them - the framework handles them automatically
} 