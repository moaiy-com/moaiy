# Moaiy Pro Open Core Contracts v1

Status: Draft v1 (implemented in Core repository)  
Last Updated: 2026-04-18

## 1. Repository Split

- Public repo `moaiy` (this repository):
  - Free/Core feature set
  - Main app shell and all shared UI flows
  - Stable Pro contracts surface
  - StoreKit 2 entitlement provider
  - `NoopProModule` and `NoopEntitlementProvider` fallbacks
- Private repo `moaiy-pro-private`:
  - Pro feature implementation
  - Pro UI internals
  - Signed `MoaiyProKit.xcframework` artifacts

## 2. Contract Versioning

- Contract semantic version is tracked by:
  - `Constants.Pro.contractsSemanticVersion`
- Current value: `1.0.0`
- Rule:
  - Breaking contract change -> major bump
  - Backward-compatible extension -> minor bump
  - Non-contract internal change -> patch bump

## 3. Stable Core Contracts

Defined in Core and consumed by both Core + Pro implementation:

```swift
enum ProFeature {
    case hardwareKeyAdvanced
    case batchGovernance
    case auditExport
    case teamPolicyTemplates
}

struct ProFeatureAvailability {
    let isEnabled: Bool
    let reasonCode: ProAvailabilityReason
    let messageKey: String
    let source: ProAvailabilitySource // storekit/direct/none
}

protocol ProEntitlementProvider {
    func refresh() async
    func availability(for feature: ProFeature) async -> ProFeatureAvailability
    func restorePurchases() async throws
}

protocol ProModule {
    var menuDescriptors: [ProActionDescriptor] { get }
    var settingsDescriptors: [ProSettingsDescriptor] { get }
    func execute(actionID: String, context: ProActionContext) async throws -> ProActionExecutionResult
}
```

### Fallback Contract

- `NoopProModule`:
  - Exposes descriptors for locked Pro entries.
  - Rejects execution with `unsupportedAction`.
- `NoopEntitlementProvider`:
  - Always returns locked availability.
  - Keeps Core build and runtime healthy without Pro binaries.

## 4. Product Manifest Mapping

Feature-to-product mapping is declared in Core:

- `hardwareKeyAdvanced` -> `com.moaiy.pro.hardware_key_advanced`
- `batchGovernance` -> `com.moaiy.pro.batch_governance`
- `auditExport` -> `com.moaiy.pro.audit_export`
- `teamPolicyTemplates` -> `com.moaiy.pro.team_policy_templates`

Invariants:

- One feature maps to exactly one product ID.
- Product IDs are unique.
- Mapping coverage equals `ProFeature.allCases`.

## 5. Runtime Integration Rules

- Core never directly imports Pro private view types.
- Core gates all Pro execution by entitlement state before action dispatch.
- Core module bootstrap path:
  - `ProModuleFactory.makeModule()` is the single entry.
  - If `MoaiyProKit` is importable, Core uses a binary adapter (`ProBinaryModuleAdapter`) to map
    private contract types into Core contract types.
  - If `MoaiyProKit` is absent, Core falls back to `NoopProModule` automatically.
- App lifecycle refresh points:
  - App launch task
  - Foreground activation
  - `Transaction.updates` stream listener
- Refund/revocation is reflected by StoreKit entitlement refresh and gate re-evaluation.

## 6. Distribution Modes

- App Store mode (default):
  - `StoreKit2EntitlementProvider` is the active provider.
  - Restore flow calls `AppStore.sync()`.
- Non-App Store mode (reserved):
  - `DirectLicenseEntitlementProvider` remains a contract placeholder.
  - Not enabled by default.

## 6.1 Private Artifact Pipeline (`moaiy-pro`)

- Private repo release workflow:
  - `.github/workflows/release-xcframework.yml`
- Generated release assets:
  - `MoaiyProKit.xcframework.zip`
  - `MoaiyProKit.xcframework.zip.sha256`
  - generated notes file (`release-notes.md`)
- Tag format:
  - `pro-vX.Y.Z`
- Notes rendering script:
  - `scripts/render_release_notes.sh`
- Core internal injection workflow consumes this artifact as the Pro binary source.

## 7. Test and CI Expectations

- Public CI:
  - Must pass with no private Pro binary injected.
  - `Noop` fallback path must remain green.
  - `scripts/check_pro_contracts.py` must pass.
- Internal CI:
  - Runs with Pro binary injected.
  - Workflow: `.github/workflows/internal-pro-injection-ci.yml`.
  - Required secrets:
    - `MOAIY_PRO_XCFRAMEWORK_URL`
    - `MOAIY_PRO_XCFRAMEWORK_TOKEN` (if artifact URL requires auth)
    - `MOAIY_PRO_XCFRAMEWORK_SHA256` (recommended)
  - Covers entitlement transitions and Pro action execution.
  - Verifies adapter path (`ProBinaryModuleAdapter`) and descriptor mapping.
- Contract tests include:
  - Noop provider behavior
  - Noop module rejection behavior
  - Module factory descriptor exposure and settings coverage
  - StoreKit mapping resolution
  - Manifest one-to-one mapping
  - Contract semver format
  - Runtime entitlement transition states

## 8. HardwareKeyAdvanced v1 (Current Pro Baseline)

- Diagnostics flow in `moaiy-pro`:
  - `gpg --version` (runtime availability)
  - optional fingerprint precheck:
    - `gpg --batch --with-colons --list-secret-keys -- <fingerprint>`
  - `gpg --card-status` (hardware card readiness)
- Failure outcomes map to existing Core-localized keys:
  - `error_smartcard_unavailable_recovery`
  - `error_key_not_found_recovery`
  - `error_smartcard_not_present_recovery`
  - fallback: `pro_action_module_unavailable_message`
- Goal:
  - Keep Pro diagnostics actionable without introducing locale regressions.
