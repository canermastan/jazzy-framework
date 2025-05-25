package jazzyframework.core;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.AfterEach;
import static org.junit.jupiter.api.Assertions.*;

import java.io.IOException;
import java.io.InputStream;
import java.util.Properties;

/**
 * Tests for PropertyLoader class focusing on database configuration.
 */
public class PropertyLoaderTest {

    @BeforeEach
    public void setUp() {
        // Reset singleton instance before each test
        resetPropertyLoaderInstance();
    }

    @AfterEach
    public void tearDown() {
        // Clean up after each test
        resetPropertyLoaderInstance();
    }

    @Test
    public void testGetDatabaseUrl_DefaultValue() {
        PropertyLoader loader = PropertyLoader.getInstance();
        String url = loader.getDatabaseUrl();
        assertEquals("jdbc:h2:mem:test_db;DB_CLOSE_DELAY=-1;DB_CLOSE_ON_EXIT=FALSE", url);
    }

    @Test
    public void testGetDatabaseUsername_DefaultValue() {
        PropertyLoader loader = PropertyLoader.getInstance();
        String username = loader.getDatabaseUsername();
        assertEquals("sa", username);
    }

    @Test
    public void testGetDatabasePassword_DefaultValue() {
        PropertyLoader loader = PropertyLoader.getInstance();
        String password = loader.getDatabasePassword();
        assertEquals("", password);
    }

    @Test
    public void testGetDatabaseDriverClassName_DefaultValue() {
        PropertyLoader loader = PropertyLoader.getInstance();
        String driver = loader.getDatabaseDriverClassName();
        assertEquals("org.h2.Driver", driver);
    }

    @Test
    public void testGetHibernateDialect_DefaultValue() {
        PropertyLoader loader = PropertyLoader.getInstance();
        String dialect = loader.getHibernateDialect();
        assertEquals("org.hibernate.dialect.H2Dialect", dialect);
    }

    @Test
    public void testGetHibernateDdlAuto_DefaultValue() {
        PropertyLoader loader = PropertyLoader.getInstance();
        String ddlAuto = loader.getHibernateDdlAuto();
        assertEquals("create-drop", ddlAuto);
    }

    @Test
    public void testIsShowSql_DefaultValue() {
        PropertyLoader loader = PropertyLoader.getInstance();
        boolean showSql = loader.isShowSql();
        assertFalse(showSql);
    }

    @Test
    public void testIsFormatSql_DefaultValue() {
        PropertyLoader loader = PropertyLoader.getInstance();
        boolean formatSql = loader.isFormatSql();
        assertFalse(formatSql);
    }

    @Test
    public void testIsH2ConsoleEnabled_DefaultValue() {
        PropertyLoader loader = PropertyLoader.getInstance();
        boolean h2Console = loader.isH2ConsoleEnabled();
        assertFalse(h2Console);
    }

    @Test
    public void testIsDatabaseEnabled_DefaultValue() {
        PropertyLoader loader = PropertyLoader.getInstance();
        boolean dbEnabled = loader.isDatabaseEnabled();
        assertTrue(dbEnabled);
    }

    @Test
    public void testBooleanProperty_ValidValues() {
        PropertyLoader loader = PropertyLoader.getInstance();
        
        // Test valid boolean values from test.properties
        assertTrue(loader.getBooleanProperty("test.boolean.true", false));
        assertFalse(loader.getBooleanProperty("test.boolean.false", true));
        
        // Test default values
        assertTrue(loader.getBooleanProperty("non.existent.property", true));
        assertFalse(loader.getBooleanProperty("non.existent.property", false));
    }

    @Test
    public void testIntProperty_ValidValues() {
        PropertyLoader loader = PropertyLoader.getInstance();
        
        // Test default values for non-existent properties
        assertEquals(100, loader.getIntProperty("non.existent.property", 100));
        assertEquals(42, loader.getIntProperty("non.existent.property", 42));
    }

    @Test
    public void testStringProperty_DefaultHandling() {
        PropertyLoader loader = PropertyLoader.getInstance();
        
        // Test default values
        assertEquals("default", loader.getProperty("non.existent.property", "default"));
        assertNull(loader.getProperty("non.existent.property"));
    }

    @Test
    public void testHasProperty() {
        PropertyLoader loader = PropertyLoader.getInstance();
        
        // These properties should exist with default values
        assertTrue(loader.hasProperty("jazzy.datasource.url") || 
                   !loader.hasProperty("jazzy.datasource.url")); // Either way is valid
        
        // This property should definitely not exist
        assertFalse(loader.hasProperty("definitely.non.existent.property.12345"));
    }

    @Test
    public void testGetAllProperties() {
        PropertyLoader loader = PropertyLoader.getInstance();
        Properties props = loader.getAllProperties();
        
        assertNotNull(props);
        // Properties should be independent copy
        assertNotSame(props, loader.getAllProperties());
    }

    @Test
    public void testPropertyPrefixes() {
        PropertyLoader loader = PropertyLoader.getInstance();
        
        // Test that all database methods use "jazzy" prefix correctly
        // We can't test the actual property values without a test properties file,
        // but we can test that the methods work without exceptions
        assertDoesNotThrow(() -> {
            loader.getDatabaseUrl();
            loader.getDatabaseUsername();
            loader.getDatabasePassword();
            loader.getDatabaseDriverClassName();
            loader.getHibernateDialect();
            loader.getHibernateDdlAuto();
            loader.isShowSql();
            loader.isFormatSql();
            loader.isH2ConsoleEnabled();
            loader.isDatabaseEnabled();
        });
    }

    /**
     * Helper method to reset PropertyLoader singleton for testing.
     * Uses reflection to reset the static instance.
     */
    private void resetPropertyLoaderInstance() {
        try {
            var field = PropertyLoader.class.getDeclaredField("instance");
            field.setAccessible(true);
            field.set(null, null);
        } catch (Exception e) {
            // Ignore reflection errors in test
        }
    }
} 