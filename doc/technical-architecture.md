# Moaiy Technical Architecture

> Product: Moaiy (macOS native OpenPGP key manager)
> Architecture baseline for v0.5.x
> Updated: 2026-04-05

## 1. Technology Stack

### Core stack
| Layer | Technology | Notes |
| --- | --- | --- |
| App language | Swift | Native macOS development |
| UI | SwiftUI | Primary UI framework |
| Concurrency | async/await | Structured async operations |
| Crypto runtime | Bundled GPG toolchain | Self-contained execution model |
| Platform | macOS | App Sandbox compatibility required |

### Supporting APIs
- `Process` for runtime invocation
- `FileManager` and sandbox-safe file operations
- Keychain APIs for sensitive credentials
- `UserNotifications` for user reminders (where applicable)

## 2. System Architecture

Moaiy follows a layered architecture with clear boundaries:

1. Presentation Layer (Views)
2. State/Orchestration Layer (ViewModels)
3. Domain/Service Layer (GPG and feature services)
4. Resource/Runtime Layer (bundled binaries, file system, system integrations)

### High-level flow
1. User action is triggered in SwiftUI view.
2. ViewModel validates input/state.
3. Service layer executes business logic or crypto command.
4. Result is mapped into UI-safe state for rendering.

## 3. Core Modules

## 3.1 GPGService

### Responsibilities
- Key listing and key metadata retrieval
- Key generation/import/export/delete
- Text and file encryption/decryption
- Signature verification and keyserver-adjacent operations (as supported)

### Design constraints
- No sensitive plaintext logging
- Deterministic command construction
- Explicit error mapping for user-safe messaging

## 3.2 Key Management ViewModel

### Responsibilities
- Manage key list state and filtering
- Coordinate action menu operations
- Orchestrate sheet/alert state transitions
- Translate service errors to actionable UX states

### State principles
- Single source of truth per screen
- Main-thread UI updates only
- Side effects isolated in service calls

## 3.3 File and Access Services

### Responsibilities
- User-authorized file picking and save flows
- Bookmark persistence/recovery for sandbox continuity
- Safe temporary path handling inside container

### Security posture
- No broad path assumptions
- Graceful fallback when permission scope is invalid

## 3.4 Backup and Recovery Flows

### Responsibilities
- Export/import backup artifacts
- Validate backup integrity before mutation
- Provide human-readable operation summaries

## 3.5 Optional Hardware Key Layer (Pro scope)

### Responsibilities
- Device detection and capability reporting
- Guided setup and operation boundaries
- Explicit failure messaging for unsupported states

## 4. Data Model Direction

### Primary entities
- Key identity and capabilities
- Trust/validity status
- Operation result metadata (success/failure context)

### Modeling rules
- Keep models UI-independent where possible
- Use explicit enums for trust/error categories
- Preserve immutable identifiers for stable reconciliation

## 5. Error Handling Architecture

### Error classes
1. User-actionable errors (retry, re-authorize, correct input)
2. Environment/runtime errors (missing dependency, permission failures)
3. Internal errors (unexpected states needing diagnostics)

### UX contract
Every blocking error should provide:
- what failed
- likely reason
- one clear next action

## 6. Security Architecture

### Sensitive data handling
- Passphrases handled in bounded scope.
- Sensitive memory retained only as long as needed.
- Logging excludes key material and private plaintext.

### Storage policy
- Secret persistence uses secure system primitives (for allowed scopes).
- Backup outputs require explicit user intent.

### Execution policy
- Prefer bundled runtime behavior over external mutable system state.
- Validate runtime integrity in build/release flows.

## 7. Performance Strategy

### Runtime goals
- Non-blocking UI for long operations
- Predictable progress and completion reporting
- Minimized redundant key list refreshes

### Engineering tactics
- Structured concurrency for async command execution
- Bounded in-memory buffers for large file operations
- Avoid repeated expensive shell calls when cacheable

## 8. Test Strategy

### Unit tests
- Model parsing and state transitions
- Service command planning and error mapping
- ViewModel behavior under success/failure paths

### Integration tests
- Text/file encryption roundtrip
- Key import/export consistency
- Action menu availability and gating rules

### Release validation
- Sandbox-sensitive smoke tests
- Bundled runtime execution checks
- Manual UX regression for critical flows

## 9. Deployment and Packaging

### Build artifacts
- Xcode build output (`.app`)
- DMG packaging through project scripts

### Release controls
- Tag-based GitHub releases
- Repeatable packaging with checksum capture
- Branch-protected merge path into `main`

## 10. Operational Guidelines

### Change management
- Keep architecture docs synchronized with actual code behavior.
- Record intentional deviations in release notes/changelog.
- Treat sandbox and crypto behavior changes as high-risk changes requiring explicit validation.

---

This document is intentionally implementation-oriented.
If architecture and code diverge, update this file in the same PR as the code change.
