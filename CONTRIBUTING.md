# Contributing to Jazzy Framework 🎷

First of all, thank you for being here! Jazzy is built on the belief that **developer happiness leads to better software.** By contributing, you're not just writing code; you're helping Nim developers build features faster and with less friction.

---

## 💎 The Jazzy Philosophy
Before you dive in, keep our core values in mind:
1. **Simplicity First:** If a feature can be implemented in a simpler way for the end-user, do it.
2. **Speed is a Feature:** Jazzy should stay lightweight and fast.
3. **Batteries Included, but Swappable:** Provide great defaults, but never force them.
4. **Intuitive DX:** A developer should be able to guess how a method works without reading the docs.

---

## 🚀 How to Get Started

### 1. Find Your Path
*   **Bug Hunter:** Fix issues labeled as `bug`.
*   **Feature Architect:** Implement items from `SUGGESTED_ISSUES.md` or propose new ones.
*   **Documentation Wizard:** Improve our guides, add examples, or fix typos. Our documentation repo is located at [github.com/canermastan/jazzyframework](https://github.com/canermastan/jazzyframework).
*   **Community Hero:** Help others in GitHub Discussions or Issues.

### 2. Local Setup
1. **Fork & Clone:**
   ```bash
   git clone https://github.com/YOUR_USERNAME/jazzy-framework.git
   cd jazzy-framework
   ```
2. **Install Dependencies:**
   ```bash
   nimble install -d
   ```
3. **Create a Feature Branch:**
   ```bash
   git checkout -b feat/your-exciting-feature
   ```

### 3. Testing Your Changes
We take stability seriously. Please run the tests before submitting:
```bash
# Run all tests
nimble test
```

---

## 🛠️ Development Guidelines

### Project Structure
- `src/jazzy/` - The core engine (HTTP, Auth, DB, Utils).
- `src/jazzy/devui/` - The interactive developer dashboard.
- `examples/` - Real-world scenarios. Always update these if you change core APIs!
- `tests/` - Where the magic is verified.

### Coding Style (The Nim Way)
- Follow the [Nim Style Guide](https://nim-lang.org/docs/nep1.html).
- **Indentation:** 2 spaces.
- **Naming:** `camelCase` for procs/vars, `PascalCase` for Types.
- **Documentation:** Use `##` for all public procedures. If it's public, it must be documented.

---

## 📤 Pull Request Process

1. **Self-Review:** Did you follow the style? Are there any `echo` or `debug` statements left?
2. **Update Docs:** Did you change an API? Update the README or examples.
3. **Commit Messages:** We prefer semantic commits:
   - `feat:` for new features
   - `fix:` for bug fixes
   - `docs:` for documentation changes
   - `chore:` for maintenance
4. **Description:** Explain the **why**, not just the **what**.

---

## ❤️ Code of Conduct
Be kind, be professional, and be supportive. We are all here to learn and build together.

**Happy Hacking!** 🎷
