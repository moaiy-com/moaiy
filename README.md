# Moaiy

> Protect what matters with drag and drop.

Moaiy helps you protect your important information through simple, easy actions.

Moaiy is an open-source macOS app for encryption and recovery workflows, designed with a native SwiftUI experience.

**[Chinese Version](./README_CN.md)**

Latest stable release: `v1.0.0`
Current rollout: Streaming large-file crypto pipeline, Keychain & Touch ID passphrase integration, `moaiy-cli` companion tool, and Kyber-768 hybrid post-quantum encryption

## App Screenshot

![Moaiy main key management view](./doc/images/moaiy-main-ui.png)

## What's New in v1.0.0

Moaiy v1.0.0 marks the first General Availability milestone, introducing a bounded-memory streaming crypto pipeline, macOS Keychain & Touch ID integration, a companion CLI tool (`moaiy-cli`), and hardened App Sandbox staging.

- **Streaming File Crypto Pipeline (`StreamingCryptoPipeline`)**: 256KB chunked I/O with independent `stdinQueue`/`stdoutQueue` 8MB backpressure throttling, per-chunk `autoreleasepool` drainage (<32MB Peak RSS delta on 64MB streams), and `0600` isolated passphrase token files.
- **Overwrite-Safe Sandbox Staging (`commitStagedFile`)**: POSIX `statfs` net disk-space preflight, `open(O_WRONLY)` permission pre-check, rollback backup (`original.bak`) with zero-scrubbing, and in-place `ftruncate` + stream write + `fsync` to preserve `NSSavePanel` sandbox grants and target file inodes without data loss.
- **System Keychain & Touch ID Integration (`KeychainService`)**: Stores and retrieves private key passphrases via macOS Data Protection Keychain and `LocalAuthentication` (`.userPresence` for Touch ID, Apple Watch, and device passcode), with single-pass primary/subkey fingerprint resolution (`resolvePrimaryFingerprint`).
- **Memory & Scratch Lifecycle Hygiene (`SecureMemory` & `TransientFileRegistry`)**: Best-effort `memset_s` buffer zeroization on deallocation, automatic zero-scrubbing and purge of active scratch directories on app termination (`willTerminateNotification`), and 24-hour stale directory cleanup on launch.
- **Companion CLI (`moaiy-cli`)**: Standalone command-line tool (`MoaiyCLI` target) supporting `status` (including Kyber-768 detection), `list-keys`, `encrypt`, and `decrypt`.
- **Post-Quantum Ready (`v0.9.0`+)**: Built-in GnuPG 2.5.21 runtime (`gpg.bundle`) supporting Kyber-768 hybrid OpenPGP keys alongside classical RSA-4096 and ECC keys.

## Features

- Generate, import, export, and delete keys (ECC, RSA-4096, RSA-2048, and Kyber-768 hybrid PQC)
- Encrypt and decrypt text and large files via bounded-memory streaming I/O
- Store and unlock key passphrases with macOS Keychain & Touch ID
- Companion `moaiy-cli` tool for terminal and script automation
- Trust management, subkey lifecycle, ownertrust transfer, revocation certificates, and key signing flows
- Backup and restore workflows with integrity verification
- Bundled GnuPG 2.5.21 runtime (`gpg.bundle`) for zero-dependency sandboxed execution

## Requirements

- macOS 14.0+ (app runtime)
- Xcode with macOS 14+ SDK support

## Quick Start

### Option 1: Download Release

