## Summary
<!-- What and why, 1–3 sentences. -->

## Changes
-

## Testing
<!-- Commands run and results. See REVIEW.md "Evidence required". -->
- [ ] `xcodebuild test -project Moaiy/Moaiy.xcodeproj -scheme MoaiyTests -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO` →
- [ ] Build (`Moaiy` scheme) →
- [ ] `scripts/verify_gpg_bundle.sh` (if gpg.bundle touched) →
- [ ] DMG SHA-256 (if packaging) →

## Risk
Level: low / medium / high

Sensitive paths touched (require owner review, see REVIEW.md):
- [ ] GPG / crypto services (`Moaiy/Services/GPGService.swift`, `StreamingCryptoPipeline.swift`, keychain/secure memory)
- [ ] `Moaiy/Resources/gpg.bundle/**`
- [ ] Signing / packaging / release scripts (`scripts/*gpg_bundle*.sh`, `scripts/package_dmg.sh`, `scripts/release/**`)
- [ ] Entitlements
- [ ] `.github/workflows/**`
- [ ] Xcode signing settings / `Moaiy/Config/*.xcconfig` / version
- [ ] Licensing (`LICENSE`, `THIRD_PARTY_NOTICES.md`)
- [ ] None

## How to revert
<!-- e.g. `git revert <sha>`; any data/config migration to undo. -->

## Screenshots
<!-- UI changes only. -->
