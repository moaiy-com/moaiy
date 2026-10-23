# Export Compliance Preparation

This file is a pre-submission template for App Store Connect encryption compliance.

## Product Summary

- App: `Moaiy`
- Platform: macOS (`arm64`)
- Bundle identifier: `com.moaiy.app`
- Primary crypto function: OpenPGP key management and encryption/decryption workflows.

## Encryption Details

- Implementation: bundled `gpg` binaries inside `gpg.bundle` (`GnuPG 2.5.21`).
- Typical algorithms used by OpenPGP/GnuPG include RSA, ECC (EdDSA/ECDH), Kyber-768 hybrid OpenPGP, symmetric encryption (AES-256), and hashing (SHA-256/SHA-512).
- Usage scope: local file/text encryption, decryption, key generation, key import/export, key signing and trust operations.
- User data flow: cryptographic operations are local-first; optional network is used for keyserver lookup/upload.

## Info.plist Configuration

- `ITSAppUsesNonExemptEncryption` is set to `<true/>` in `Moaiy/Info.plist`.
- Once the annual self-classification / CCATS encryption approval is accepted in App Store Connect, add the issued `ITSEncryptionExportComplianceCode` string to `Moaiy/Info.plist`.

## App Store Connect Checklist (when account is ready)

1. Complete the export compliance questionnaire for the app version.
2. Confirm whether supporting documentation is required for your selected distribution countries/regions.
3. When App Store Connect returns an export compliance code, record it and update `Moaiy/Info.plist`:
   - `ITSEncryptionExportComplianceCode`

## Operational Notes

- Keep this file synchronized with actual cryptographic capabilities in `GPGService`.
- Re-check compliance answers if algorithms, keyserver behavior, or crypto libraries change.
