# Contributing to Jazzy Framework

First off, thank you for considering contributing to Jazzy! It's people like you that make Jazzy such a great tool for the Nim community. 🎉

Following these guidelines helps to communicate that you respect the time of the developers managing and developing this open source project. In return, they should reciprocate that respect in addressing your issue, assessing changes, and helping you finalize your pull requests.

## ⚡ Quick Start

1.  **Fork** the repository on GitHub.
2.  **Clone** your fork locally:
    ```bash
    git clone https://github.com/YOUR_USERNAME/jazzy.git
    cd jazzy
    ```
3.  **Install Dependencies**:
    ```bash
    nimble install -d
    ```
4.  **Create a Branch** for your feature or fix:
    ```bash
    git checkout -b feature/amazing-feature
    ```

## 🛠️ Development Workflow

### Project Structure
- `src/jazzy/` - Core styles and framework logic.
- `examples/` - Example applications (check `todo_app`).
- `tests/` - Unit and integration tests.

### Running Tests
Please ensure all tests pass before submitting a PR.
```bash
nim c -r tests/all_tests.nim
```

### Coding Style
We generally follow the [Nim Style Guide](https://nim-lang.org/docs/nep1.html).
- Use 2 spaces for indentation.
- Use `camelCase` for variables and procedures.
- Add docstrings `##` for public procedures.

## 🚀 Pull Request Process

1.  **Update Documentation**: If your change affects public APIs, please update `README.md` or the relevant docstrings.
2.  **Add Tests**: If you are adding functionality, please add a corresponding test case in `tests/`.
3.  **Description**: In your PR description, clearly explain *what* you changed and *why*.
4.  **Review**: Wait for a maintainer to review your PR. We might ask for changes to match the project's design philosophy (Simplicity & Speed).

## � Reporting Bugs

Bugs are tracked as GitHub issues. When creating an issue, please explain:
1.  **Steps to Reproduce**: Minimal code example that causes the issue.
2.  **Expected Behavior**: What you thought should happen.
3.  **Actual Behavior**: What actually happened (stack trace, error message).

## 💡 Suggesting Enhancements

We love new ideas! If you have a suggestion:
1.  Check the `SUGGESTED_ISSUES.md` first to see if it's already planned.
2.  Open an issue using the **Feature Request** label.
3.  Describe the feature in detail and how it fits into the "Write Less, Build More" philosophy.

---

Thank you for hacking on Jazzy! 🎷
