package jazzyframework.core;

import java.io.IOException;
import java.io.InputStream;
import java.util.Properties;
import java.util.logging.Logger;

/**
 * Loads configuration properties from application.properties file.
 * Provides JazzyFramework's own property management with default values and type conversion.
 * 
 * <p>This class automatically loads properties from:
 * <ul>
 *   <li>application.properties in classpath root</li>
 *   <li>application.properties in resources folder</li>
 *   <li>application.properties in config folder</li>
 * </ul>
 * 
 * <p>Supports JazzyFramework property patterns:
 * <ul>
 *   <li>Database configuration (jazzy.datasource.*)</li>
 *   <li>JPA/Hibernate configuration (jazzy.jpa.*)</li>
 *   <li>H2 Console configuration (jazzy.h2.*)</li>
 *   <li>Framework configuration (jazzy.database.*)</li>
 * </ul>
 * 
 * <p>Example usage:
 * <pre>
 * PropertyLoader loader = PropertyLoader.getInstance();
 * String dbUrl = loader.getDatabaseUrl();
 * boolean showSql = loader.isShowSql();
 * </pre>
 * 
 * @since 0.3.0
 * @author Caner Mastan
 */
public class PropertyLoader {
    private static final Logger logger = Logger.getLogger(PropertyLoader.class.getName());
    private static PropertyLoader instance;
    private final Properties properties;

    /**
     * Private constructor for singleton pattern.
     */
    private PropertyLoader() {
        this.properties = new Properties();
        loadProperties();
    }

    /**
     * Gets the singleton instance of PropertyLoader.
     * 
     * @return the PropertyLoader instance
     */
    public static PropertyLoader getInstance() {
        if (instance == null) {
            synchronized (PropertyLoader.class) {
                if (instance == null) {
                    instance = new PropertyLoader();
                }
            }
        }
        return instance;
    }

    /**
     * Loads properties from application.properties file.
     */
    private void loadProperties() {
        String[] possibleLocations = {
            "/application.properties",
            "application.properties",
            "/config/application.properties"
        };

        boolean loaded = false;
        for (String location : possibleLocations) {
            try (InputStream inputStream = getClass().getResourceAsStream(location)) {
                if (inputStream != null) {
                    properties.load(inputStream);
                    logger.info("Loaded properties from: " + location);
                    loaded = true;
                    break;
                }
            } catch (IOException e) {
                logger.fine("Could not load properties from: " + location);
            }
        }

        if (!loaded) {
            logger.info("No application.properties found, using default configuration");
        }

        logLoadedProperties();
    }

    /**
     * Logs loaded properties (excluding sensitive data).
     */
    private void logLoadedProperties() {
        logger.info("Loaded " + properties.size() + " properties");
        properties.stringPropertyNames().stream()
            .filter(key -> !key.toLowerCase().contains("password"))
            .forEach(key -> logger.fine("Property: " + key + " = " + properties.getProperty(key)));
    }

    /**
     * Gets a string property with optional default value.
     * 
     * @param key the property key
     * @param defaultValue the default value if property is not found
     * @return the property value or default value
     */
    public String getProperty(String key, String defaultValue) {
        return properties.getProperty(key, defaultValue);
    }

    /**
     * Gets a string property.
     * 
     * @param key the property key
     * @return the property value or null if not found
     */
    public String getProperty(String key) {
        return properties.getProperty(key);
    }

    /**
     * Gets a boolean property with default value.
     * 
     * @param key the property key
     * @param defaultValue the default value
     * @return the boolean value
     */
    public boolean getBooleanProperty(String key, boolean defaultValue) {
        String value = properties.getProperty(key);
        if (value == null) {
            return defaultValue;
        }
        return Boolean.parseBoolean(value.trim());
    }

    /**
     * Gets an integer property with default value.
     * 
     * @param key the property key
     * @param defaultValue the default value
     * @return the integer value
     */
    public int getIntProperty(String key, int defaultValue) {
        String value = properties.getProperty(key);
        if (value == null) {
            return defaultValue;
        }
        try {
            return Integer.parseInt(value.trim());
        } catch (NumberFormatException e) {
            logger.warning("Invalid integer value for property " + key + ": " + value + ", using default: " + defaultValue);
            return defaultValue;
        }
    }

    /**
     * Checks if a property exists.
     * 
     * @param key the property key
     * @return true if the property exists
     */
    public boolean hasProperty(String key) {
        return properties.containsKey(key);
    }

    /**
     * Gets all properties.
     * 
     * @return the Properties object
     */
    public Properties getAllProperties() {
        return new Properties(properties);
    }

    // Database-specific convenience methods

    /**
     * Gets the database URL.
     * 
     * @return the database URL or H2 default if not specified
     */
    public String getDatabaseUrl() {
        return getProperty("jazzy.datasource.url", "jdbc:h2:mem:testdb;DB_CLOSE_DELAY=-1;DB_CLOSE_ON_EXIT=FALSE");
    }

    /**
     * Gets the database username.
     * 
     * @return the database username or "sa" if not specified
     */
    public String getDatabaseUsername() {
        return getProperty("jazzy.datasource.username", "sa");
    }

    /**
     * Gets the database password.
     * 
     * @return the database password or empty string if not specified
     */
    public String getDatabasePassword() {
        return getProperty("jazzy.datasource.password", "");
    }

    /**
     * Gets the database driver class name.
     * 
     * @return the driver class name or H2 driver if not specified
     */
    public String getDatabaseDriverClassName() {
        return getProperty("jazzy.datasource.driver-class-name", "org.h2.Driver");
    }

    /**
     * Gets the Hibernate dialect.
     * 
     * @return the Hibernate dialect or H2 dialect if not specified
     */
    public String getHibernateDialect() {
        return getProperty("jazzy.jpa.database-platform", "org.hibernate.dialect.H2Dialect");
    }

    /**
     * Gets the Hibernate DDL auto mode.
     * 
     * @return the DDL auto mode or "update" if not specified
     */
    public String getHibernateDdlAuto() {
        return getProperty("jazzy.jpa.hibernate.ddl-auto", "update");
    }

    /**
     * Checks if SQL logging is enabled.
     * 
     * @return true if SQL logging is enabled
     */
    public boolean isShowSql() {
        return getBooleanProperty("jazzy.jpa.show-sql", false);
    }

    /**
     * Checks if SQL formatting is enabled.
     * 
     * @return true if SQL formatting is enabled
     */
    public boolean isFormatSql() {
        return getBooleanProperty("jazzy.jpa.properties.hibernate.format_sql", false);
    }

    /**
     * Checks if H2 console is enabled.
     * 
     * @return true if H2 console is enabled
     */
    public boolean isH2ConsoleEnabled() {
        return getBooleanProperty("jazzy.h2.console.enabled", true);
    }

    /**
     * Checks if database is enabled.
     * 
     * @return true if database is enabled
     */
    public boolean isDatabaseEnabled() {
        return getBooleanProperty("jazzy.database.enabled", true);
    }
} 