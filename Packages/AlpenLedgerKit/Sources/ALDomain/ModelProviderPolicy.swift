import Foundation

public enum ModelProviderRole: String, Codable, CaseIterable, Sendable {
    case localSmall
    case localReasoning
    case cloudReasoning
    case embeddingProvider
    case rerankerProvider
}

public enum ModelProviderCapability: String, Codable, CaseIterable, Sendable {
    case fileClassification
    case extractionCleanup
    case evidenceLinking
    case reconciliationExplanation
    case taxExplanation
    case chatReasoning
    case embeddings
    case reranking
}

public enum ModelProviderLocation: String, Codable, CaseIterable, Sendable {
    case inProcess
    case localService
    case externalNetwork
}

public enum ModelProviderInputScope: String, Codable, CaseIterable, Sendable {
    case metadataOnly
    case redactedSnippets
    case localWorkspaceData
}

public enum ModelProviderRedactionPolicy: String, Codable, CaseIterable, Sendable {
    case metadataOnly
    case redactedSnippets

    public func allows(_ inputScope: ModelProviderInputScope) -> Bool {
        switch (self, inputScope) {
        case (.metadataOnly, .metadataOnly):
            true
        case (.metadataOnly, .redactedSnippets), (.metadataOnly, .localWorkspaceData):
            false
        case (.redactedSnippets, .metadataOnly), (.redactedSnippets, .redactedSnippets):
            true
        case (.redactedSnippets, .localWorkspaceData):
            false
        }
    }
}

public enum ModelProviderPrivacyMode: String, Codable, CaseIterable, Sendable {
    case airGapped
    case hybrid
    case externalAssistant

    public var allowsNetworkAccess: Bool {
        switch self {
        case .airGapped:
            false
        case .hybrid, .externalAssistant:
            true
        }
    }

    public var canSendDataOffDevice: Bool {
        switch self {
        case .airGapped:
            false
        case .hybrid, .externalAssistant:
            true
        }
    }
}

public struct ModelProviderDescriptor: Hashable, Codable, Sendable {
    public let id: String
    public let displayName: String
    public let role: ModelProviderRole
    public let location: ModelProviderLocation
    public let capabilities: Set<ModelProviderCapability>
    public let requiresNetworkAccess: Bool
    public let sendsDataOffDevice: Bool
    public let requiresExplicitConsent: Bool

    public init(
        id: String,
        displayName: String,
        role: ModelProviderRole,
        location: ModelProviderLocation,
        capabilities: Set<ModelProviderCapability>,
        requiresNetworkAccess: Bool,
        sendsDataOffDevice: Bool,
        requiresExplicitConsent: Bool
    ) {
        self.id = id
        self.displayName = displayName
        self.role = role
        self.location = location
        self.capabilities = capabilities
        self.requiresNetworkAccess = requiresNetworkAccess
        self.sendsDataOffDevice = sendsDataOffDevice
        self.requiresExplicitConsent = requiresExplicitConsent
    }

    public static let localRules = ModelProviderDescriptor(
        id: "local.rules",
        displayName: "Local deterministic tools",
        role: .localSmall,
        location: .inProcess,
        capabilities: [
            .fileClassification,
            .extractionCleanup,
            .evidenceLinking,
            .reconciliationExplanation,
        ],
        requiresNetworkAccess: false,
        sendsDataOffDevice: false,
        requiresExplicitConsent: false
    )
}

public struct ModelProviderRequest: Hashable, Codable, Sendable {
    public let capability: ModelProviderCapability
    public let promptTemplateID: String
    public let inputScope: ModelProviderInputScope
    public let inputObjectRefs: [ObjectRef]
    public let maxOutputTokens: Int?

