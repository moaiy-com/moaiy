# Review Guidelines

For human and AI reviewers of Moaiy pull requests. Keep reviews focused on what can actually hurt users.

## What counts as a failure
- **Crypto correctness**: wrong recipient/signer, silent fallback to weaker algorithms, unverified signatures treated as valid, truncated or corrupted encrypt/decrypt output.
- **Secret leakage**: keys, passphrases or plaintext in logs, temp files, crash reports, pasteboard, or memory that is not wiped (`SecureMemory`, `TransientFileRegistry`).
- **Misrouted config**: wrong `GNUPGHOME`, gpg binary, agent/scdaemon path, or keychain item.
- **Broken signing / sandbox**: unsigned or mis-signed embedded binaries, entitlement changes that widen or break the sandbox.
- **Docs that lie**: README/CHANGELOG/help text that no longer matches behavior.

## Sensitive paths — always require owner (@tau-gast) human review
- `Moaiy/Services/GPGService.swift`, `Moaiy/Services/StreamingCryptoPipeline.swift`, `Moaiy/Services/KeychainService.swift`, `Moaiy/Services/SecureMemory.swift`, `Moaiy/Services/TransientFileRegistry.swift`
- `Moaiy/Resources/gpg.bundle/**` (embedded GnuPG)
- `scripts/sign_embedded_gpg_bundle.sh`, `scripts/prepare_gpg_bundle.sh`, `scripts/verify_gpg_bundle.sh`, `scripts/package_dmg.sh`, `scripts/release/**`
- `Moaiy/Resources/Entitlements.entitlements`, `Moaiy/Resources/GPGHelper.entitlements`, `MoaiySandboxTest/MoaiySandboxTest/Entitlements.entitlements`
- `.github/workflows/**`, `.github/CODEOWNERS`
- `Moaiy/Moaiy.xcodeproj/project.pbxproj` (signing settings), `Moaiy/Config/*.xcconfig` (signing, version)
- `CHANGELOG.md`, `LICENSE`, `THIRD_PARTY_NOTICES.md`, `SECURITY.md`

AI review may comment on these but never counts as approval.

## Reporting rules
- Start with a summary: number of findings by severity. If clean, say **"No issues found."** explicitly.
- Every finding cites `file:line` and explains the impact.
- Label each finding:
  - **Important** — must fix before merge (failures above, bugs, missing tests for risky logic).
  - **Nit** — optional; keep to a handful, skip pure style already covered by tooling.
  - **Pre-existing** — real issue not introduced by this PR; do not block on it.
- Report the bug *class* ("all callers of X ignore exit status"), not just one line.

## Ignored paths
Generated files, `DerivedData/`, `build/`, `dist/`, `*.xcuserstate`, and binary contents of `Moaiy/Resources/gpg.bundle/` (review `manifest.json` and scripts instead).

## Review rounds
- At most **3** review cycles per PR.
- After round 1, review only the new diff; do not re-report known or accepted issues.
- If still blocked after round 3, escalate to the owner instead of another round.

## Evidence required in the PR
- Tests: `xcodebuild test -project Moaiy/Moaiy.xcodeproj -scheme MoaiyTests -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO` (Swift Testing suite) — paste the result.
- Build result for the `Moaiy` scheme.
- `scripts/verify_gpg_bundle.sh` output when `gpg.bundle` or bundle scripts change.
- DMG SHA-256 checksum when packaging/release scripts change.
