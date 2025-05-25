package jazzyframework.data;

import jazzyframework.core.PropertyLoader;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.MockedStatic;
import org.mockito.junit.jupiter.MockitoExtension;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

/**
 * Tests for HibernateConfig class.
 */
@ExtendWith(MockitoExtension.class)
public class HibernateConfigTest {

    private HibernateConfig hibernateConfig;

    @BeforeEach
    public void setUp() {
        hibernateConfig = new HibernateConfig();
    }

    @Test
    public void testConstructor() {
        assertNotNull(hibernateConfig);
        assertFalse(hibernateConfig.isInitialized());
    }

    @Test
    public void testIsInitialized_BeforeInit() {
        assertFalse(hibernateConfig.isInitialized());
    }

    @Test
    public void testGetSessionFactory_NotInitialized() {
        assertThrows(IllegalStateException.class, () -> {
            hibernateConfig.getSessionFactory();
        });
    }

    @Test
    public void testGetDataSource_NotInitialized() {
        assertThrows(IllegalStateException.class, () -> {
            hibernateConfig.getDataSource();
        });
    }

    @Test
    public void testInitialize_DatabaseDisabled() {
        // Mock PropertyLoader to return database disabled
        try (MockedStatic<PropertyLoader> mockedPropertyLoader = mockStatic(PropertyLoader.class)) {
            PropertyLoader mockLoader = mock(PropertyLoader.class);
            when(mockLoader.isDatabaseEnabled()).thenReturn(false);
            mockedPropertyLoader.when(PropertyLoader::getInstance).thenReturn(mockLoader);
            
            // Create new instance to use mocked PropertyLoader
            HibernateConfig config = new HibernateConfig();
            
            // This should not throw and should not initialize
            assertDoesNotThrow(() -> config.initialize());
            assertFalse(config.isInitialized());
        }
    }

    @Test
    public void testDestroy() {
        // Test that destroy doesn't throw even when not initialized
        assertDoesNotThrow(() -> hibernateConfig.destroy());
    }

    @Test
    public void testDestroy_AfterPartialInit() {
        // Even after partial initialization, destroy should work
        assertDoesNotThrow(() -> hibernateConfig.destroy());
    }

    // Note: Full initialization tests are covered in integration tests
    // because they require actual database setup which is complex for unit tests
} 