    public init(
        capability: ModelProviderCapability,
        promptTemplateID: String,
        inputScope: ModelProviderInputScope,
        inputObjectRefs: [ObjectRef] = [],
        maxOutputTokens: Int? = nil
    ) {
        self.capability = capability
        self.promptTemplateID = promptTemplateID
        self.inputScope = inputScope
        self.inputObjectRefs = inputObjectRefs
        self.maxOutputTokens = maxOutputTokens
    }
}

public struct ModelProviderResponse: Hashable, Codable, Sendable {
    public let providerID: String
    public let capability: ModelProviderCapability
    public let outputText: String
    public let confidence: Double?
    public let sourceRefs: [ObjectRef]
    public let sentDataOffDevice: Bool

    public init(
        providerID: String,
        capability: ModelProviderCapability,
        outputText: String,
        confidence: Double? = nil,
        sourceRefs: [ObjectRef] = [],
        sentDataOffDevice: Bool
    ) {
        self.providerID = providerID
        self.capability = capability
        self.outputText = outputText
        self.confidence = confidence
        self.sourceRefs = sourceRefs
        self.sentDataOffDevice = sentDataOffDevice
    }
}

public protocol ModelProvider: Sendable {
    var descriptor: ModelProviderDescriptor { get }

    func generate(_ request: ModelProviderRequest) async throws -> ModelProviderResponse
}

public enum LocalModelProviderError: Error, Hashable, Sendable {
    case unsupportedCapability(ModelProviderCapability)
    case emptyPromptTemplateID
    case invalidMaxOutputTokens(Int)
}

public struct LocalRulesModelProvider: ModelProvider {
    public let descriptor: ModelProviderDescriptor

    public init(descriptor: ModelProviderDescriptor = .localRules) {
        self.descriptor = descriptor
    }

    public func generate(_ request: ModelProviderRequest) async throws -> ModelProviderResponse {
        guard descriptor.capabilities.contains(request.capability) else {
            throw LocalModelProviderError.unsupportedCapability(request.capability)
        }
        guard request.promptTemplateID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            throw LocalModelProviderError.emptyPromptTemplateID
        }
        if let maxOutputTokens = request.maxOutputTokens, maxOutputTokens <= 0 {
            throw LocalModelProviderError.invalidMaxOutputTokens(maxOutputTokens)
        }

        let outputText = [
            "provider=\(descriptor.id)",
            "capability=\(request.capability.rawValue)",
            "inputScope=\(request.inputScope.rawValue)",
            "sourceRefs=\(request.inputObjectRefs.count)",
        ].joined(separator: ";")

        return ModelProviderResponse(
            providerID: descriptor.id,
            capability: request.capability,
            outputText: outputText,
            confidence: 1.0,
            sourceRefs: request.inputObjectRefs,
            sentDataOffDevice: false
        )
    }
}

public enum ModelProviderPolicyBlockReason: String, Codable, Hashable, Sendable {
    case providerNotRegistered
    case missingCapability
    case networkDisabled
    case offDeviceDataDisabled
    case explicitConsentRequired
    case providerNotApproved
    case inputScopeNotAllowed
}

public enum ModelProviderPolicyDecision: Codable, Hashable, Sendable {
    case allowed
    case blocked(ModelProviderPolicyBlockReason)
}

public struct ModelProviderConsent: Hashable, Codable, Sendable {
    public let allowsNetworkAccess: Bool
    public let allowsOffDeviceData: Bool
    public let approvedProviderIDs: Set<String>
    public let redactionPolicy: ModelProviderRedactionPolicy

    public init(
        allowsNetworkAccess: Bool = false,
        allowsOffDeviceData: Bool = false,
        approvedProviderIDs: Set<String> = [],
        redactionPolicy: ModelProviderRedactionPolicy = .metadataOnly
    ) {
        self.allowsNetworkAccess = allowsNetworkAccess
        self.allowsOffDeviceData = allowsOffDeviceData
        self.approvedProviderIDs = approvedProviderIDs
        self.redactionPolicy = redactionPolicy
    }

    public static let none = ModelProviderConsent()
}

