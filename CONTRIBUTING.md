# Contributing to Jazzy Framework

Thank you for your interest in contributing to Jazzy Framework! 🎉

## Ways to Contribute

There are many ways you can contribute to Jazzy Framework:

- 🐛 **Report bugs** using our bug report template
- 💡 **Suggest features** using our feature request template  
- 📝 **Improve documentation** - fix typos, add examples, clarify explanations
- 🧪 **Write tests** - help us reach 100% test coverage
- 🔧 **Fix bugs** - tackle issues labeled with `good first issue`
- ⭐ **Add new features** - implement requested features
- 📚 **Create examples** - build sample applications showcasing framework features

## Getting Started

### 1. Fork and Clone
```bash
git clone https://github.com/YOUR_USERNAME/jazzy-framework.git
cd jazzy-framework
```

### 2. Build the Project
```bash
# Install dependencies and run tests
mvn clean install

# Run tests only
mvn test

# Run example application
mvn exec:java -Dexec.mainClass="examples.basic.App"
```

### 3. Make Your Changes

#### For Bug Fixes:
1. Create a branch: `git checkout -b fix/issue-123-description`
2. Write tests that reproduce the bug
3. Fix the bug
4. Ensure all tests pass
5. Update documentation if needed

#### For New Features:
1. Create a branch: `git checkout -b feature/feature-name`
2. Write tests for the new feature
3. Implement the feature
4. Add documentation and examples
5. Ensure all tests pass

#### For Documentation:
1. Create a branch: `git checkout -b docs/description`
2. Update relevant `.md` files or javadocs
3. Test documentation builds (if applicable)

### 4. Commit Guidelines

We follow [Conventional Commits](https://www.conventionalcommits.org/):

```bash
# Examples:
git commit -m "feat: add middleware support to router"
git commit -m "fix: resolve null pointer in DI container"
git commit -m "docs: add examples for @Named annotation"
git commit -m "test: add integration tests for validation"
git commit -m "chore: update dependencies"
```

**Types:**
- `feat:` - New features
- `fix:` - Bug fixes
- `docs:` - Documentation changes
- `test:` - Adding/updating tests
- `chore:` - Maintenance tasks
- `refactor:` - Code refactoring
- `perf:` - Performance improvements

### 5. Pull Request Process

1. **Update your branch** with latest main:
   ```bash
   git checkout main
   git pull origin main
   git checkout your-branch
   git rebase main
   ```

2. **Run the full test suite**:
   ```bash
   mvn clean test
   ```

3. **Create Pull Request** with:
   - Clear title describing the change
   - Detailed description of what was changed and why
   - Link to related issues
   - Screenshots/examples if applicable

## Code Standards

### Java Code Style
- **Indentation**: 4 spaces (no tabs)
- **Line Length**: Maximum 120 characters
- **Naming**: 
  - Classes: `PascalCase`
  - Methods/Variables: `camelCase`
  - Constants: `UPPER_SNAKE_CASE`
- **Javadoc**: Required for all public methods and classes

### Testing
- **Test Coverage**: Aim for >90% coverage for new code
- **Test Naming**: Use descriptive names that explain what is being tested
- **Test Structure**: Follow Arrange-Act-Assert pattern

Example:
```java
@Test
public void shouldInjectDependencyWhenComponentHasConstructorParameter() {
    // Arrange
    DIContainer container = new DIContainer();
    container.register(UserRepository.class);
    
    // Act
    UserService service = container.getBean(UserService.class);
    
    // Assert
    assertThat(service.getRepository()).isNotNull();
}
```

## Good First Issues

Looking for a good first contribution? Check out issues labeled:

- 🟢 `good first issue` - Perfect for beginners
- 📚 `documentation` - Documentation improvements
- 🧪 `tests` - Writing or improving tests
- 🐛 `bug` - Bug fixes with clear reproduction steps

## Development Setup

### Prerequisites
- Java 11 or higher
- Maven 3.6+
- Git

### Running Tests
```bash
# Run all tests
mvn test

# Run specific test class
mvn test -Dtest=DIContainerTest

# Run tests with coverage (if configured)
mvn test
```

### Building Documentation
```bash
cd docs-site
npm install
npm run build
npm run serve
```

## Community Guidelines

### Be Respectful
- Use welcoming and inclusive language
- Be respectful of differing viewpoints and experiences
- Accept constructive criticism gracefully
- Focus on what is best for the community

### Communication
- **Issues**: Use issue templates for bug reports and feature requests
- **Pull Requests**: Provide clear descriptions and context

## Recognition

Contributors are recognized in our:
- 🏆 GitHub contributors graph
- 📚 Release notes for significant contributions

## Questions?

- 💬 **General Questions**: Use [GitHub Discussions](https://github.com/canermastan/jazzy-framework/discussions) for community help
- 🐛 **Bug Reports**: Use our [bug report template](https://github.com/canermastan/jazzy-framework/issues/new?template=bug_report.yml)
- 💡 **Feature Ideas**: Use our [feature request template](https://github.com/canermastan/jazzy-framework/issues/new?template=feature_request.yml)
- ❓ **Questions**: Use our [question template](https://github.com/canermastan/jazzy-framework/issues/new?template=question.yml)

Thank you for contributing to Jazzy Framework! 🚀 