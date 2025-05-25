package examples.database.entity;

import jakarta.persistence.*;
import java.time.LocalDateTime;

/**
 * User entity demonstrating JPA annotations and database integration.
 * 
 * <p>This entity showcases:
 * <ul>
 *   <li>Basic JPA annotations (@Entity, @Id, @GeneratedValue)</li>
 *   <li>Column constraints and specifications</li>
 *   <li>Timestamp fields with automatic management</li>
 *   <li>Validation constraints</li>
 * </ul>
 * 
 * @since 0.3.0
 * @author Caner Mastan
 */
@Entity
@Table(name = "users")
public class User {
    
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    
    @Column(name = "name", nullable = false, length = 100)
    private String name;
    
    @Column(name = "email", nullable = false, unique = true, length = 255)
    private String email;
    
    @Column(name = "password", nullable = false)
    private String password;
    
    @Column(name = "active", nullable = false)
    private Boolean active = true;
    
    @Column(name = "age")
    private Integer age;
    
    @Column(name = "created_at", nullable = false)
    private LocalDateTime createdAt;
    
    @Column(name = "updated_at")
    private LocalDateTime updatedAt;

    /**
     * Default constructor required by JPA.
     */
    public User() {
        this.createdAt = LocalDateTime.now();
    }

    /**
     * Constructor with required fields.
     * 
     * @param name the user's name
     * @param email the user's email
     * @param password the user's password
     */
    public User(String name, String email, String password) {
        this();
        this.name = name;
        this.email = email;
        this.password = password;
    }

    /**
     * Constructor with all fields.
     * 
     * @param name the user's name
     * @param email the user's email
     * @param password the user's password
     * @param age the user's age
     */
    public User(String name, String email, String password, Integer age) {
        this(name, email, password);
        this.age = age;
    }

    /**
     * Called before entity update.
     */
    @PreUpdate
    public void preUpdate() {
        this.updatedAt = LocalDateTime.now();
    }

    /**
     * Called before entity persistence.
     */
    @PrePersist
    public void prePersist() {
        if (this.createdAt == null) {
            this.createdAt = LocalDateTime.now();
        }
        if (this.active == null) {
            this.active = true;
        }
    }

    // Getters and Setters

    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public String getName() {
        return name;
    }

    public void setName(String name) {
        this.name = name;
    }

    public String getEmail() {
        return email;
    }

    public void setEmail(String email) {
        this.email = email;
    }

    public String getPassword() {
        return password;
    }

    public void setPassword(String password) {
        this.password = password;
    }

    public Boolean getActive() {
        return active;
    }

    public void setActive(Boolean active) {
        this.active = active;
    }

    public Integer getAge() {
        return age;
    }

    public void setAge(Integer age) {
        this.age = age;
    }

    public LocalDateTime getCreatedAt() {
        return createdAt;
    }

    public void setCreatedAt(LocalDateTime createdAt) {
        this.createdAt = createdAt;
    }

    public LocalDateTime getUpdatedAt() {
        return updatedAt;
    }

    public void setUpdatedAt(LocalDateTime updatedAt) {
        this.updatedAt = updatedAt;
    }

    @Override
    public String toString() {
        return "User{" +
                "id=" + id +
                ", name='" + name + '\'' +
                ", email='" + email + '\'' +
                ", active=" + active +
                ", age=" + age +
                ", createdAt=" + createdAt +
                ", updatedAt=" + updatedAt +
                '}';
    }

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (o == null || getClass() != o.getClass()) return false;

        User user = (User) o;

        return id != null ? id.equals(user.id) : user.id == null;
    }

    @Override
    public int hashCode() {
        return id != null ? id.hashCode() : 0;
    }
} 