//
//  AppState.swift
//  Moaiy
//
//  Shared application state and Pro contracts.
//

import Foundation
import StoreKit

enum ProFeature: String, CaseIterable, Identifiable, Sendable {
    case hardwareKeyAdvanced
    case batchGovernance
    case auditExport
    case teamPolicyTemplates

    var id: String { rawValue }

    var settingsDisplayKey: String {
        switch self {
        case .hardwareKeyAdvanced:
            return "pro_feature_hardware_key_advanced_title"
        case .batchGovernance:
            return "pro_feature_batch_governance_title"
        case .auditExport:
            return "pro_feature_audit_export_title"
        case .teamPolicyTemplates:
            return "pro_feature_team_policy_templates_title"
        }
    }
}

enum ProAvailabilitySource: String, Sendable {
    case storekit
    case direct
    case none

    var displayKey: String {
        switch self {
        case .storekit:
            return "pro_source_storekit"
        case .direct:
            return "pro_source_direct"
        case .none:
            return "pro_source_none"
        }
    }
}

enum ProAvailabilityReason: String, Sendable {
    case enabled
    case notPurchased
    case revokedOrExpired
    case providerUnavailable
    case moduleUnavailable
    case productMappingMissing
}

struct ProFeatureAvailability: Sendable, Hashable {
    let isEnabled: Bool
    let reasonCode: ProAvailabilityReason
    let messageKey: String
    let source: ProAvailabilitySource

    static func enabled(source: ProAvailabilitySource) -> ProFeatureAvailability {
        ProFeatureAvailability(
            isEnabled: true,
            reasonCode: .enabled,
            messageKey: "pro_status_enabled_message",
            source: source
        )
    }

    static func locked(
        reasonCode: ProAvailabilityReason,
        source: ProAvailabilitySource,
        messageKey: String = "pro_status_locked_message_purchase"
    ) -> ProFeatureAvailability {
        ProFeatureAvailability(
            isEnabled: false,
            reasonCode: reasonCode,
            messageKey: messageKey,
            source: source
        )
    }

    var statusDisplayKey: String {
        isEnabled ? "pro_status_enabled" : "pro_status_locked"
    }
}

protocol ProEntitlementProvider: Sendable {
    func refresh() async
    func availability(for feature: ProFeature) async -> ProFeatureAvailability
    func restorePurchases() async throws
}

struct ProActionDescriptor: Sendable, Hashable, Identifiable {
    let id: String
    let feature: ProFeature
    let titleKey: String
    let systemImage: String
}

struct ProSettingsDescriptor: Sendable, Hashable, Identifiable {
    let id: String
    let feature: ProFeature
    let titleKey: String
}

struct ProActionContext: Sendable {
    let keyFingerprint: String?
}

struct ProActionExecutionResult: Sendable, Hashable {
    let titleKey: String
    let messageKey: String
}

enum ProModuleExecutionError: Error, LocalizedError {
    case unsupportedAction(String)
    case featureLocked(ProFeature)

    var errorDescription: String? {
        switch self {
        case .unsupportedAction(let actionID):
            return "Unsupported Pro action: \(actionID)"
        case .featureLocked(let feature):
            return "Pro feature is locked: \(feature.rawValue)"
        }
    }
}

protocol ProModule: Sendable {
    var menuDescriptors: [ProActionDescriptor] { get }
    var settingsDescriptors: [ProSettingsDescriptor] { get }
    func execute(actionID: String, context: ProActionContext) async throws -> ProActionExecutionResult
}

extension ProActionDescriptor {
    static let hardwareKeyAdvanced = ProActionDescriptor(
        id: "hardware-key-advanced",
        feature: .hardwareKeyAdvanced,
        titleKey: "action_pro_hardware_key_advanced",
        systemImage: "creditcard.and.123"
    )
}

struct NoopProModule: ProModule {
    let menuDescriptors: [ProActionDescriptor] = [.hardwareKeyAdvanced]
    let settingsDescriptors: [ProSettingsDescriptor] = ProFeature.allCases.map {
        ProSettingsDescriptor(
            id: "settings-\($0.rawValue)",
            feature: $0,
            titleKey: $0.settingsDisplayKey
        )
    }

    func execute(actionID: String, context: ProActionContext) async throws -> ProActionExecutionResult {
        throw ProModuleExecutionError.unsupportedAction(actionID)
    }
}

actor NoopEntitlementProvider: ProEntitlementProvider {
    func refresh() async {}

    func availability(for feature: ProFeature) async -> ProFeatureAvailability {
        ProFeatureAvailability.locked(
            reasonCode: .providerUnavailable,
            source: .none,
            messageKey: "pro_status_locked_message_provider"
        )
    }

    func restorePurchases() async throws {}
}

actor DirectLicenseEntitlementProvider: ProEntitlementProvider {
    private var enabledFeatures: Set<ProFeature> = []

    func setEnabledFeatures(_ features: Set<ProFeature>) {
        enabledFeatures = features
    }

    func refresh() async {}

    func availability(for feature: ProFeature) async -> ProFeatureAvailability {
        if enabledFeatures.contains(feature) {
            return .enabled(source: .direct)
        }
        return .locked(
            reasonCode: .notPurchased,
            source: .direct,
            messageKey: "pro_status_locked_message_purchase"
        )
    }

    func restorePurchases() async throws {}
}