public enum ModelProviderActivityPhase: String, Codable, Hashable, Sendable {
    case running
    case completed
    case blocked
    case failed
}

public struct ModelProviderActivitySnapshot: Hashable, Codable, Sendable {
    public let providerID: String
    public let providerName: String?
    public let capability: ModelProviderCapability?
    public let inputScope: ModelProviderInputScope?
    public let privacyMode: ModelProviderPrivacyMode
    public let phase: ModelProviderActivityPhase
    public let requiresNetworkAccess: Bool
    public let sendsDataOffDevice: Bool
    public let sentDataOffDevice: Bool?
    public let startedAt: Date
    public let finishedAt: Date?
    public let blockReason: ModelProviderPolicyBlockReason?
    public let errorDescription: String?

    public init(
        providerID: String,
        providerName: String? = nil,
        capability: ModelProviderCapability? = nil,
        inputScope: ModelProviderInputScope? = nil,
        privacyMode: ModelProviderPrivacyMode,
        phase: ModelProviderActivityPhase,
        requiresNetworkAccess: Bool,
        sendsDataOffDevice: Bool,
        sentDataOffDevice: Bool? = nil,
        startedAt: Date,
        finishedAt: Date? = nil,
        blockReason: ModelProviderPolicyBlockReason? = nil,
        errorDescription: String? = nil
    ) {
        self.providerID = providerID
        self.providerName = providerName
        self.capability = capability
        self.inputScope = inputScope
        self.privacyMode = privacyMode
        self.phase = phase
        self.requiresNetworkAccess = requiresNetworkAccess
        self.sendsDataOffDevice = sendsDataOffDevice
        self.sentDataOffDevice = sentDataOffDevice
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.blockReason = blockReason
        self.errorDescription = errorDescription
    }
}

public protocol ModelProviderActivityRecording: Sendable {
    func record(_ snapshot: ModelProviderActivitySnapshot)
}

public final class ModelProviderActivityLog: ModelProviderActivityRecording, @unchecked Sendable {
    private let lock = NSLock()
    private var recordedSnapshots: [ModelProviderActivitySnapshot] = []

    public init() {}

    public func record(_ snapshot: ModelProviderActivitySnapshot) {
        lock.lock()
        defer { lock.unlock() }
        recordedSnapshots.append(snapshot)
    }

    public var latestSnapshot: ModelProviderActivitySnapshot? {
        lock.lock()
        defer { lock.unlock() }
        return recordedSnapshots.last
    }

    public func snapshots() -> [ModelProviderActivitySnapshot] {
        lock.lock()
        defer { lock.unlock() }
        return recordedSnapshots
    }
}

public enum ModelProviderRegistryViolation: Codable, Hashable, Sendable {
    case duplicateProviderID(String)
    case emptyProviderID
    case emptyDisplayName(String)
    case missingCapability(String)
    case externalProviderWithoutNetworkRequirement(String)
    case externalProviderWithoutOffDeviceFlag(String)
}

public enum ModelProviderExecutionError: Error, Hashable, Sendable {
    case unsafeRegistry([ModelProviderRegistryViolation])
    case providerUnavailable(String)
    case descriptorMismatch(providerID: String)
    case policyBlocked(providerID: String, reason: ModelProviderPolicyBlockReason)
    case responseProviderMismatch(expected: String, actual: String)
    case responseCapabilityMismatch(expected: ModelProviderCapability, actual: ModelProviderCapability)
    case offDeviceResponseContradictsDescriptor(String)
}

public struct ModelProviderRegistry: Hashable, Codable, Sendable {
    public let providers: [ModelProviderDescriptor]

    public init(providers: [ModelProviderDescriptor]) {
        self.providers = providers
    }

    public func provider(id: String) -> ModelProviderDescriptor? {
        providers.first { $0.id == id }
    }

