package jazzyframework.data.annotations;

import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;

/**
 * Query hint annotation for providing hints to the query execution engine.
 * 
 * @since 0.3.0
 * @author Caner Mastan
 */
@Retention(RetentionPolicy.RUNTIME)
public @interface QueryHint {
    
    /**
     * The name of the hint.
     * 
     * @return the hint name
     */
    String name();
    
    /**
     * The value of the hint.
     * 
     * @return the hint value
     */
    String value();
} 