import Foundation
import Testing
@testable import Moaiy

@Suite("Pro Contracts Tests")
struct ProContractsTests {

    @Test("Noop entitlement provider always returns locked availability")
    func noopProvider_returnsLockedAvailability() async {
        let provider = NoopEntitlementProvider()
        await provider.refresh()

        let availability = await provider.availability(for: .hardwareKeyAdvanced)
        #expect(!availability.isEnabled)
        #expect(availability.source == .none)
    }

    @Test("Noop Pro module rejects execution")
    func noopModule_rejectsExecution() async {
        let module = NoopProModule()

        do {
            _ = try await module.execute(
                actionID: ProActionDescriptor.hardwareKeyAdvanced.id,
                context: ProActionContext(keyFingerprint: "FINGERPRINT")
            )
            Issue.record("Expected unsupported action failure")
        } catch ProModuleExecutionError.unsupportedAction {
            #expect(true)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("Pro module factory exposes hardware advanced descriptor")
    func moduleFactory_exposesHardwareActionDescriptor() {
        let module = ProModuleFactory.makeModule()
        let actionIDs = Set(module.menuDescriptors.map(\.id))
        #expect(actionIDs.contains(ProActionDescriptor.hardwareKeyAdvanced.id))
    }

    @Test("Pro module factory settings descriptors cover all known features")
    func moduleFactory_settingsDescriptorsCoverAllFeatures() {
        let module = ProModuleFactory.makeModule()
        let features = Set(module.settingsDescriptors.map(\.feature))
        #expect(features == Set(ProFeature.allCases))
    }

    @Test("StoreKit mapping resolves entitled product IDs to enabled features")
    func storeKitMapping_resolvesEnabledFeatures() {
        let entitledProductIDs: Set<String> = [
            "com.moaiy.pro.hardware_key_advanced",
            "com.moaiy.pro.batch_governance"
        ]

        let enabled = StoreKit2EntitlementProvider.resolveEnabledFeatures(
            entitledProductIDs: entitledProductIDs,
            mapping: Constants.Pro.productToFeatureMap
        )

        #expect(enabled.contains(.hardwareKeyAdvanced))
        #expect(enabled.contains(.batchGovernance))
        #expect(!enabled.contains(.auditExport))
    }

    @Test("Pro product manifest maps features one-to-one")
    func proProductManifest_isOneToOne() {
        #expect(Constants.Pro.featureToProductID.count == ProFeature.allCases.count)
        #expect(
            Set(Constants.Pro.featureToProductID.values).count
                == Constants.Pro.featureToProductID.count
        )
    }

    @Test("Pro contracts semantic version follows major.minor.patch")
    func proContractsSemanticVersion_isValidSemver() {
        let segments = Constants.Pro.contractsSemanticVersion.split(separator: ".")
        #expect(segments.count == 3)
        #expect(segments.allSatisfy { Int($0) != nil })
    }

    @Test("Runtime entitlement transitions cover purchase restore and revocation")
    @MainActor
    func runtimeTransitions_purchaseRestoreRevocation() async throws {
        let provider = MockProEntitlementProvider()
        let runtime = ProRuntime(
            entitlementProvider: provider,
            module: NoopProModule()
        )

        await runtime.refreshEntitlements()
        #expect(!runtime.isEnabled(.hardwareKeyAdvanced))

        await provider.setEnabledFeatures([.hardwareKeyAdvanced])
        await runtime.refreshEntitlements()
        #expect(runtime.isEnabled(.hardwareKeyAdvanced))

        await provider.setEnabledFeatures([])
        await runtime.refreshEntitlements()
        #expect(!runtime.isEnabled(.hardwareKeyAdvanced))

        await provider.setRestorableFeatures([.hardwareKeyAdvanced])
        try await runtime.restorePurchases()
        #expect(runtime.isEnabled(.hardwareKeyAdvanced))
    }
}

actor MockProEntitlementProvider: ProEntitlementProvider {
    private var enabledFeatures: Set<ProFeature> = []
    private var restorableFeatures: Set<ProFeature> = []

    func setEnabledFeatures(_ features: Set<ProFeature>) {
        enabledFeatures = features
    }

    func setRestorableFeatures(_ features: Set<ProFeature>) {
        restorableFeatures = features
    }

    func refresh() async {}

    func availability(for feature: ProFeature) async -> ProFeatureAvailability {
        if enabledFeatures.contains(feature) {
            return .enabled(source: .storekit)
        }

        return .locked(
            reasonCode: .notPurchased,
            source: .storekit,
            messageKey: "pro_status_locked_message_purchase"
        )
    }

    func restorePurchases() async throws {
        enabledFeatures = restorableFeatures
    }
}
