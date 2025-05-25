package jazzyframework.data;

import java.util.List;
import java.util.Optional;

/**
 * Base repository interface providing common CRUD operations.
 * 
 * <p>This interface is inspired by Spring Data JPA's JpaRepository and provides
 * a similar set of basic operations for entities. All repository interfaces
 * should extend this interface to get automatic implementation of common operations.
 * 
 * <p>Example usage:
 * <pre>
 * public interface UserRepository extends BaseRepository&lt;User, Long&gt; {
 *     // Custom query methods can be added here
 *     Optional&lt;User&gt; findByEmail(String email);
 *     List&lt;User&gt; findByActiveTrue();
 * }
 * </pre>
 * 
 * <p>The generic parameters are:
 * <ul>
 *   <li>{@code T} - The entity type</li>
 *   <li>{@code ID} - The type of the entity's primary key</li>
 * </ul>
 * 
 * @param <T> the entity type
 * @param <ID> the type of the entity's primary key
 * 
 * @since 0.3.0
 * @author Caner Mastan
 */
public interface BaseRepository<T, ID> {

    /**
     * Saves a given entity.
     * 
     * @param entity the entity to save; must not be null
     * @return the saved entity; will never be null
     * @throws IllegalArgumentException if entity is null
     */
    T save(T entity);

    /**
     * Saves all given entities.
     * 
     * @param entities the entities to save; must not be null and must not contain null elements
     * @return the saved entities; will never be null
     * @throws IllegalArgumentException if entities is null or contains null elements
     */
    List<T> saveAll(Iterable<T> entities);

    /**
     * Retrieves an entity by its id.
     * 
     * @param id the id of the entity to retrieve; must not be null
     * @return the entity with the given id or Optional#empty() if none found
     * @throws IllegalArgumentException if id is null
     */
    Optional<T> findById(ID id);

    /**
     * Returns whether an entity with the given id exists.
     * 
     * @param id the id of the entity; must not be null
     * @return true if an entity with the given id exists, false otherwise
     * @throws IllegalArgumentException if id is null
     */
    boolean existsById(ID id);

    /**
     * Returns all instances of the type.
     * 
     * @return all entities
     */
    List<T> findAll();

    /**
     * Returns all instances of the type with the given IDs.
     * 
     * @param ids the IDs of the entities to retrieve; must not be null
     * @return the entities with the given IDs
     * @throws IllegalArgumentException if ids is null
     */
    List<T> findAllById(Iterable<ID> ids);

    /**
     * Returns the number of entities available.
     * 
     * @return the number of entities
     */
    long count();

    /**
     * Deletes the entity with the given id.
     * 
     * @param id the id of the entity to delete; must not be null
     * @throws IllegalArgumentException if id is null
     */
    void deleteById(ID id);

    /**
     * Deletes a given entity.
     * 
     * @param entity the entity to delete; must not be null
     * @throws IllegalArgumentException if entity is null
     */
    void delete(T entity);

    /**
     * Deletes all instances of the type with the given IDs.
     * 
     * @param ids the IDs of the entities to delete; must not be null
     * @throws IllegalArgumentException if ids is null
     */
    void deleteAllById(Iterable<ID> ids);

    /**
     * Deletes the given entities.
     * 
     * @param entities the entities to delete; must not be null
     * @throws IllegalArgumentException if entities is null
     */
    void deleteAll(Iterable<T> entities);

    /**
     * Deletes all entities managed by the repository.
     */
    void deleteAll();

    /**
     * Flushes all pending changes to the database.
     */
    void flush();

    /**
     * Saves an entity and flushes changes instantly.
     * 
     * @param entity the entity to save
     * @return the saved entity
     */
    T saveAndFlush(T entity);

    /**
     * Deletes the given entities in a batch which means it will create a single Query.
     * 
     * @param entities the entities to delete
     */
    void deleteInBatch(Iterable<T> entities);

    /**
     * Deletes all entities in a batch call.
     */
    void deleteAllInBatch();
} 