- Download the latest `.dmg` from [GitHub Releases](https://github.com/moaiy-com/moaiy/releases)
- Apple Silicon Macs: `Moaiy-1.0.0-macos-apple-silicon.dmg`
- Intel Macs: `Moaiy-1.0.0-macos-intel-chip.dmg`

### Option 2: Build from Source

```bash
git clone https://github.com/moaiy-com/moaiy.git
cd moaiy
open Moaiy/Moaiy.xcodeproj
```

Or build `Moaiy` and `MoaiyCLI` via CLI:

```bash
xcodebuild -project Moaiy/Moaiy.xcodeproj \
           -scheme Moaiy \
           -destination 'platform=macOS,arch=arm64' \
           build

xcodebuild -project Moaiy/Moaiy.xcodeproj \
           -target MoaiyCLI \
           -configuration Release \
           build
```

## Companion CLI (`moaiy-cli`)

```bash
moaiy-cli status
moaiy-cli list-keys --secret
moaiy-cli encrypt --recipient <FINGERPRINT_OR_EMAIL> --input secret.txt --output secret.txt.gpg --armor
moaiy-cli decrypt --input secret.txt.gpg --output secret.txt
```

## Package DMG

Use one command to build and package a timestamped DMG:

```bash
./scripts/package_dmg.sh
```

Or run the full dual-architecture (`arm64` + `x86_64`) release orchestrator:

```bash
./scripts/release/run_release.sh --version 1.0.0 --mode draft --signing auto --gate balanced
```

Useful standalone options:

```bash
./scripts/package_dmg.sh --configuration Release --arch arm64 --version 1.0.0 --artifact-name Moaiy-1.0.0-macos-apple-silicon.dmg
./scripts/package_dmg.sh --configuration Release --arch x86_64 --version 1.0.0 --artifact-name Moaiy-1.0.0-macos-intel-chip.dmg
./scripts/package_dmg.sh --skip-build --open
```

## Run Tests

```bash
# Run full Xcode unit & integration test suite (451 tests)
xcodebuild test -project Moaiy/Moaiy.xcodeproj \
                -scheme MoaiyTests \
                -destination 'platform=macOS,arch=arm64'

# Or run the full 5-stage loop verification harness (SwiftLint + CLI + 64MB streaming + MoaiyTests)
bash scripts/loop-runner.sh
```

## Bundled GPG Workflow

If you need to refresh the embedded GPG bundle:

```bash
./scripts/prepare_gpg_bundle.sh
./scripts/verify_gpg_bundle.sh
```

If the bundle is not added in Xcode, use:

```bash
./scripts/add_gpg_bundle_to_xcode.sh
```

## Repository Layout

```text
moaiy/
├── Moaiy/                  # Main macOS SwiftUI app & MoaiyTests suite
├── MoaiyCLI/               # Standalone moaiy-cli companion tool
├── MoaiySandboxTest/       # Sandbox validation app/project
├── specs/                  # v1.0 work-package engineering specifications
├── scripts/                # Build, verification, and DMG release scripts
├── doc/                    # Technical and release documentation
├── CONTRIBUTING.md
├── DISCLAIMER.md
├── README_CN.md
└── LICENSE
```

## Documentation

- [Contributing Guide](./CONTRIBUTING.md)
- [Documentation Index](./doc/README.md)
- [v1.0.0 Release Validation Summary](./doc/v1.0.0-release-validation-summary.md)
- [v1.0.0 Comprehensive Test Plan](./doc/v1.0.0-comprehensive-test-plan.md)
- [v1.0.0 Release Notes](./doc/v1.0.0-release-notes.md)
- [Release Workflow Guide](./doc/release-workflow-skill.md)
- [Technical Architecture](./doc/technical-architecture.md)
- [Technical Validation Status](./doc/technical-validation-status.md)
- [Xcode Integration Guide](./doc/xcode-integration-guide.md)
- [Bundled GPG Summary](./doc/bundled-gpg-summary.md)
- [Changelog](./CHANGELOG.md)

## Localization

- UI: English, Chinese (Simplified), Spanish, Portuguese (Brazil), Hindi, Arabic, French, German, Japanese, Korean, Russian
- String catalog: `Moaiy/Resources/Localizable.xcstrings`

## Security

If you discover a security issue, use private disclosure channels described in
[SECURITY.md](./SECURITY.md) instead of filing a public issue.

## License

MIT. See [LICENSE](./LICENSE).

## Disclaimer

For key-management, key-leakage, information-exposure, and financial-loss risk boundaries, see [DISCLAIMER.md](./DISCLAIMER.md).
