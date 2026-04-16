# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Release execution checklist for v0.5.0 (`doc/v0.5.0-minimal-release-checklist.md`)
- Core flow validation list for v0.5.0 (`doc/v0.5.0-core-flow-validation.md`)

## [0.7.0] - 2026-04-16

### Added

- Added subkey management MVP for local secret keys (non smart-card stubs): list subkeys, add subkey, and update subkey expiration.
- Added ownertrust transfer flow: export ownertrust to file and import ownertrust from file.
- Added revocation management flow: generate ASCII-armored revocation certificate and import revocation certificate.
- Added service-layer command-builder coverage for ownertrust/revocation command construction.
- Added end-to-end hardening regression cases for ownertrust and revocation lifecycle + wrong-passphrase error mapping.
- Added release planning/task breakdown document for 0.7.x (`doc/v0.7.x-task-breakdown.md`).

### Changed

- Extended key action menu with trust operations entry points for ownertrust transfer and revocation center.
- Added Settings toggle for key-signing menu availability to reduce default action surface.
- Adjusted subkey card layout density to reduce card height and improve information scanning.
- Updated trust management sheet composition to host ownertrust/revocation sheets and align with actor-isolation requirements.
- Updated string catalog with new ownertrust/revocation/settings keys and 11-locale coverage.

### Fixed

- Fixed `TrustManagementSheet` default parameter actor-isolation warning by removing actor-isolated singleton from default argument context.
- Fixed ownertrust "none" downgrade command mapping to use gpg-compatible value for non-interactive trust updates.
- Fixed revocation certificate generation flow by removing unsupported batch flag from interactive revoke command path.

## [0.6.5] - 2026-04-15

### Added

- Expanded in-app language options to 11 locales (`en`, `zh-Hans`, `es`, `pt-BR`, `hi`, `ar`, `fr`, `de`, `ja`, `ko`, `ru`) while keeping default `Follow System`.
- Added localization integrity automation (`scripts/check_localization.py`) and CI hard-fail gate for missing keys/placeholder mismatches.

### Changed

- Refactored language metadata and dynamic bundle resolution for app-level localization selection in Settings.
- Updated project locale declarations (`knownRegions`) and completed string catalog coverage for newly supported locales.
- Bumped app marketing version from `0.6.1` to `0.6.5`.

### Fixed

- Fixed runtime language switching so main UI text updates immediately without app restart.
- Fixed Key Edit sheet layout overflow for long localized content (notably Japanese/Russian) with adaptive tab presentation.
- Right-aligned the Settings `Default Key Type` control for consistent form alignment.

## [0.6.1] - 2026-04-14

### Changed

- Updated release DMG naming to use hardware-friendly labels:
  - `Moaiy-X.Y.Z-macos-apple-silicon.dmg`
  - `Moaiy-X.Y.Z-macos-intel-chip.dmg`
- Bumped app marketing version from `0.6.0` to `0.6.1`.

## [0.5.3] - 2026-04-06

### Added

- Protected release workflow v2 (`.github/workflows/release.yml`) with manual dispatch inputs:
  - `version`
  - `mode (draft|publish)`
  - `signing (auto|unsigned|signed)`
  - `gate (balanced|strict|fast)`
- Release orchestration scripts under `scripts/release/`:
  - `run_release.sh`
  - `check_version_sync.sh`
  - `external_validation.sh`
  - `render_release_notes.sh`
  - `setup_tag_ruleset.sh`
  - release notes template

### Changed

- CI `build-and-test` now runs both build and tests, matching `main` protection semantics.
- `package_dmg.sh` now supports architecture-aware packaging, artifact naming, and explicit version consistency checks.
- Legacy `v050_external_validation.sh` now delegates to the version-agnostic validation script for backward compatibility.

### Security

- Introduced repository tag ruleset support script to protect `v*` tags from deletion and non-fast-forward rewrites.

## [0.5.1] - 2026-04-05

### Changed

- Hidden the `Backup/Restore` action-menu entry by default while keeping the full flow implementation behind a feature toggle.
- Centered create-key loading/success states for consistent modal feedback alignment.
- Moved the key-management footer brand logo/text note into a non-blocking background layer to prevent key-card content occlusion.

### Fixed

- Updated key action menu availability tests to verify backup menu is hidden by default and still restorable via flag.

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