    public func validateSafetyPolicy() -> [ModelProviderRegistryViolation] {
        var violations: [ModelProviderRegistryViolation] = []
        var seenIDs = Set<String>()

        for provider in providers {
            if provider.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                violations.append(.emptyProviderID)
            } else if seenIDs.insert(provider.id).inserted == false {
                violations.append(.duplicateProviderID(provider.id))
            }
            if provider.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                violations.append(.emptyDisplayName(provider.id))
            }
            if provider.capabilities.isEmpty {
                violations.append(.missingCapability(provider.id))
            }
            if provider.location == .externalNetwork && provider.requiresNetworkAccess == false {
                violations.append(.externalProviderWithoutNetworkRequirement(provider.id))
            }
            if provider.location == .externalNetwork && provider.sendsDataOffDevice == false {
                violations.append(.externalProviderWithoutOffDeviceFlag(provider.id))
            }
        }

        return violations
    }

    public func decision(
        forProviderID providerID: String,
        privacyMode: ModelProviderPrivacyMode,
        consent: ModelProviderConsent = .none,
        requiredCapabilities: Set<ModelProviderCapability> = [],
        inputScope: ModelProviderInputScope? = nil
    ) -> ModelProviderPolicyDecision {
        guard let provider = provider(id: providerID) else {
            return .blocked(.providerNotRegistered)
        }
        guard requiredCapabilities.isSubset(of: provider.capabilities) else {
            return .blocked(.missingCapability)
        }
        guard provider.requiresNetworkAccess == false || privacyMode.allowsNetworkAccess else {
            return .blocked(.networkDisabled)
        }
        guard provider.requiresNetworkAccess == false || consent.allowsNetworkAccess else {
            return .blocked(.explicitConsentRequired)
        }
        guard provider.sendsDataOffDevice == false || privacyMode.canSendDataOffDevice else {
            return .blocked(.offDeviceDataDisabled)
        }
        guard provider.sendsDataOffDevice == false || consent.allowsOffDeviceData else {
            return .blocked(.explicitConsentRequired)
        }
        guard provider.requiresExplicitConsent == false || consent.approvedProviderIDs.contains(provider.id) else {
            return .blocked(.providerNotApproved)
        }
        if provider.sendsDataOffDevice,
           let inputScope,
           consent.redactionPolicy.allows(inputScope) == false {
            return .blocked(.inputScopeNotAllowed)
        }

        return .allowed
    }

    public func allowedProviders(
        privacyMode: ModelProviderPrivacyMode,
        consent: ModelProviderConsent = .none,
        requiredCapabilities: Set<ModelProviderCapability> = []
    ) -> [ModelProviderDescriptor] {
        providers.filter { provider in
            decision(
                forProviderID: provider.id,
                privacyMode: privacyMode,
                consent: consent,
                requiredCapabilities: requiredCapabilities
            ) == .allowed
        }
    }

    public static let productionDefaults = ModelProviderRegistry(
        providers: [
            .localRules,
        ]
    )
}

public struct ModelProviderExecutor: Sendable {
    private let registry: ModelProviderRegistry
    private let providers: [String: any ModelProvider]
    private let activityRecorder: (any ModelProviderActivityRecording)?
    private let nowProvider: @Sendable () -> Date

    public init(
        registry: ModelProviderRegistry,
        providers: [String: any ModelProvider],
        activityRecorder: (any ModelProviderActivityRecording)? = nil,
        nowProvider: @escaping @Sendable () -> Date = { .now }
    ) {
        self.registry = registry
        self.providers = providers
        self.activityRecorder = activityRecorder
        self.nowProvider = nowProvider
    }

