# Work Package 4: CLI Companion Tool (v1.0 Spec)

## 1. Objective
Build a native, lightweight companion command-line interface (`moaiy-cli`) that aligns with desktop client capabilities. Enable developers and automation workflows to check backend readiness, list keys, and execute file encryption and decryption directly from the terminal or CI/CD pipelines.

## 2. Invariants & Requirements
1. **Shared Keyring & Configuration**: Discovers the Moaiy sandboxed container keyring (`~/Library/Containers/com.moaiy.app/Data/Library/gnupg`), standard `~/Library/gnupg`, and system `~/.gnupg`, while supporting custom `--gpg-home`.
2. **Non-blocking Pipe Draining**: All process execution (`runProcessSafe`) must drain standard output and standard error concurrently on background queues to prevent pipe buffer deadlocks on payloads >64KB.
3. **Subcommand Parity**: Implements `status`, `list-keys` (with `--secret`), `encrypt`, and `decrypt`.
4. **Machine-Readable Outputs**: Supports `--json` flag on discovery commands (`status`, `list-keys`).
5. **Clear Operational Notes**: Documents `--batch` and `--yes` overwrite behaviors and gpg-agent passphrase caching requirements in `--help`.

## 3. Command Surface
- `moaiy-cli status [--json] [--gpg-home <path>]`
- `moaiy-cli list-keys [--secret] [--json] [--gpg-home <path>]`
- `moaiy-cli encrypt <file> -r <recipient> [-o <dest>] [--armor] [--gpg-home <path>]`
- `moaiy-cli decrypt <file> [-o <dest>] [--gpg-home <path>]`

## 4. Acceptance Criteria
- [x] Subcommands (`status`, `list-keys`, `encrypt`, `decrypt`) implemented and syntax verified.
- [x] Concurrent pipe draining prevents deadlocks.
- [x] Automated GNUPGHOME resolution chains container and system homes.
- [x] Standalone compilable via `swiftc`.
