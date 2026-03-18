# Contributing to Moaiy

Thank you for your interest in contributing to Moaiy! This document provides guidelines and instructions for contributing to this project.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [Coding Standards](#coding-standards)
- [Commit Message Format](#commit-message-format)
- [Pull Request Process](#pull-request-process)
- [Testing Guidelines](#testing-guidelines)

## Code of Conduct

By participating in this project, you agree to maintain a respectful and inclusive environment. Please be considerate of others and follow these principles:

- Use welcoming and inclusive language
- Be respectful of differing viewpoints
- Gracefully accept constructive criticism
- Focus on what is best for the community
- Show empathy towards other community members

## Getting Started

### Prerequisites

- macOS 12.0 or later
- Xcode 15.0 or later
- Swift 6.2 or later
- GPG (GnuPG) installed via Homebrew (for testing)

### Fork and Clone

1. Fork the repository on GitHub
2. Clone your fork locally:
   ```bash
   git clone https://github.com/your-username/moaiy.git
   cd moaiy
   ```
3. Add the upstream repository:
   ```bash
   git remote add upstream https://github.com/moaiy-com/moaiy.git
   ```

## Development Setup

### Building the Project

1. Open `MoaiySandboxTest/MoaiySandboxTest.xcodeproj` in Xcode
2. Build the project (Cmd+B)
3. Run tests (Cmd+U)

### Bundling GPG

If you need to bundle GPG with the application:

```bash
# Run the GPG bundling script
./fix_gpg_deps.sh

# Or for a specific configuration
./fix_gpg_deps.sh Debug   # Debug build
./fix_gpg_deps.sh Release # Release build
```

## Coding Standards

### Swift Version

- Use **Swift 6.2** or later
- Use modern Swift concurrency (async/await)
- Avoid deprecated APIs

### Code Style

#### Modern Swift Features

```swift
// ✅ Correct: Use @Observable for state management
@MainActor
@Observable
class KeyManagementViewModel {
    var keys: [Key] = []
    var isLoading = false
}

// ❌ Avoid: Outdated ObservableObject
class KeyManagementViewModel: ObservableObject {
    @Published var keys: [Key] = []
}
```

#### Concurrency

```swift
// ✅ Correct: Use async/await
func encryptFile(_ url: URL) async throws -> URL {
    // Async encryption logic
}

// ❌ Avoid: GCD and closure callbacks
DispatchQueue.global().async {
    // Closure callbacks
}
```

#### Error Handling

```swift
// ✅ Correct: Detailed error types with user-friendly messages
enum GPGError: Error, LocalizedError {
    case gpgNotInstalled
    case executionFailed(String)
    case invalidPassword
    
    var errorDescription: String? {
        switch self {
        case .gpgNotInstalled:
            return "GPG tool is not installed"
        case .executionFailed(let message):
            return "Execution failed: \(message)"
        case .invalidPassword:
            return "Invalid password"
        }
    }
}
```

#### Naming Conventions

- **Classes**: PascalCase (`KeyManagementViewModel`)
- **Methods**: camelCase (`encryptFile(_:for:)`)
- **Properties**: camelCase (`isLoading`)
- **Constants**: camelCase (`defaultKeyLength`)
- **Enums**: PascalCase (`case rsa2048`)

### SwiftUI Best Practices

```swift
// ✅ Correct: Modular view design
struct KeyListView: View {
    @Environment(KeyManagementViewModel.self) private var viewModel
    
    var body: some View {
        List {
            ForEach(viewModel.keys) { key in
                KeyRowView(key: key)
            }
        }
        .navigationTitle("My Keys")
    }
}

// ✅ Correct: Modern API usage
.foregroundStyle(.primary)  // Not .foregroundColor()
.clipShape(.rect(cornerRadius: 12))  // Not .cornerRadius()
.scrollIndicators(.hidden)  // Not .showsIndicators(false)
```

### Security Guidelines

#### Password and Key Storage

```swift
// ✅ Correct: Use Keychain Services
class SecurePasswordStorage {
    func savePassword(_ password: String, for keyId: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keyId,
            kSecValueData as String: password.data(using: .utf8)!
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw SecurityError.keychainSaveFailed
        }
    }
}
```

#### Sandbox Compatibility

```swift
// ✅ Correct: Use security-scoped bookmarks
class FileAccessManager {
    func requestFileAccess() -> URL? {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.message = "Moaiy needs access to this folder"
        
        if panel.runModal() == .OK, let url = panel.url {
            saveBookmark(for: url)
            return url
        }
        return nil
    }
}
```

### Internationalization

- All UI text must use `Localizable.xcstrings`
- Code, variables, and comments: **English only**
- User-facing text: Support English + Chinese (Simplified)

```swift
// ✅ Correct: Use localization keys
Text("welcome_message")  // Auto-localizes
Text(.welcomeMessage)    // Symbolic keys (recommended)

// ❌ Avoid: Hardcoded text
Text("Welcome")  // Don't do this
```

## Commit Message Format

We follow the [Conventional Commits](https://www.conventionalcommits.org/) specification:

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

### Types

- `feat`: A new feature
- `fix`: A bug fix
- `docs`: Documentation only changes
- `style`: Code style changes (formatting, semicolons, etc.)
- `refactor`: Code change that neither fixes a bug nor adds a feature
- `test`: Adding missing tests or correcting existing tests
- `chore`: Changes to build process or auxiliary tools

### Examples

```bash
# Feature
git commit -m "feat: add key generation wizard"

# Bug fix
git commit -m "fix: resolve file encryption permission issue"

# Documentation
git commit -m "docs: update API documentation"

# Refactoring
git commit -m "refactor: simplify GPGService implementation"

# Testing
git commit -m "test: add unit tests for encryption service"
```

## Pull Request Process

### Before Submitting

1. **Update your branch** with the latest upstream changes:
   ```bash
   git fetch upstream
   git rebase upstream/main
   ```

2. **Run tests** to ensure everything works:
   ```bash
   # Build and test in Xcode (Cmd+U)
   # Or use command line:
   xcodebuild test -project MoaiySandboxTest.xcodeproj \
                   -scheme MoaiySandboxTest \
                   -destination 'platform=macOS'
   ```

3. **Check code style**:
   ```bash
   swiftlint
   ```

4. **Update documentation** if needed

### Submitting a Pull Request

1. Push your changes to your fork:
   ```bash
   git push origin your-branch-name
   ```

2. Create a Pull Request on GitHub

3. Fill in the PR template with:
   - Clear description of changes
   - Reference to related issues
   - Screenshots (if applicable)
   - Testing instructions

4. Wait for review and address any feedback

### Review Process

- All PRs require at least one review
- Reviewers will check for:
  - Code quality and style
  - Test coverage
  - Documentation updates
  - Security implications
  - Performance impact

## Testing Guidelines

### Unit Tests

```swift
// Example test
@Test("Generate key pair successfully")
func generateKeyPair() async throws {
    let config = KeyConfig(
        name: "Test User",
        email: "test@example.com",
        type: .rsa,
        length: 2048
    )
    
    let key = try await GPGService.shared.generateKeyPair(config: config)
    
    #expect(key.id.isNotEmpty)
    #expect(key.email == "test@example.com")
}
```

### Test Coverage

- Aim for >80% code coverage
- Test edge cases and error conditions
- Test async operations properly

### Running Tests

```bash
# Run all tests
xcodebuild test -project MoaiySandboxTest.xcodeproj \
                -scheme MoaiySandboxTest \
                -destination 'platform=macOS'

# Run specific test
xcodebuild test -project MoaiySandboxTest.xcodeproj \
                -scheme MoaiySandboxTest \
                -destination 'platform=macOS' \
                -only-testing:MoaiySandboxTestTests/SpecificTestClass
```

## Project Structure

```
moaiy/
├── MoaiySandboxTest/       # Sandbox test project
├── MoaiyUI/                # UI component library
├── doc/                    # Technical documentation
├── scripts/                # Build and utility scripts
├── .gitignore
├── LICENSE
├── README.md
└── CONTRIBUTING.md
```

## Getting Help

- **Issues**: Report bugs or request features via [GitHub Issues](https://github.com/moaiy-com/moaiy/issues)
- **Discussions**: Ask questions in [GitHub Discussions](https://github.com/moaiy-com/moaiy/discussions)
- **Documentation**: Check the `doc/` directory for technical details

## License

By contributing to Moaiy, you agree that your contributions will be licensed under the [MIT License](LICENSE).

---

Thank you for contributing to Moaiy! Your efforts help make encryption accessible to everyone. 🗿
