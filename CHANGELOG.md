# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Release execution checklist for v0.5.0 (`doc/v0.5.0-minimal-release-checklist.md`)
- Core flow validation list for v0.5.0 (`doc/v0.5.0-core-flow-validation.md`)

## [0.5.0] - 2026-04-10

### Added

- D1-D6 minimal release execution artifacts:
  - `doc/v0.5.0-minimal-release-checklist.md`
  - `doc/v0.5.0-core-flow-validation.md`
  - `doc/v0.5.0-d4-regression-matrix.md`
  - `doc/v0.5.0-d4-manual-regression-script.md`
  - `doc/v0.5.0-release-blockers.md`
  - `doc/v0.5.0-security-audit.md`
  - `doc/v0.5.0-release-notes.md`
- Added text-flow integration tests (`TextEncryptionFlowTests`) covering:
  - encrypt/decrypt roundtrip
  - decrypt failure with invalid passphrase
  - encrypt failure with invalid recipient
- Added file-flow integration tests (`FileEncryptionFlowTests`) covering:
  - file encrypt/decrypt roundtrip
  - conflict-safe destination suffix behavior

### Changed

- Exposed Backup/Restore entry in key action menu for primary user path.
- Completed release i18n quick pass on `Views + App` UI keys with explicit `en` and `zh-Hans` coverage.
- Localized key-management footer tagline and app navigation title using symbol keys.
- Restored app icon build configuration to `moaiy_icon` and embedded Icon Composer asset under `Assets.xcassets`.

### Fixed

- Fixed `actool` crash in thinned asset compile by moving `moaiy_icon.icon` into `Assets.xcassets` and avoiding standalone icon catalog input.
- Fixed release-blocking backup entry visibility issue in primary key action flow (`RB-003`).

### Security

- Fixed newline/control-character injection surface in key generation batch payload (`SAF-001`).
- Removed sensitive identity details from logs and replaced with non-identifying messages (`SAF-002`).
