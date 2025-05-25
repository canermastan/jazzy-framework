package jazzyframework.data;

import jazzyframework.core.PropertyLoader;
import jazzyframework.di.annotations.Component;
import jazzyframework.di.annotations.PostConstruct;
import jazzyframework.di.annotations.PreDestroy;

import org.hibernate.SessionFactory;
import org.hibernate.boot.registry.StandardServiceRegistry;
import org.hibernate.boot.registry.StandardServiceRegistryBuilder;
import org.hibernate.cfg.Configuration;

import com.zaxxer.hikari.HikariConfig;
import com.zaxxer.hikari.HikariDataSource;

import javax.sql.DataSource;
import java.util.List;
import java.util.logging.Logger;

/**
 * Hibernate configuration and SessionFactory management.
 * 
 * <p>This class provides zero-configuration Hibernate setup by:
 * <ul>
 *   <li>Reading configuration from application.properties</li>
 *   <li>Automatically discovering @Entity classes</li>
 *   <li>Setting up HikariCP connection pool</li>
 *   <li>Creating and managing SessionFactory</li>
 *   <li>Providing proper cleanup on shutdown</li>
 * </ul>
 * 
 * <p>Supports multiple databases out of the box:
 * <ul>
 *   <li>H2 (embedded, default for development)</li>
 *   <li>MySQL (production ready)</li>
 *   <li>PostgreSQL (production ready)</li>
 * </ul>
 * 
 * <p>Configuration properties (all prefixed with "jazzy"):
 * <ul>
 *   <li>jazzy.datasource.* - Database connection settings</li>
 *   <li>jazzy.jpa.* - JPA/Hibernate settings</li>
 *   <li>jazzy.h2.console.enabled - H2 console enablement</li>
 * </ul>
 * 
 * @since 0.3.0
 * @author Caner Mastan
 */
@Component
public class HibernateConfig {
    private static final Logger logger = Logger.getLogger(HibernateConfig.class.getName());
    
    private SessionFactory sessionFactory;
    private HikariDataSource dataSource;
    private final PropertyLoader propertyLoader;
    private final EntityScanner entityScanner;

    /**
     * Creates a new HibernateConfig instance.
     * Dependencies will be injected by the DI container.
     */
    public HibernateConfig() {
        this.propertyLoader = PropertyLoader.getInstance();
        this.entityScanner = new EntityScanner();
    }

    /**
     * Initializes Hibernate configuration after bean creation.
     * This method is called automatically by the DI container.
     */
    @PostConstruct
    public void initialize() {
        if (!propertyLoader.isDatabaseEnabled()) {
            logger.info("Database is disabled via configuration");
            return;
        }

        logger.info("Initializing Hibernate configuration...");
        
        try {
            createDataSource();
            createSessionFactory();
            startH2ConsoleIfEnabled();
            
            logger.info("Hibernate initialized successfully");
        } catch (Exception e) {
            logger.severe("Failed to initialize Hibernate: " + e.getMessage());
            throw new RuntimeException("Hibernate initialization failed", e);
        }
    }

    /**
     * Creates HikariCP data source based on properties.
     */
    private void createDataSource() {
        HikariConfig config = new HikariConfig();
        
        config.setJdbcUrl(propertyLoader.getDatabaseUrl());
        config.setUsername(propertyLoader.getDatabaseUsername());
        config.setPassword(propertyLoader.getDatabasePassword());
        config.setDriverClassName(propertyLoader.getDatabaseDriverClassName());

        config.setMaximumPoolSize(propertyLoader.getIntProperty("jazzy.datasource.hikari.maximum-pool-size", 10));
        config.setMinimumIdle(propertyLoader.getIntProperty("jazzy.datasource.hikari.minimum-idle", 2));
        config.setConnectionTimeout(propertyLoader.getIntProperty("jazzy.datasource.hikari.connection-timeout", 30000));
        config.setIdleTimeout(propertyLoader.getIntProperty("jazzy.datasource.hikari.idle-timeout", 600000));
        config.setMaxLifetime(propertyLoader.getIntProperty("jazzy.datasource.hikari.max-lifetime", 1800000));

        config.setConnectionTestQuery("SELECT 1");
        config.setValidationTimeout(5000);

        this.dataSource = new HikariDataSource(config);
        
        logger.info("DataSource created: " + config.getJdbcUrl());
    }

