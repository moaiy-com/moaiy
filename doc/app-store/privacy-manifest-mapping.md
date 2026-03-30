# Privacy Manifest Mapping

This document tracks Required Reason API usage for `Moaiy`.

## Current Mapping

| API Category | Reason | Why It Is Used | Code Locations |
| --- | --- | --- | --- |
| `NSPrivacyAccessedAPICategoryUserDefaults` | `CA92.1` | Persist user preferences and non-sensitive app state such as history and reminder settings. | `Moaiy/Services/ExpirationReminderService.swift`, `Moaiy/ViewModels/EncryptionViewModel.swift`, `Moaiy/Services/FileBookmarkManager.swift`, `Moaiy/Views/Backup/BackupManagerView.swift`, `Moaiy/ViewModels/KeyManagementViewModel.swift` |

## Manifest File

- File path: `Moaiy/PrivacyInfo.xcprivacy`
- Added to `Moaiy` target resources.

## Maintenance Checklist

1. If a new Required Reason API category appears, update `Moaiy/PrivacyInfo.xcprivacy`.
2. Keep this mapping aligned with concrete call sites.
3. Re-run App Store validation before submission.
