# Work Package 1: Streaming I/O & Pipe Deadlock Elimination (v1.0 Spec)

## 1. Objective
Refactor the file encryption and decryption pipeline to support chunked streaming I/O using Swift Concurrency (`AsyncStream<Data>`). Eliminate blocking pipe reads that risk deadlock during large file transfers (>64KB / >10GB), maintaining peak memory usage strictly below 50MB RSS.

## 2. Invariants & Requirements
1. **Bounded Memory**: Memory consumption must stay constant (<50MB) regardless of file size.
2. **Asynchronous Pipe Consumption**: Standard Output and Standard Error from external processes (`Process`) must be read concurrently via asynchronous file handles or streams.
3. **Progress Reporting**: Real-time progress updates (bytes processed / total bytes) with throttled UI emission (max 10Hz) to prevent main thread rendering lag.
4. **Cancellation Safety**: When a user cancels the operation, the underlying `Process` must receive `terminate()`, and all intermediate open file handles must be cleanly closed.
5. **Sandbox Compliance**: All file access must be protected by paired `startAccessingSecurityScopedResource()` and `defer { stopAccessingSecurityScopedResource() }`.

## 3. Architecture Blueprint
- **Component**: `StreamingCryptoPipeline`
- **Protocols**:
  - `CryptoStreamProvider`: Exposes `func streamEncrypt(input: URL, output: URL, progress: @escaping (Double) -> Void) async throws`
  - `AsyncChunkReader`: Reads chunks of adaptive size (256KB to 1MB) from `FileHandle`.
- **Data Flow**:
  `Input FileHandle` -> `Chunking Stream` -> `Process stdin Pipe` -> `Crypto Process (GPG/Age)` -> `Process stdout Pipe` -> `Output FileHandle (Atomic Temp File)`

## 4. Acceptance Criteria
- [ ] 5GB dummy test file can be encrypted and decrypted without memory spike (>50MB RSS).
- [ ] SIGINT / Task cancellation terminates child processes within 500ms and cleans temporary files.
- [ ] Unit tests pass with 100% success rate on `MoaiyTests`.
- [ ] Sandbox tests pass with zero access entitlement errors on `MoaiySandboxTest`.
