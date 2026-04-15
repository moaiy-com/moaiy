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
   - `dist/release/vX.Y.Z-*/assets/Moaiy-X.Y.Z-macos-intel-chip.dmg`
   - `dist/release/vX.Y.Z-*/SHA256SUMS.txt`
   - `dist/release/vX.Y.Z-*/release-manifest.json`
   - `dist/release/vX.Y.Z-*/release-notes.md`
5. Create or verify release tag `vX.Y.Z` on `origin/main`.
6. Publish with GitHub workflow (`Release`) after draft verification.
7. Verify published release state and digests:

```bash
./scripts/release/verify_github_release.sh \
  --repo moaiy-com/moaiy \
  --tag vX.Y.Z \
  --mode draft|publish \
  --arm64-dmg-path <path> \
  --x86-64-dmg-path <path> \
  --sha256-path <path> \
  --manifest-path <path>
```

## Gate Policy

- `balanced` (default): arm64 full test gate + x86_64 smoke gate
- `strict`: arm64 full test gate + x86_64 full test gate
- `fast`: arm64 full test gate only

## Signing Policy (Dual Track)

- `auto`: signed track when team id is configured, otherwise unsigned track
- `unsigned`: always use unsigned distribution path
- `signed`: fail fast if no valid team id is configured

## Repository Ruleset Prerequisite

When `v*` tag creation is protected by rulesets, the `Release` workflow does not create tags.
Create `vX.Y.Z` manually on `origin/main` with an authorized account before triggering workflow dispatch.

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
- Artifact mismatch: regenerate both architectures in the same run.
- Existing tag conflict: resolve tag target mismatch before any release update.
- Workflow defect fallback used: publish can proceed with controlled fallback,
  but workflow fix PR is mandatory before next release.
