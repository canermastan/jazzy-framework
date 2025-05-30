package examples.simple_crud.repository;

import examples.simple_crud.entity.Product;
import jazzyframework.data.BaseRepository;

public interface ProductRepository extends BaseRepository<Product, Long> {
}