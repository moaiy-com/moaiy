# Work Package 4: CLI Companion Tool (v1.0 Spec)

## 1. Objective
Build a native, lightweight companion command-line interface (`moaiy-cli`) that aligns with GUI core capabilities. Enable developers and automation workflows to list keys, check system readiness, and perform streaming file encryption and decryption directly from terminal or CI/CD pipelines.

## 2. Invariants & Requirements
1. **Shared Keyring & Configuration**: Must seamlessly discover and operate against the app-managed GPG keyring and system environment without requiring separate key imports.
2. **Streaming Execution**: File encryption and decryption commands must leverage chunked streaming I/O (`StreamingCryptoPipeline` / `AtomicFileUtility`) to keep memory footprint bounded.
3. **Machine-Readable Outputs**: Support `--json` flag on discovery commands (`list-keys`, `status`) for programmatic consumption in scripts.
4. **POSIX Exit Codes**: Standard zero on success, non-zero with informative stderr output on failure.

## 3. Command Surface
- `moaiy-cli status [--json]`: Checks cryptographic engine health, version, and PQC/Kyber capability.
- `moaiy-cli list-keys [--secret] [--json]`: Lists available public or secret keys.
- `moaiy-cli encrypt --recipient <keyID> [--output <dest>] <file>`: Encrypts file with specified recipient.
- `moaiy-cli decrypt [--output <dest>] <file>`: Decrypts specified file.

## 4. Acceptance Criteria
- [ ] `moaiy-cli --help` outputs comprehensive usage synopsis.
- [ ] Status command reports engine version and Kyber capability.
- [ ] Standalone buildable via Swift compiler.
- [ ] Automated regression tests verify CLI execution.