actor StoreKit2EntitlementProvider: ProEntitlementProvider {
    private let productToFeature: [String: ProFeature]
    private var enabledFeatures: Set<ProFeature> = []

    init(productToFeature: [String: ProFeature] = Constants.Pro.productToFeatureMap) {
        self.productToFeature = productToFeature
    }

    func refresh() async {
        let entitledProductIDs = await currentEntitledProductIDs()
        enabledFeatures = Self.resolveEnabledFeatures(
            entitledProductIDs: entitledProductIDs,
            mapping: productToFeature
        )
    }

    func availability(for feature: ProFeature) async -> ProFeatureAvailability {
        guard Constants.Pro.featureToProductID[feature] != nil else {
            return .locked(
                reasonCode: .productMappingMissing,
                source: .storekit,
                messageKey: "pro_status_locked_message_mapping"
            )
        }

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
        try await AppStore.sync()
        await refresh()
    }

    static func resolveEnabledFeatures(
        entitledProductIDs: Set<String>,
        mapping: [String: ProFeature]
    ) -> Set<ProFeature> {
        Set(entitledProductIDs.compactMap { mapping[$0] })
    }

    private func currentEntitledProductIDs() async -> Set<String> {
        var productIDs: Set<String> = []

        for await verificationResult in Transaction.currentEntitlements {
            guard case .verified(let transaction) = verificationResult else { continue }
            guard transaction.revocationDate == nil else { continue }
            if let expirationDate = transaction.expirationDate, expirationDate < Date() {
                continue
            }
            productIDs.insert(transaction.productID)
        }

        return productIDs
    }
}

@MainActor
@Observable
final class ProRuntime {
    private let entitlementProvider: any ProEntitlementProvider
    private(set) var module: any ProModule
    private(set) var availabilityMap: [ProFeature: ProFeatureAvailability]
    private var transactionUpdatesTask: Task<Void, Never>?

    init(
        entitlementProvider: any ProEntitlementProvider,
        module: any ProModule
    ) {
        self.entitlementProvider = entitlementProvider
        self.module = module
        self.availabilityMap = Dictionary(
            uniqueKeysWithValues: ProFeature.allCases.map {
                (
                    $0,
                    ProFeatureAvailability.locked(
                        reasonCode: .providerUnavailable,
                        source: .none,
                        messageKey: "pro_status_locked_message_provider"
                    )
                )
            }
        )
    }

    func startMonitoringEntitlements() {
        transactionUpdatesTask?.cancel()
        transactionUpdatesTask = Task { [weak self] in
            guard let self else { return }
            for await _ in Transaction.updates {
                await self.refreshEntitlements()
            }
        }
    }

    func refreshEntitlements() async {
        await entitlementProvider.refresh()
        var updated: [ProFeature: ProFeatureAvailability] = [:]
        for feature in ProFeature.allCases {
            updated[feature] = await entitlementProvider.availability(for: feature)
        }
        availabilityMap = updated
    }

    func restorePurchases() async throws {
        try await entitlementProvider.restorePurchases()
        await refreshEntitlements()
    }

    func availability(for feature: ProFeature) -> ProFeatureAvailability {
        availabilityMap[feature] ?? .locked(
            reasonCode: .providerUnavailable,
            source: .none,
            messageKey: "pro_status_locked_message_provider"
        )
    }

    func isEnabled(_ feature: ProFeature) -> Bool {
        availability(for: feature).isEnabled
    }

    var menuDescriptors: [ProActionDescriptor] {
        module.menuDescriptors
    }

    var settingsDescriptors: [ProSettingsDescriptor] {
        module.settingsDescriptors
    }

    func executeMenuAction(
        descriptor: ProActionDescriptor,
        keyFingerprint: String?
    ) async throws -> ProActionExecutionResult {
        guard isEnabled(descriptor.feature) else {
            throw ProModuleExecutionError.featureLocked(descriptor.feature)
        }
        return try await module.execute(
            actionID: descriptor.id,
            context: ProActionContext(keyFingerprint: keyFingerprint)
        )
    }
}

/// Shared application state container for dependency injection.
@MainActor
@Observable
final class AppState {

    // MARK: - Singleton

    static let shared = AppState()

    // MARK: - Shared ViewModels

    let keyManagement: KeyManagementViewModel
    let proRuntime: ProRuntime

    // MARK: - Initialization

    private init() {
        keyManagement = KeyManagementViewModel()

        let entitlementProvider: any ProEntitlementProvider = StoreKit2EntitlementProvider()
        let module: any ProModule = NoopProModule()
        proRuntime = ProRuntime(
            entitlementProvider: entitlementProvider,
            module: module
        )
        proRuntime.startMonitoringEntitlements()

        Task {
            await proRuntime.refreshEntitlements()
        }
    }
}