    public func execute(
        providerID: String,
        request: ModelProviderRequest,
        privacyMode: ModelProviderPrivacyMode,
        consent: ModelProviderConsent = .none
    ) async throws -> ModelProviderResponse {
        let startedAt = nowProvider()

        func recordActivity(
            phase: ModelProviderActivityPhase,
            descriptor: ModelProviderDescriptor?,
            finishedAt: Date? = nil,
            sentDataOffDevice: Bool? = nil,
            blockReason: ModelProviderPolicyBlockReason? = nil,
            errorDescription: String? = nil
        ) {
            activityRecorder?.record(
                ModelProviderActivitySnapshot(
                    providerID: descriptor?.id ?? providerID,
                    providerName: descriptor?.displayName,
                    capability: request.capability,
                    inputScope: request.inputScope,
                    privacyMode: privacyMode,
                    phase: phase,
                    requiresNetworkAccess: descriptor?.requiresNetworkAccess ?? false,
                    sendsDataOffDevice: descriptor?.sendsDataOffDevice ?? false,
                    sentDataOffDevice: sentDataOffDevice,
                    startedAt: startedAt,
                    finishedAt: finishedAt,
                    blockReason: blockReason,
                    errorDescription: errorDescription
                )
            )
        }

        let violations = registry.validateSafetyPolicy()
        guard violations.isEmpty else {
            recordActivity(
                phase: .failed,
                descriptor: registry.provider(id: providerID),
                finishedAt: nowProvider(),
                errorDescription: "Unsafe provider registry"
            )
            throw ModelProviderExecutionError.unsafeRegistry(violations)
        }

        guard let registeredDescriptor = registry.provider(id: providerID) else {
            recordActivity(
                phase: .failed,
                descriptor: nil,
                finishedAt: nowProvider(),
                errorDescription: "Provider is not registered"
            )
            throw ModelProviderExecutionError.providerUnavailable(providerID)
        }
        guard let provider = providers[providerID] else {
            recordActivity(
                phase: .failed,
                descriptor: registeredDescriptor,
                finishedAt: nowProvider(),
                errorDescription: "Provider is unavailable"
            )
            throw ModelProviderExecutionError.providerUnavailable(providerID)
        }
        guard provider.descriptor == registeredDescriptor else {
            recordActivity(
                phase: .failed,
                descriptor: registeredDescriptor,
                finishedAt: nowProvider(),
                errorDescription: "Provider descriptor mismatch"
            )
            throw ModelProviderExecutionError.descriptorMismatch(providerID: providerID)
        }

        switch registry.decision(
            forProviderID: providerID,
            privacyMode: privacyMode,
            consent: consent,
            requiredCapabilities: [request.capability],
            inputScope: request.inputScope
        ) {
        case .allowed:
            break
        case .blocked(let reason):
            recordActivity(
                phase: .blocked,
                descriptor: registeredDescriptor,
                finishedAt: nowProvider(),
                blockReason: reason
            )
            throw ModelProviderExecutionError.policyBlocked(providerID: providerID, reason: reason)
        }

        recordActivity(phase: .running, descriptor: registeredDescriptor)

        do {
            let response = try await provider.generate(request)
            guard response.providerID == providerID else {
                throw ModelProviderExecutionError.responseProviderMismatch(
                    expected: providerID,
                    actual: response.providerID
                )
            }
            guard response.capability == request.capability else {
                throw ModelProviderExecutionError.responseCapabilityMismatch(
                    expected: request.capability,
                    actual: response.capability
                )
            }
            if registeredDescriptor.sendsDataOffDevice == false && response.sentDataOffDevice {
                throw ModelProviderExecutionError.offDeviceResponseContradictsDescriptor(providerID)
            }

            recordActivity(
                phase: .completed,
                descriptor: registeredDescriptor,
                finishedAt: nowProvider(),
                sentDataOffDevice: response.sentDataOffDevice
            )
            return response
        } catch {
            recordActivity(
                phase: .failed,
                descriptor: registeredDescriptor,
                finishedAt: nowProvider(),
                errorDescription: String(describing: error)
            )
            throw error
        }
    }

    public static let productionLocalOnly = ModelProviderExecutor(
        registry: .productionDefaults,
        providers: [
            ModelProviderDescriptor.localRules.id: LocalRulesModelProvider(),
        ]
    )
}
