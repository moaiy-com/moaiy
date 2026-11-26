# Release Workflow Skill (Tracked Spec)

This document is the tracked specification for Moaiy release skill behavior.
The local runtime skill in `.factory/skills/release-workflow/skill.md` should stay aligned.

## Mandatory Rule

Primary path must always execute through:

```bash
./scripts/release/run_release.sh --version X.Y.Z --mode draft|publish --signing auto|unsigned|signed --gate balanced|strict|fast
```

Then publish with GitHub `Release` workflow (`workflow_dispatch`).
The workflow is split into `release_build` and `release_publish` jobs.
If publish/metadata step fails, rerun failed jobs without re-running full build/package by default.

Only if the `Release` workflow itself is broken (workflow defect, not product/test failure),
use the controlled fallback path.

## Standard Flow

1. Confirm working branch is clean and synced to `origin/main`.
2. Run version sync guard:

```bash
./scripts/release/check_version_sync.sh --version X.Y.Z
```

3. Run release orchestration:

```bash
./scripts/release/run_release.sh --version X.Y.Z --mode draft --signing auto --gate balanced
```

4. Review generated artifacts:
   - `dist/release/vX.Y.Z-*/assets/Moaiy-X.Y.Z-macos-apple-silicon.dmg`
   - `dist/release/vX.Y.Z-*/assets/Moaiy-X.Y.Z-macos-intel-chip.dmg` only when `gpg.bundle` contains an `x86_64` slice
   - `dist/release/vX.Y.Z-*/SHA256SUMS.txt`
   - `dist/release/vX.Y.Z-*/release-manifest.json`
   - `dist/release/vX.Y.Z-*/release-notes.md`
   - `release-notes.md` must include a detailed change list for the target version
     (auto-extracted from `CHANGELOG.md`, not only packaging metadata)
   - Current `gpg.bundle` is arm64-only, so the official path publishes the Apple Silicon DMG and does not require an Intel file.
5. Create or verify release tag `vX.Y.Z` on `origin/main`.
6. Publish with GitHub workflow (`Release`) after draft verification.
7. Verify published release state and digests:

```bash
./scripts/release/verify_github_release.sh \
  --repo moaiy-com/moaiy \
  --tag vX.Y.Z \
  --mode draft|publish \
  --arm64-dmg-path <path> \
  --sha256-path <path> \
  --manifest-path <path>
```

Add `--x86-64-dmg-path` only when `release-manifest.json` lists an `x86_64` artifact. Omitting it for an Apple Silicon-only manifest is required. Passing it when the manifest has no Intel artifact fails closed, and a manifest that lists Intel without the flag also fails.

## Release Note Policy

- Release notes must contain version-specific detailed updates (Added/Changed/Fixed/Security, etc.).
- The source of truth for detailed updates is `CHANGELOG.md` section `## [X.Y.Z]`.
- `CHANGELOG.md` for the target version must include bilingual detail blocks:
  - English: `### Added`, `### Changed`, `### Fixed`, ...
  - Chinese: `### Added (zh-Hans)`, `### Changed (zh-Hans)`, `### Fixed (zh-Hans)`, ...
- Packaging metadata (assets, hashes, gate/signing mode) is supplementary and cannot replace detailed updates.
- Renderer behavior is strict: missing `zh-Hans` detail blocks fails release-note generation.
- During release review, compare generated `release-notes.md` against the corresponding changelog section before publish.
- If a published release note is incomplete, patch it with:

```bash
gh release edit vX.Y.Z --repo moaiy-com/moaiy --notes-file <release-notes.md>
```

## Gate Policy

x86_64 gates run only when `lipo` reports an `x86_64` slice in `gpg.bundle`. The current bundle does not, so every gate level runs the arm64 gate only.

- `balanced` (default): arm64 full test gate, plus x86_64 smoke when that slice exists
- `strict`: arm64 full test gate, plus x86_64 full when that slice exists
- `fast`: arm64 full test gate only

## Signing Policy (Dual Track)

- `auto`: signed Release track when `MOAIY_DEVELOPMENT_TEAM_ID` (environment or `Moaiy/Config/Moaiy.Signing.xcconfig`) is a real team id. Otherwise the unsigned Debug track. Placeholders (`YOUR_TEAM_ID`, `__TEAM_ID_PLACEHOLDER__`) are not valid.
- `unsigned`: always use the unsigned Debug path, including `--mode publish`
- `signed`: fail fast if no valid team id is configured
- `--mode publish` does not require a signed artifact. With no valid team id, publish completes on the unsigned track.
- Unsigned release notes must say the build is not code-signed, is not notarized, that macOS Gatekeeper will block opening it until the user allows it, and that it is not a substitute for a Developer ID signed and notarized release. `package_dmg.sh` has no notarization step; do not describe an unsigned package as notarized.
- Signed notes must still say that packaging itself does not notarize the app.

## Unsigned official publish (no Apple Developer account)

Tag `vX.Y.Z` must already point at the `origin/main` commit that contains this policy, and `build-and-test` must be green on that commit. Then dispatch the `Release` workflow:

```bash
gh workflow dispatch Release \
  --repo moaiy-com/moaiy \
  --ref main \
  -f version=X.Y.Z \
  -f mode=publish \
  -f signing=auto \
  -f gate=balanced
```

`signing=auto` stays on the signed Release track once a team id is configured. `signing=unsigned` forces the unsigned track even if a team id is present. The workflow creates a draft only as the upload staging step, then edits it to a public release when `mode=publish`.

## Repository Ruleset Prerequisite

When `v*` tag creation is protected by rulesets, the `Release` workflow does not create tags.
Create `vX.Y.Z` manually on `origin/main` with an authorized account before triggering workflow dispatch.
Both lightweight and annotated tags are accepted by workflow SHA checks.

## Release Safety CI

`Release Safety` workflow validates release-critical changes on PR/push when any of these paths change:
- `.github/workflows/release.yml`
- `scripts/release/**`
- `scripts/package_dmg.sh`
- `Moaiy/Moaiy.xcodeproj/project.pbxproj`
- `Moaiy/Resources/Assets.xcassets/**`
- `CHANGELOG.md`

It enforces:
- asset catalog integrity guard (`check_asset_catalog_integrity.sh`)
- version sync guard (`check_version_sync.sh --allow-existing-tag`)
- arm64 smoke external validation (`external_validation.sh --mode smoke --arch arm64`)

## Controlled Fallback (Workflow Defect Only)

Use only when `Release` workflow fails due workflow logic defects
(for example check query bug), while source commit and gates are already validated.

1. Run `run_release.sh` on `main` and collect artifacts.
2. Create/verify tag `vX.Y.Z` points to `origin/main`.
3. Create draft release first (metadata only).
4. Upload assets with `--clobber`.
5. Edit draft to publish (`--draft=false`) only after upload succeeds.
6. Run `verify_github_release.sh` and archive evidence.
7. Immediately open a fix PR to restore normal workflow path before next release.

## Failure Handling

- Version mismatch: fix `MARKETING_VERSION` + `CHANGELOG` before rerun.
- Gate failure: do not create/update tag; fix tests first.
- Artifact mismatch: regenerate the architectures this runtime can package in the same run. Do not publish an Intel DMG the manifest does not list, and do not omit one it does list.
- Existing tag conflict: resolve tag target mismatch before any release update.
- Workflow defect fallback used: publish can proceed with controlled fallback,
  but workflow fix PR is mandatory before next release.
