# Export Compliance Preparation

This file is a pre-submission template for App Store Connect encryption compliance.

## Product Summary

- App: `Moaiy`
- Platform: macOS
- Bundle identifier: `com.moaiy.app`
- Primary crypto function: OpenPGP key management and encryption/decryption workflows.

## Encryption Details

- Implementation: bundled `gpg` binaries inside `gpg.bundle`.
- Typical algorithms used by OpenPGP/GnuPG include RSA, ECC (EdDSA/ECDH), symmetric encryption, and hashing.
- Usage scope: local file/text encryption, decryption, key generation, key import/export, key signing and trust operations.
- User data flow: cryptographic operations are local-first; optional network is used for keyserver lookup/upload.

## App Store Connect Checklist (when account is ready)

1. Complete the export compliance questionnaire for the app version.
2. Confirm whether supporting documentation is required for your selected distribution countries/regions.
3. If App Store Connect returns an export compliance code, record it and update Info.plist key:
   - `ITSEncryptionExportComplianceCode`
4. If App Store Connect flow requires, set:
   - `ITSAppUsesNonExemptEncryption`

## Operational Notes

- Keep this file synchronized with actual cryptographic capabilities in `GPGService`.
- Re-check compliance answers if algorithms, keyserver behavior, or crypto libraries change.
