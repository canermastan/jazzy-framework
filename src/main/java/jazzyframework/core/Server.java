package jazzyframework.core;

import java.io.IOException;
import java.net.ServerSocket;
import java.net.Socket;
import java.util.logging.Logger;

import jazzyframework.controllers.MetricsController;
import jazzyframework.data.CrudProcessor;
import jazzyframework.di.DIContainer;
import jazzyframework.routing.Router;
import jazzyframework.security.AuthProcessor;

/**
 * The main server class of the Jazzy Framework.
 * 
 * <p>This class is responsible for:
 * <ul>
 *   <li>Starting a HTTP server on a specified port</li>
 *   <li>Accepting client connections and delegating requests to appropriate handlers</li>
 *   <li>Automatically initializing dependency injection with component discovery</li>
 *   <li>Registering the metrics endpoint if enabled</li>
 *   <li>Processing @Crud annotations and auto-generating CRUD endpoints</li>
 *   <li>Managing server lifecycle and cleanup</li>
 * </ul>
 * 
 * <p>The server automatically enables dependency injection and discovers all components
 * in the application package without requiring any configuration.
 * 
 * @since 0.1
 * @author Caner Mastan
 */
public class Server {
    private final Router router;
    private final Config config;
    private DIContainer diContainer;
    private static final Logger logger = Logger.getLogger(Server.class.getName());

    /**
     * Creates a new Server instance with the specified router and config.
     * Automatically registers the metrics endpoint and initializes dependency injection.
     * 
     * @param router The router to use for handling HTTP requests
     * @param config The configuration object
     */
    public Server(Router router, Config config) {
        this.router = router;
        this.config = config;

        initializeDependencyInjection();
        
        // Process @Crud annotations after DI initialization
        processCrudAnnotations();
        
        // Process @EnableJazzyAuth annotations after DI initialization
        processAuthAnnotations();

        if (config.isEnableMetrics()) {
            router.addRoute("GET", "/metrics", "getMetrics", MetricsController.class);
            logger.info("Metrics route added");
        }
    }

    /**
     * Initializes the dependency injection container.
     * Automatically discovers and registers all components.
     */
    private void initializeDependencyInjection() {
        this.diContainer = new DIContainer();
        this.router.setDIContainer(diContainer);
        
        diContainer.initialize();
        logger.info("Dependency injection enabled with automatic component discovery");
    }
    
    /**
     * Processes @Crud annotations and automatically generates CRUD endpoints.
     */
    private void processCrudAnnotations() {
        try {
            CrudProcessor crudProcessor = new CrudProcessor(router, diContainer);
            crudProcessor.processAllCrudControllers();
            logger.info("@Crud annotations processed and CRUD endpoints generated");
        } catch (Exception e) {
            logger.warning("Failed to process @Crud annotations: " + e.getMessage());
            e.printStackTrace();
            // Don't fail startup if CRUD processing fails
        }
    }

    /**
     * Processes @EnableJazzyAuth annotations and automatically configures authentication.
     */
    private void processAuthAnnotations() {
        try {
            AuthProcessor authProcessor = new AuthProcessor(router, diContainer);
            authProcessor.processAuthAnnotations();
            logger.info("@EnableJazzyAuth annotations processed and authentication configured");
        } catch (Exception e) {
            logger.warning("Failed to process @EnableJazzyAuth annotations: " + e.getMessage());
            e.printStackTrace();
            // Don't fail startup if auth processing fails
        }
    }

    /**
     * Gets the DI container used by this server.
     * 
     * @return the DI container
     */
    public DIContainer getDIContainer() {
        return diContainer;
    }

    /**
     * Starts the server on the specified port.
     * Creates a new thread for each incoming connection.
     * 
     * @param port The port number to listen on
     */
    public void start(int port) {
        try (ServerSocket serverSocket = new ServerSocket(port)) {
            logger.info("Server started on port " + port + " with dependency injection and auto-CRUD");
            
            while (true) {
                Socket clientSocket = serverSocket.accept();
                new Thread(new RequestHandler(clientSocket, router)).start();
            }
        } catch (IOException e) {
            logger.severe("Error starting server: " + e.getMessage());
        } finally {
            if (diContainer != null) {
                diContainer.dispose();
            }
        }
    }
}
