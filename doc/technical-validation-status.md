# Moaiy Technical Validation Status

> Scope: Runtime, streaming crypto pipeline, Keychain integration, sandbox behavior, packaging, and release-critical workflows
> Updated: 2026-10-17

## 1. Validation Summary

| Area | Status | Notes |
| --- | --- | --- |
| Core GPG command execution (`gpg.bundle` 2.5.21) | Complete | Bundled runtime path & Kyber-768 hybrid PQC validated |
| Streaming crypto pipeline (`StreamingCryptoPipeline`) | Complete | 64MB stream verified (<32MB Peak RSS delta, 8MB backpressure cap) |
| Overwrite-safe staging (`commitStagedFile`) | Complete | `statfs` net-space preflight, `O_WRONLY` pre-check & zero-scrubbed rollback backup |
| Keychain & Touch ID (`KeychainService`) | Complete | Data Protection Keychain + `#if DEBUG` isolated legacy fallback verified |
| Companion CLI (`moaiy`) | Complete | Standalone `MoaiyCLI` target (`status`, `list-keys`, `encrypt`, `decrypt`) validated |
| Full `MoaiyTests` suite (`xcodebuild test`) | Complete | **451/451 tests in 38 suites passed** (`TEST SUCCEEDED`) with isolated `GNUPGHOME` |
| App Store-specific submission loop | Pending | Compliance track prepared; active distribution track is GitHub Releases |

## 2. Completed Validation Tracks

## 2.1 Streaming Pipeline, Staging & Memory Hygiene (v1.0.0)
- 256KB chunked I/O with independent `stdinQueue`/`stdoutQueue` and 8MB backpressure throttling.
- Per-chunk `autoreleasepool` drainage keeping 64MB streaming Peak RSS delta at ~9.8–10.3MB (<32MB threshold).
- Isolated `0600` passphrase token file creation and zero-scrubbing before `unlink`.
- `commitStagedFile` in-place overwrite preserving `NSSavePanel` sandbox security scope and target inode, with rollback backup (`original.bak`) zero-scrubbed via `zeroScrubDirectoryContents`.
- `SecureMemory` (`memset_s`) and `TransientFileRegistry` (`willTerminateNotification` + 24h stale cleanup) verified.

## 2.2 Keychain & Single-Pass Key Resolution (v1.0.0)
- `KeychainService` verified across Data Protection Keychain and compile-time `#if DEBUG` fallback paths.
- `GPGService.resolvePrimaryFingerprint` resolves 8-char short IDs, 16-char long IDs, primary fingerprints, and subkey fingerprints in a single `--list-secret-keys --with-colons` call, throwing typed `GPGError.ambiguousKeyReference` on collisions.

## 2.3 Bundled Runtime & Post-Quantum Hybrid Keys (v0.9.0 – v1.0.0)
- Embedded GnuPG 2.5.21 runtime (`gpg.bundle`) validated for classical (ECC, RSA-4096, RSA-2048) and Kyber-768 hybrid OpenPGP keys.
- Full `MoaiyTests` suite (451 tests across 38 suites) uses isolated temporary `GNUPGHOME` directories (`0700`) and terminates temporary `gpg-agent` daemons via `gpgconf --kill gpg-agent` on teardown.

## 3. Open / Ongoing Items

## 3.1 App Store submission readiness loop
- Compliance documents and sandbox strategy exist.
- End-to-end App Store review cycle remains pending execution.

## 3.2 Physical Touch ID & 50GB endurance benchmark
- Interactive physical Touch ID hardware prompt and multi-hour 50GB file endurance benchmark remain manual pre-release checks on physical hardware.

## 4. Evidence Sources

Primary references in repository:
- `doc/v1.0.0-release-validation-summary.md`
- `doc/v1.0.0-comprehensive-test-plan.md`
- `doc/v1.0.0-release-notes.md`
- `doc/v0.9.0-pqc-technical-validation-report.md`
- `CHANGELOG.md`

---

This file tracks operational validation status. Update it whenever release quality gates or runtime behavior materially change.
