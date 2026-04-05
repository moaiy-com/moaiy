# Moaiy Technical Validation Status

> Scope: Runtime, sandbox behavior, packaging, and release-critical crypto workflows
> Updated: 2026-04-05

## 1. Validation Summary

| Area | Status | Notes |
| --- | --- | --- |
| Core GPG command execution | Complete | Bundled runtime path validated |
| Key management core flows | Complete | Generate/import/export/delete paths covered |
| Text/file crypto roundtrip | Complete | Integration tests available |
| Sandbox authorization model | Complete (baseline) | User-granted file model validated |
| Intel external environment pass | Complete for release target scope | Captured in v0.5.0 validation artifacts |
| App Store-specific submission loop | Pending | Compliance track prepared, not the active distribution path |

## 2. Completed Validation Tracks

## 2.1 Bundled runtime validation
- Runtime binaries and library dependencies packaged in app resources.
- Command invocation works in tested macOS environments.
- Regression checks added to release validation process.

## 2.2 Core key and crypto workflows
- Key lifecycle operations validated through automated and manual passes.
- Text encryption/decryption roundtrip covered by tests.
- File encryption/decryption roundtrip covered by tests.

## 2.3 Release validation pack (v0.5.0 baseline)
- External validation helper scripts executed.
- Manual regression evidence captured for release-critical user flows.
- Known blockers were tracked and closed before release publication.

## 2.4 Hotfix validation (v0.5.1)
- Action menu behavior regression validated.
- UI regressions fixed and re-validated.
- GitHub release artifact published with checksum.

## 3. Open / Ongoing Items

## 3.1 App Store submission readiness loop
- Compliance documents and sandbox strategy exist.
- End-to-end App Store review cycle is still pending execution.

## 3.2 Hardware key Pro-path validation
- Design and architecture direction documented.
- Full production-grade validation remains scoped for future milestones.

## 4. Evidence Sources

Primary references in repository:
- `doc/v0.5.0-minimal-release-checklist.md`
- `doc/v0.5.0-d4-regression-matrix.md`
- `doc/v0.5.0-release-blockers.md`
- `doc/v0.5.0-security-audit.md`
- `CHANGELOG.md`

## 5. Risk Posture

### Current high-confidence areas
- Bundled runtime viability
- Core user encryption workflows
- Release packaging reproducibility for GitHub path

### Remaining risks
- Policy/process risk for App Store submission cycle
- Expanded surface risk when enabling advanced Pro hardware flows

## 6. Recommended Next Actions

1. Keep release smoke validation scripts versioned and current.
2. Add/update automated checks whenever menu gating or key operation behavior changes.
3. Run periodic sandbox regression pass on latest macOS + architecture variants.
4. If App Store path is prioritized, start a dedicated submission readiness sprint with reviewer-feedback tracking.

## 7. Decision Record

- Active public distribution path: GitHub Releases.
- Validation process: release checklist + automated smoke + focused manual regression.
- Documentation baseline: English engineering docs (except `README_CN.md` by design).

---

This file tracks operational validation status, not product roadmap scope.
Update it whenever release quality gates or runtime behavior materially change.
