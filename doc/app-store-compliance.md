# Moaiy App Store Compliance Plan

> Project: Moaiy (macOS native OpenPGP key manager)
> Scope: App Store review readiness for encryption, sandboxing, privacy, and licensing
> Updated: 2026-04-05

## 1. Risk Snapshot

| Area | Risk | Why It Matters | Mitigation Priority |
| --- | --- | --- | --- |
| Export compliance (encryption) | Medium | Mandatory disclosure for cryptographic functionality | High |
| App Sandbox constraints | High | Core workflows depend on file and process access | High |
| Command-line runtime usage | High | Runtime behavior must remain sandbox-safe and review-friendly | High |
| Privacy disclosures | Medium | App Store metadata must match actual data behavior | High |
| Open-source license handling | Low | Notices must be complete and accurate | Medium |
| Monetization boundaries | Medium | Feature gating must not violate platform policy | Medium |

## 2. Export Compliance (Encryption)

Moaiy uses industry-standard cryptography for local key management and encryption workflows.

### 2.1 Classification posture
- Primary use: user data protection and personal key management
- Algorithms in use: OpenPGP toolchain (including asymmetric, symmetric, and hash primitives)
- Operational pattern: user-initiated encryption/decryption and key operations on macOS

### 2.2 App Store Connect declaration checklist
- Declare that the app uses encryption.
- Provide purpose statement focused on user data protection and secure communication/file handling.
- Confirm whether any custom cryptography is introduced (if no, state reliance on standard vetted cryptographic implementations).
- Keep supporting rationale ready for reviewer follow-up.

### 2.3 Operational controls
- Keep a single source of truth for algorithm/runtime claims in product docs.
- Ensure release notes do not conflict with compliance declarations.
- Re-check declaration whenever encryption scope changes.

## 3. Sandbox Strategy

Moaiy targets App Sandbox compatibility by design.

### 3.1 Core principles
- Prefer user-mediated file access (`NSOpenPanel` / `NSSavePanel`).
- Persist scoped access where needed with security-scoped bookmarks.
- Restrict long-term file access to explicitly granted paths.
- Avoid undeclared privileged behaviors.

### 3.2 File access model
1. User selects file/directory in system panel.
2. App receives sandbox-approved URL.
3. App stores bookmark for future access when appropriate.
4. Access is started/stopped in bounded scopes.

### 3.3 Process/runtime model
- Execute only app-bundled runtime components required for product behavior.
- Keep runtime location deterministic in app bundle resources.
- Validate executable and dylib structure during CI/release validation.

### 3.4 Entitlement hygiene
- Keep minimum entitlements.
- Avoid capability creep between Debug and Release.
- Re-audit entitlements before every public release.

## 4. Hardware Key Support (Pro Scope)

If hardware token/smart card features are enabled:
- Gate capability behind explicit user-facing feature boundaries.
- Request only required permissions.
- Document exactly what data leaves the app (if any).
- Add review notes explaining workflow necessity and user consent path.

## 5. Privacy & Data Handling

### 5.1 Product posture
- Default model: local-first key and encryption workflows.
- No hidden telemetry claims in docs unless implemented and disclosed.
- Sensitive values must never be logged in plaintext.

### 5.2 Review-facing privacy checklist
- App Privacy metadata aligns with real runtime behavior.
- Privacy policy text aligns with actual data collection/sharing.
- If analytics/crash reporting is introduced, update policy and metadata before release.

## 6. Open-Source License Compliance

### 6.1 Required artifacts
- Keep `THIRD_PARTY_NOTICES.md` current.
- Maintain license attributions for bundled/open-source components.
- Validate redistribution obligations for all bundled binaries/libraries.

### 6.2 Release checklist
- Confirm license files are present in repository and release packaging if required.
- Confirm attribution strings are accurate and current.

## 7. Submission Readiness Checklist

### Technical
- [ ] Release build succeeds on clean environment.
- [ ] Sandbox-sensitive flows pass validation.
- [ ] Entitlements reviewed and minimized.
- [ ] Bundled crypto runtime validation completed.

### Compliance
- [ ] Encryption declaration in App Store Connect updated.
- [ ] Privacy metadata and policy reviewed.
- [ ] Third-party notices and licenses reviewed.

### UX / metadata
- [ ] App description does not make unverifiable compliance claims.
- [ ] Screenshots and feature claims match current product behavior.
- [ ] Known limitations are documented for support handling.

## 8. Reviewer-Rejection Playbook

### Common rejection vectors
- Insufficient encryption disclosure
- Entitlement/sandbox mismatch
- Privacy metadata inconsistency
- Ambiguous feature gating language

### Response strategy
1. Respond with concrete technical evidence (not generic claims).
2. Provide exact workflow steps and permission rationale.
3. Patch quickly and resubmit with concise delta notes.
4. Keep an internal log of reviewer feedback for future releases.

## 9. Alternative Distribution (If Needed)

If App Store path is delayed:
- Continue GitHub Release distribution for OSS users.
- Keep notarization/signing roadmap documented separately.
- Maintain parity between distributed binaries and repository tags.

## 10. Decision Record (Current)

- Current public path: GitHub Releases for early OSS versions.
- App Store path: maintained as a compliance-ready track, not blocked by architecture.

---

This plan is intentionally implementation-oriented. Update it whenever encryption scope, sandbox capabilities, or privacy behavior changes.
