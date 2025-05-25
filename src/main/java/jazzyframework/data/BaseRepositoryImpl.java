package jazzyframework.data;

import org.hibernate.Session;
import org.hibernate.SessionFactory;
import org.hibernate.Transaction;
import org.hibernate.query.Query;

import jakarta.persistence.Id;
import java.lang.reflect.Field;
import java.lang.reflect.ParameterizedType;
import java.lang.reflect.Type;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.logging.Logger;

/**
 * Default implementation of BaseRepository using Hibernate SessionFactory.
 * 
 * <p>This class provides concrete implementations for all CRUD operations
 * defined in BaseRepository interface. It uses Hibernate Session for
 * database operations and handles transactions automatically.
 * 
 * <p>Key features:
 * <ul>
 *   <li>Automatic transaction management</li>
 *   <li>Generic type resolution for entity operations</li>
 *   <li>Efficient batch operations</li>
 *   <li>Proper exception handling and logging</li>
 * </ul>
 * 
 * @param <T> the entity type
 * @param <ID> the type of the entity's primary key
 * 
 * @since 0.3.0
 * @author Caner Mastan
 */
public class BaseRepositoryImpl<T, ID> implements BaseRepository<T, ID> {
    private static final Logger logger = Logger.getLogger(BaseRepositoryImpl.class.getName());
    
    protected final SessionFactory sessionFactory;
    protected final Class<T> entityClass;
    protected final Class<ID> idClass;
    protected final String entityName;
    protected final String idFieldName;

    /**
     * Creates a new BaseRepositoryImpl with the given SessionFactory and entity types.
     * 
     * @param sessionFactory the Hibernate SessionFactory
     * @param entityClass the entity class
     * @param idClass the ID class
     */
    public BaseRepositoryImpl(SessionFactory sessionFactory, Class<T> entityClass, Class<ID> idClass) {
        this.sessionFactory = sessionFactory;
        this.entityClass = entityClass;
        this.idClass = idClass;
        this.entityName = entityClass.getSimpleName();
        this.idFieldName = findIdFieldName();
    }

    /**
     * Creates a new BaseRepositoryImpl with automatic type resolution.
     * This constructor is used when the repository is created through reflection.
     * 
     * @param sessionFactory the Hibernate SessionFactory
     */
    @SuppressWarnings("unchecked")
    public BaseRepositoryImpl(SessionFactory sessionFactory) {
        this.sessionFactory = sessionFactory;
        
        // Resolve generic types from the class hierarchy
        Type[] actualTypeArguments = getActualTypeArguments();
        this.entityClass = (Class<T>) actualTypeArguments[0];
        this.idClass = (Class<ID>) actualTypeArguments[1];
        this.entityName = entityClass.getSimpleName();
        this.idFieldName = findIdFieldName();
    }

    /**
     * Gets the actual type arguments for the generic types.
     */
    private Type[] getActualTypeArguments() {
        Type genericSuperclass = getClass().getGenericSuperclass();
        if (genericSuperclass instanceof ParameterizedType) {
            ParameterizedType parameterizedType = (ParameterizedType) genericSuperclass;
            return parameterizedType.getActualTypeArguments();
        }
        throw new IllegalStateException("Cannot resolve generic types for " + getClass());
    }

    /**
     * Finds the ID field name using @Id annotation.
     */
    private String findIdFieldName() {
        Field[] fields = entityClass.getDeclaredFields();
        for (Field field : fields) {
            if (field.isAnnotationPresent(Id.class)) {
                return field.getName();
            }
        }
        return "id"; // fallback to default
    }

    @Override
    public T save(T entity) {
        if (entity == null) {
            throw new IllegalArgumentException("Entity must not be null");
        }

        try (Session session = sessionFactory.openSession()) {
            Transaction transaction = session.beginTransaction();
            T savedEntity = session.merge(entity);
            transaction.commit();
            return savedEntity;
        } catch (Exception e) {
            logger.severe("Error saving entity: " + e.getMessage());
            throw new RuntimeException("Failed to save entity", e);
        }
    }

