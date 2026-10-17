# Work Package 1: Streaming I/O & Pipe Deadlock Elimination (v1.0 Spec)

## 1. Objective
Refactor the file encryption and decryption pipeline to support chunked streaming I/O with asynchronous pipe draining. Eliminate blocking pipe reads that risk deadlock during large file transfers (>64KB), maintaining peak memory usage bounded via 256KB chunking.

## 2. Invariants & Requirements
1. **Bounded Memory**: Memory consumption kept bounded via 256KB chunked I/O, per-chunk `autoreleasepool` drainage, and dual-queue backpressure (`maxInFlightOutputBytes = 8 MB`, Peak RSS delta `< 32 MB` on 64MB streams).
2. **Asynchronous Non-blocking Pipe Consumption**: Standard Output and Standard Error from external processes (`Process`) must be consumed concurrently via non-blocking `readabilityHandler` and dedicated background queues, unregistering handlers immediately upon EOF.
3. **Passphrase Stream Isolation**: Passphrases must NEVER be prepended to the data stream on standard input. When needed, passphrases must be passed via isolated loopback passphrase files with strict `0o600` permissions.
4. **EOF & Output Synchronization**: The pipeline must wait for both child process exit AND standard output pipe EOF, and drain the disk writing queue completely before committing output.
5. **Progress Reporting**: Real-time progress updates with throttled UI emission (10Hz) to prevent main thread rendering lag.
6. **Cancellation & Error Safety**: When a user cancels the operation or child exits early, the underlying `Process` is terminated, all intermediate open file handles are closed, and temporary staging directories are cleaned up.
7. **Sandbox Compliance & Known Overwrite Limitations (`commitStagedFile`)**:
   - Temporary staging files reside strictly within app-managed container directories (`SecureTempStorage`), and user-chosen destinations are written in-place (`open(O_WRONLY)` preflight + `ftruncate` + stream write + `fsync`) to preserve the target inode and macOS App Sandbox `NSSavePanel` security-scoped access.
   - **Known Limitation 1 (Non-Atomic In-Place Write on Process Crash)**: Because `commitStagedFile` overwrites the existing file in-place rather than performing a POSIX atomic `rename` in the destination's parent directory (which App Sandbox denies without directory-level permission), an abnormal process crash (`SIGKILL` or power loss) mid-write can leave the destination file truncated. A rollback backup (`original.bak`) is created inside `SecureTempStorage` before truncation and retained for up to 24 hours (`staleTTL`) until startup cleanup.
   - **Known Limitation 2 (Rollback Backup Plaintext Copy & Storage Media Limits)**: When overwriting an existing plaintext file, `original.bak` is a temporary plaintext copy on disk. `SecureTempStorage.removeOperationDirectory` best-effort zero-overwrites (`zeroScrubDirectoryContents` + `fsync`) regular files before unlinking on normal completion or rollback; however, on copy-on-write filesystems (APFS) and wear-leveled SSDs, physical flash blocks cannot be guaranteed erased at the user-space filesystem layer.

## 3. Architecture Blueprint
- **Component**: `StreamingCryptoPipeline`
- **Component**: `StreamingProgressReporter`
- **Data Flow**:
  `Input FileHandle` -> `Chunking Background Stream` -> `Process stdin Pipe` -> `GPG Process` -> `Process stdout Pipe (readabilityHandler)` -> `Sandboxed Staged Output` -> `Destination Overwrite`

## 4. Acceptance Criteria
- [x] End-to-end data pass-through verified with 64MB multi-chunk payloads (<32MB Peak RSS delta).
- [x] Child process early exit and read errors propagate safely without corrupting destination.
- [x] Passphrase isolation verified without leaking credentials into ciphertext.
- [ ] Large-file continuous load benchmark (50GB) executed on local test hardware.
