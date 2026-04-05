# Moaiy Extreme Usability Design

> Goal: Make secure encryption workflows approachable for non-technical users without reducing cryptographic safety.
> Updated: 2026-04-05

## 1. Design Thesis

Security tooling fails when users must learn cryptography before they can protect data.
Moaiy design choices are therefore driven by one principle:

- The user focuses on intent.
- The app handles technical complexity.

### Core principles
- Zero-friction onboarding
- Safe defaults first
- Plain-language UX
- Progressive disclosure for advanced controls
- Strong security boundaries with clear feedback

## 2. Problem vs Solution

| User Problem | Legacy GPG Experience | Moaiy Direction |
| --- | --- | --- |
| Setup overhead | Install/patch CLI + dependencies manually | Bundled runtime inside app |
| Cognitive load | Command syntax and flags | Action-oriented UI labels |
| Error recovery | Opaque stderr output | Human-readable diagnostics + next action |
| Key management anxiety | Manual file/identity handling | Guided creation, import, trust, export flows |
| New-user confidence | Steep learning curve | Fast “first success” path |

## 3. Zero-Setup Experience

### Product expectations
- One app bundle, no external installers required for basic use.
- First launch prepares runtime automatically.
- No mandatory terminal interaction.

### First-run UX
1. Welcome panel explains value in plain language.
2. Initialization runs in background with visible progress.
3. User lands directly in key management with a clear first action.

### Acceptance criteria
- New user can reach key creation flow in under 30 seconds.
- First-run errors are actionable and non-technical.

## 4. Smart Key Management

### Key creation
- Provide safe defaults (algorithm, size, expiration recommendations).
- Validate identity fields early.
- Keep advanced options collapsible.

### Key list and cards
- Prioritize identity and status clarity.
- Show concise trust/validity state.
- Keep high-frequency actions one tap away.

### Import/export
- Support both file picker and drag-and-drop.
- Show pre-flight checks before mutation.
- Use clear completion messaging with destination hints.

## 5. Minimal Encryption Flow

### Text encryption
- Single obvious entry point.
- Recipient selection defaults to the current key context.
- Copy/save actions available immediately after success.

### File encryption
- Drag-and-drop first.
- Show source, destination, and overwrite policy before execution.
- Preserve original by default; never silently delete user files.

### Success state
- Confirm what happened.
- Provide next-step actions:
  - open destination
  - copy output path
  - run another operation

## 6. Assisted Decryption Flow

### Detection and prompts
- Detect encrypted payload format where possible.
- Ask only for the minimum required input.
- Explain passphrase request context.

### Sensitive output handling
- Provide controlled reveal/copy patterns.
- Offer optional clipboard cleanup after copy.
- Avoid retaining plaintext longer than needed.

## 7. Hardware Key (Pro) UX Strategy

### Goals
- Treat hardware-key setup as a guided wizard.
- Prefer “recommended” defaults for most users.
- Keep advanced controls available but out of the critical path.

### Setup flow
1. Detect connected device and compatibility.
2. Guide PIN/passphrase setup.
3. Generate/import key material with explicit confirmations.
4. Run post-setup validation and quick usage test.

### Safety notes
- Explain irreversible actions before commit.
- Require explicit confirmation for destructive operations.

## 8. Contextual Help System

### Help behavior
- Help appears when confidence is low or errors occur.
- Keep guidance task-specific and short.
- Include one direct recovery action per message.

### Examples
- Wrong passphrase: suggest keyboard layout and retry path.
- Recipient mismatch: explain missing key and import options.
- File permission issue: guide user to re-authorize path.

## 9. Backup and Recovery UX

### Baseline
- Encourage regular encrypted backups.
- Make backup status visible but non-intrusive.
- Avoid fear-driven wording.

### Recovery
- Provide a predictable restore flow with validation summary.
- Warn before overwrite or trust-state replacement.
- Confirm completion with a diff-like summary where feasible.

## 10. Error Handling and Auto-Repair

### Error model
- Classify errors into:
  - user-actionable
  - transient/retryable
  - internal/bug-report candidates

### UX contract
- Every blocking error must include:
  - what failed
  - why (plain language)
  - what to do next

### Auto-repair boundaries
- Auto-repair safe config/runtime issues only.
- Never auto-modify key material without explicit user consent.

## 11. Productivity Enhancements

### Candidate features
- Menu-bar quick actions
- Keyboard shortcuts for common encrypt/decrypt actions
- Finder-integrated handoff entry points (where policy-compliant)

### Principle
Speed features must not bypass security confirmation boundaries.

## 12. Performance Model

### Requirements
- All long-running operations are async.
- UI remains responsive during cryptographic operations.
- Visible progress for operations above human perception threshold.

### Engineering expectations
- Background operation queueing
- Cancellation support where safe
- Deterministic operation-result reporting

## 13. Measurable Usability Targets

| Metric | Target |
| --- | --- |
| Time to first successful encryption | < 5 minutes for new user |
| Time to repeat encryption | < 15 seconds |
| Key operation error-recovery success | > 80% without external help |
| User-reported clarity (internal testing) | > 4.5 / 5 |

## 14. Rollout Priorities

### Phase A (must-have)
- First-run onboarding
- Key creation/import/export baseline
- Text/file encrypt/decrypt baseline
- Friendly error messaging

### Phase B (quality)
- Contextual help
- Backup/restore polish
- Accessibility pass
- Performance and responsiveness tuning

### Phase C (advanced)
- Hardware key guided setup
- Expanded automation and integration surfaces

---

This document is intentionally product-facing but implementation-ready.
Update it whenever core interaction flows, trust semantics, or safety boundaries change.