    @Override
    public List<T> saveAll(Iterable<T> entities) {
        if (entities == null) {
            throw new IllegalArgumentException("Entities must not be null");
        }

        List<T> savedEntities = new ArrayList<>();
        
        try (Session session = sessionFactory.openSession()) {
            Transaction transaction = session.beginTransaction();
            
            for (T entity : entities) {
                if (entity == null) {
                    throw new IllegalArgumentException("Entity must not be null");
                }
                T savedEntity = session.merge(entity);
                savedEntities.add(savedEntity);
            }
            
            transaction.commit();
            return savedEntities;
        } catch (Exception e) {
            logger.severe("Error saving entities: " + e.getMessage());
            throw new RuntimeException("Failed to save entities", e);
        }
    }

    @Override
    public Optional<T> findById(ID id) {
        if (id == null) {
            throw new IllegalArgumentException("ID must not be null");
        }

        try (Session session = sessionFactory.openSession()) {
            Transaction transaction = session.beginTransaction();
            T entity = session.get(entityClass, id);
            transaction.commit();
            return Optional.ofNullable(entity);
        } catch (Exception e) {
            logger.severe("Error finding entity by ID: " + e.getMessage());
            throw new RuntimeException("Failed to find entity", e);
        }
    }

    @Override
    public boolean existsById(ID id) {
        if (id == null) {
            throw new IllegalArgumentException("ID must not be null");
        }

        try (Session session = sessionFactory.openSession()) {
            Transaction transaction = session.beginTransaction();
            Query<Long> query = session.createQuery(
                "SELECT COUNT(e) FROM " + entityName + " e WHERE e." + idFieldName + " = :id", Long.class);
            query.setParameter("id", id);
            Long count = query.uniqueResult();
            transaction.commit();
            return count != null && count > 0;
        } catch (Exception e) {
            logger.severe("Error checking entity existence: " + e.getMessage());
            throw new RuntimeException("Failed to check entity existence", e);
        }
    }

    @Override
    public List<T> findAll() {
        try (Session session = sessionFactory.openSession()) {
            Transaction transaction = session.beginTransaction();
            Query<T> query = session.createQuery("FROM " + entityName, entityClass);
            List<T> entities = query.list();
            transaction.commit();
            return entities;
        } catch (Exception e) {
            logger.severe("Error finding all entities: " + e.getMessage());
            throw new RuntimeException("Failed to find entities", e);
        }
    }

    @Override
    public List<T> findAllById(Iterable<ID> ids) {
        if (ids == null) {
            throw new IllegalArgumentException("IDs must not be null");
        }

        List<ID> idList = new ArrayList<>();
        ids.forEach(idList::add);
        
        if (idList.isEmpty()) {
            return new ArrayList<>();
        }

        try (Session session = sessionFactory.openSession()) {
            Transaction transaction = session.beginTransaction();
            Query<T> query = session.createQuery(
                "FROM " + entityName + " e WHERE e." + idFieldName + " IN (:ids)", entityClass);
            query.setParameterList("ids", idList);
            List<T> entities = query.list();
            transaction.commit();
            return entities;
        } catch (Exception e) {
            logger.severe("Error finding entities by IDs: " + e.getMessage());
            throw new RuntimeException("Failed to find entities", e);
        }
    }

    @Override
    public long count() {
        try (Session session = sessionFactory.openSession()) {
            Transaction transaction = session.beginTransaction();
            Query<Long> query = session.createQuery("SELECT COUNT(e) FROM " + entityName + " e", Long.class);
            Long count = query.uniqueResult();
            transaction.commit();
            return count != null ? count : 0L;
        } catch (Exception e) {
            logger.severe("Error counting entities: " + e.getMessage());
            throw new RuntimeException("Failed to count entities", e);
        }
    }

    @Override
    public void deleteById(ID id) {
        if (id == null) {
            throw new IllegalArgumentException("ID must not be null");
        }

        try (Session session = sessionFactory.openSession()) {
            Transaction transaction = session.beginTransaction();
            T entity = session.get(entityClass, id);
            if (entity != null) {
                session.remove(entity);
            }
            transaction.commit();
            logger.fine("Deleted entity with ID: " + id);
        } catch (Exception e) {
            logger.severe("Error deleting entity by ID: " + e.getMessage());
            throw new RuntimeException("Failed to delete entity", e);
        }
    }

