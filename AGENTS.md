# AGENTS.md: Autonomous Engineering & Loop Guidelines for Moaiy

## Project Overview
Moaiy is a native macOS file encryption desktop client built with SwiftUI, Swift Concurrency, and modular cryptographic engines (OpenPGP via bundled GPG, Age protocol, and Kyber-768 PQC).

## Core Directives for Autonomous Agents

### 1. Loop Engineering Methodology (Inner Loop vs. Outer Loop)
- **Inner Loop**:
  1. Read specification from `specs/`.
  2. Write/modify Swift code under `Moaiy/`.
  3. Verify syntax and unit test coverage.
  4. Inspect failures, self-heal issues up to 3 attempts.
  5. Commit with semantic commit messages: `feat(scope): ...`, `fix(scope): ...`, `refactor(scope): ...`.
- **Outer Loop**:
  - Run continuous integration checks (`xcodebuild test`, ASan/TSan, `MoaiySandboxTest`, localization guard).

### 2. High-Risk Engineering Areas
- **App Sandbox**: Pay strict attention to entitlements, security-scoped bookmark resolution, and temporary directory life-cycles.
- **External Process Management**: Bundled GPG runs as a child process via `Process`. Keep IPC pipes non-blocking. Always handle cancellation via `Process.terminate()`.
- **Concurrency**: Ensure ViewModels use `@MainActor` and services leverage background actors or tasks to maintain smooth 60fps UI.

### 3. Repository Layout
- `Moaiy/App/`: Application delegate, entry point, window management.
- `Moaiy/Views/`: SwiftUI components and view hierarchies.
- `Moaiy/ViewModels/`: Presentation state, observable objects.
- `Moaiy/Services/`: Encryption engines (`GPGService`, `AgeService`, `PQCService`, `KeyManager`).
- `Moaiy/Theme/`: Design system tokens, styles, colors.
- `MoaiyTests/`: Unit test suite.
- `MoaiySandboxTest/`: Sandbox integration test suite.
- `specs/`: Work package functional specifications and acceptance criteria.
- `scripts/`: Build tooling, release integrity checks, loop runners.