    /**
     * Creates Hibernate SessionFactory with automatic entity discovery.
     */
    private void createSessionFactory() {
        Configuration configuration = new Configuration();

        configuration.setProperty("hibernate.dialect", propertyLoader.getHibernateDialect());
        configuration.setProperty("hibernate.hbm2ddl.auto", propertyLoader.getHibernateDdlAuto());
        configuration.setProperty("hibernate.show_sql", String.valueOf(propertyLoader.isShowSql()));
        configuration.setProperty("hibernate.format_sql", String.valueOf(propertyLoader.isFormatSql()));

        configuration.setProperty("hibernate.use_sql_comments", "true");
        configuration.setProperty("hibernate.jdbc.batch_size", "20");
        configuration.setProperty("hibernate.order_inserts", "true");
        configuration.setProperty("hibernate.order_updates", "true");
        configuration.setProperty("hibernate.jdbc.batch_versioned_data", "true");

        addCustomHibernateProperties(configuration);

        List<Class<?>> entityClasses = entityScanner.scanForEntities();
        if (!entityClasses.isEmpty()) {
            logger.info("Found " + entityClasses.size() + " entity classes");
        } else {
            logger.warning("No entity classes found");
        }
        
        for (Class<?> entityClass : entityClasses) {
            configuration.addAnnotatedClass(entityClass);
            logger.fine("Registered entity: " + entityClass.getName());
        }

        StandardServiceRegistry serviceRegistry = new StandardServiceRegistryBuilder()
            .applySettings(configuration.getProperties())
            .applySetting("hibernate.connection.datasource", dataSource)
            .build();

        this.sessionFactory = configuration.buildSessionFactory(serviceRegistry);
        
        logger.info("SessionFactory created successfully");
    }

    /**
     * Adds custom Hibernate properties from application.properties.
     */
    private void addCustomHibernateProperties(Configuration configuration) {
        propertyLoader.getAllProperties().stringPropertyNames().stream()
            .filter(key -> key.startsWith("jazzy.jpa.properties.hibernate."))
            .forEach(key -> {
                String hibernateKey = key.substring("jazzy.jpa.properties.".length());
                String value = propertyLoader.getProperty(key);
                configuration.setProperty(hibernateKey, value);
                logger.fine("Added custom Hibernate property: " + hibernateKey + " = " + value);
            });
    }

    /**
     * Starts H2 console if enabled and using H2 database.
     */
    private void startH2ConsoleIfEnabled() {
        if (propertyLoader.isH2ConsoleEnabled() && 
            propertyLoader.getDatabaseUrl().contains("h2")) {
            
            try {
                org.h2.tools.Server.createTcpServer("-tcpAllowOthers").start();
                org.h2.tools.Server.createWebServer("-webAllowOthers", "-webPort", "8082").start();
                
                logger.info("H2 Console started at: http://localhost:8082");
                logger.info("H2 Console URL: " + propertyLoader.getDatabaseUrl());
            } catch (Exception e) {
                logger.warning("Could not start H2 console: " + e.getMessage());
            }
        }
    }

    /**
     * Cleanup resources when the application shuts down.
     */
    @PreDestroy
    public void destroy() {
        logger.info("Shutting down Hibernate...");
        
        if (sessionFactory != null && !sessionFactory.isClosed()) {
            sessionFactory.close();
            logger.info("SessionFactory closed");
        }
        
        if (dataSource != null && !dataSource.isClosed()) {
            dataSource.close();
            logger.info("DataSource closed");
        }
    }

    /**
     * Gets the Hibernate SessionFactory.
     * 
     * @return the SessionFactory instance
     */
    public SessionFactory getSessionFactory() {
        if (sessionFactory == null) {
            throw new IllegalStateException("SessionFactory is not initialized. Ensure database is enabled.");
        }
        return sessionFactory;
    }

    /**
     * Gets the HikariCP DataSource.
     * 
     * @return the DataSource instance
     */
    public DataSource getDataSource() {
        if (dataSource == null) {
            throw new IllegalStateException("DataSource is not initialized. Ensure database is enabled.");
        }
        return dataSource;
    }

    /**
     * Checks if Hibernate is properly initialized.
     * 
     * @return true if SessionFactory is available
     */
    public boolean isInitialized() {
        return sessionFactory != null && !sessionFactory.isClosed();
    }
} 