    @Override
    public void delete(T entity) {
        if (entity == null) {
            throw new IllegalArgumentException("Entity must not be null");
        }

        try (Session session = sessionFactory.openSession()) {
            Transaction transaction = session.beginTransaction();
            session.remove(entity);
            transaction.commit();
            logger.fine("Deleted entity: " + entityName);
        } catch (Exception e) {
            logger.severe("Error deleting entity: " + e.getMessage());
            throw new RuntimeException("Failed to delete entity", e);
        }
    }

    @Override
    public void deleteAllById(Iterable<ID> ids) {
        if (ids == null) {
            throw new IllegalArgumentException("IDs must not be null");
        }

        List<ID> idList = new ArrayList<>();
        ids.forEach(idList::add);
        
        if (idList.isEmpty()) {
            return;
        }

        try (Session session = sessionFactory.openSession()) {
            Transaction transaction = session.beginTransaction();
            Query<?> query = session.createQuery( // FIXME: deprecated method
                "DELETE FROM " + entityName + " e WHERE e." + idFieldName + " IN (:ids)");
            query.setParameterList("ids", idList);
            int deletedCount = query.executeUpdate();
            transaction.commit();
            logger.fine("Deleted " + deletedCount + " entities by IDs");
        } catch (Exception e) {
            logger.severe("Error deleting entities by IDs: " + e.getMessage());
            throw new RuntimeException("Failed to delete entities", e);
        }
    }

    @Override
    public void deleteAll(Iterable<T> entities) {
        if (entities == null) {
            throw new IllegalArgumentException("Entities must not be null");
        }

        try (Session session = sessionFactory.openSession()) {
            Transaction transaction = session.beginTransaction();
            
            for (T entity : entities) {
                if (entity != null) {
                    session.remove(entity);
                }
            }
            
            transaction.commit();
            logger.fine("Deleted entities of type: " + entityName);
        } catch (Exception e) {
            logger.severe("Error deleting entities: " + e.getMessage());
            throw new RuntimeException("Failed to delete entities", e);
        }
    }

    @Override
    public void deleteAll() {
        try (Session session = sessionFactory.openSession()) {
            Transaction transaction = session.beginTransaction();
            Query<?> query = session.createQuery("DELETE FROM " + entityName); // FIXME: deprecated method
            int deletedCount = query.executeUpdate();
            transaction.commit();
            logger.fine("Deleted all " + deletedCount + " entities of type: " + entityName);
        } catch (Exception e) {
            logger.severe("Error deleting all entities: " + e.getMessage());
            throw new RuntimeException("Failed to delete all entities", e);
        }
    }

    @Override
    public void flush() {
        try (Session session = sessionFactory.openSession()) {
            session.flush();
        } catch (Exception e) {
            logger.severe("Error flushing session: " + e.getMessage());
            throw new RuntimeException("Failed to flush session", e);
        }
    }

    @Override
    public T saveAndFlush(T entity) {
        T savedEntity = save(entity);
        flush();
        return savedEntity;
    }

    @Override
    public void deleteInBatch(Iterable<T> entities) {
        if (entities == null) {
            throw new IllegalArgumentException("Entities must not be null");
        }

        List<ID> ids = new ArrayList<>();
        for (T entity : entities) {
            if (entity != null) {
                try {
                    Field idField = entityClass.getDeclaredField(idFieldName);
                    idField.setAccessible(true);
                    @SuppressWarnings("unchecked")
                    ID id = (ID) idField.get(entity);
                    if (id != null) {
                        ids.add(id);
                    }
                } catch (Exception e) {
                    logger.warning("Could not extract ID from entity: " + e.getMessage());
                }
            }
        }
        
        deleteAllById(ids);
    }

    @Override
    public void deleteAllInBatch() {
        deleteAll();
    }
} 