import Foundation
import Testing
@testable import ALDomain

@Test
func productionModelProviderRegistryDefaultsToLocalProvider() {
    let registry = ModelProviderRegistry.productionDefaults

    #expect(registry.validateSafetyPolicy().isEmpty)
    #expect(registry.providers == [.localRules])
    #expect(registry.provider(id: "local.rules")?.requiresNetworkAccess == false)
    #expect(registry.provider(id: "local.rules")?.sendsDataOffDevice == false)
    #expect(
        registry.decision(
            forProviderID: "local.rules",
            privacyMode: .airGapped,
            requiredCapabilities: [.fileClassification]
        ) == .allowed
    )
}

@Test
func modelProviderProtocolCarriesDescriptorRefsAndOffDeviceFlag() async throws {
    let provider = StubModelProvider()
    let sourceRef = ObjectRef(kind: .document, id: "doc-1")

    let response = try await provider.generate(
        ModelProviderRequest(
            capability: .fileClassification,
            promptTemplateID: "intake.classify.v1",
            inputScope: .metadataOnly,
            inputObjectRefs: [sourceRef],
            maxOutputTokens: 64
        )
    )

    #expect(provider.descriptor == .localRules)
    #expect(response.providerID == "local.rules")
    #expect(response.capability == .fileClassification)
    #expect(response.sourceRefs == [sourceRef])
    #expect(response.sentDataOffDevice == false)
}

@Test
func localRulesModelProviderReturnsLocalSourceBackedResponse() async throws {
    let provider = LocalRulesModelProvider()
    let sourceRef = ObjectRef(kind: .transaction, id: "txn-1")

    let response = try await provider.generate(
        ModelProviderRequest(
            capability: .evidenceLinking,
            promptTemplateID: "evidence.link.v1",
            inputScope: .localWorkspaceData,
            inputObjectRefs: [sourceRef],
            maxOutputTokens: 128
        )
    )

    #expect(response.providerID == "local.rules")
    #expect(response.capability == .evidenceLinking)
    #expect(response.sourceRefs == [sourceRef])
    #expect(response.sentDataOffDevice == false)
    #expect(response.outputText.contains("provider=local.rules"))
    #expect(response.outputText.contains("sourceRefs=1"))
}

@Test
func localRulesModelProviderRejectsUnsupportedOrInvalidRequests() async throws {
    let provider = LocalRulesModelProvider()

    do {
        _ = try await provider.generate(
            ModelProviderRequest(
                capability: .taxExplanation,
                promptTemplateID: "tax.explain.v1",
                inputScope: .localWorkspaceData
            )
        )
        Issue.record("Expected unsupported capability rejection")
    } catch let error as LocalModelProviderError {
        #expect(error == .unsupportedCapability(.taxExplanation))
    }

    do {
        _ = try await provider.generate(
            ModelProviderRequest(
                capability: .fileClassification,
                promptTemplateID: " ",
                inputScope: .metadataOnly
            )
        )
        Issue.record("Expected empty prompt template rejection")
    } catch let error as LocalModelProviderError {
        #expect(error == .emptyPromptTemplateID)
    }

    do {
        _ = try await provider.generate(
            ModelProviderRequest(
                capability: .fileClassification,
                promptTemplateID: "intake.classify.v1",
                inputScope: .metadataOnly,
                maxOutputTokens: 0
            )
        )
        Issue.record("Expected invalid max token rejection")
    } catch let error as LocalModelProviderError {
        #expect(error == .invalidMaxOutputTokens(0))
    }
}

@Test
func modelProviderPolicyBlocksUnknownAndMissingCapabilities() {
    let registry = ModelProviderRegistry.productionDefaults

    #expect(
        registry.decision(
            forProviderID: "missing.provider",
            privacyMode: .airGapped
        ) == .blocked(.providerNotRegistered)
    )
    #expect(
        registry.decision(
            forProviderID: "local.rules",
            privacyMode: .airGapped,
            requiredCapabilities: [.taxExplanation]
        ) == .blocked(.missingCapability)
    )
}

@Test
func modelProviderPolicyRejectsCloudProviderInAirGappedMode() {
    let registry = ModelProviderRegistry(providers: [.localRules, testCloudProvider])

    #expect(registry.validateSafetyPolicy().isEmpty)
    #expect(
        registry.decision(
            forProviderID: "cloud.reasoning",
            privacyMode: .airGapped,
            consent: ModelProviderConsent(
                allowsNetworkAccess: true,
                allowsOffDeviceData: true,
                approvedProviderIDs: ["cloud.reasoning"]
            ),
            requiredCapabilities: [.taxExplanation]
        ) == .blocked(.networkDisabled)
    )
}

@Test
func modelProviderExecutorRunsLocalProviderThroughAirGappedPolicy() async throws {
    let sourceRef = ObjectRef(kind: .document, id: "receipt-1")
    let response = try await ModelProviderExecutor.productionLocalOnly.execute(
        providerID: "local.rules",
        request: ModelProviderRequest(
            capability: .fileClassification,
            promptTemplateID: "intake.classify.v1",
            inputScope: .metadataOnly,
            inputObjectRefs: [sourceRef]
        ),
        privacyMode: .airGapped
    )

    #expect(response.providerID == "local.rules")
    #expect(response.sourceRefs == [sourceRef])
    #expect(response.sentDataOffDevice == false)
}

@Test
func modelProviderExecutorRejectsCloudProviderBeforeInvocationInAirGappedMode() async throws {
    let probe = ModelProviderProbe()
    let registry = ModelProviderRegistry(providers: [.localRules, testCloudProvider])
    let executor = ModelProviderExecutor(
        registry: registry,
        providers: [
            "local.rules": LocalRulesModelProvider(),
            "cloud.reasoning": ProbeModelProvider(descriptor: testCloudProvider, probe: probe),
        ]
    )

    do {
        _ = try await executor.execute(
            providerID: "cloud.reasoning",
            request: ModelProviderRequest(
                capability: .taxExplanation,
                promptTemplateID: "tax.explain.v1",
                inputScope: .redactedSnippets
            ),
            privacyMode: .airGapped,
            consent: ModelProviderConsent(
                allowsNetworkAccess: true,
                allowsOffDeviceData: true,
                approvedProviderIDs: ["cloud.reasoning"]
            )
        )
        Issue.record("Expected air-gapped cloud provider rejection")
    } catch let error as ModelProviderExecutionError {
        #expect(
            error == .policyBlocked(
                providerID: "cloud.reasoning",
                reason: .networkDisabled
            )
        )
    }

    #expect(probe.didRun == false)
}

@Test
func modelProviderExecutorRejectsProviderDescriptorAndResponseMismatches() async throws {
    do {
        _ = try await ModelProviderExecutor(
            registry: .productionDefaults,
            providers: ["local.rules": ProbeModelProvider(descriptor: testCloudProvider)]
        ).execute(
            providerID: "local.rules",
            request: ModelProviderRequest(
                capability: .fileClassification,
                promptTemplateID: "intake.classify.v1",
                inputScope: .metadataOnly
            ),
            privacyMode: .airGapped
        )
        Issue.record("Expected descriptor mismatch rejection")
    } catch let error as ModelProviderExecutionError {
        #expect(error == .descriptorMismatch(providerID: "local.rules"))
    }

    do {
        _ = try await ModelProviderExecutor(
            registry: .productionDefaults,
            providers: [
                "local.rules": MismatchedResponseProvider(responseProviderID: "other.provider"),
            ]
        ).execute(
            providerID: "local.rules",
            request: ModelProviderRequest(
                capability: .fileClassification,
                promptTemplateID: "intake.classify.v1",
                inputScope: .metadataOnly
            ),
            privacyMode: .airGapped
        )
        Issue.record("Expected response provider mismatch rejection")
    } catch let error as ModelProviderExecutionError {
        #expect(
            error == .responseProviderMismatch(
                expected: "local.rules",
                actual: "other.provider"
            )
        )
    }
}

@Test
func modelProviderPolicyRequiresExplicitConsentForHybridCloudProvider() {
    let registry = ModelProviderRegistry(providers: [.localRules, testCloudProvider])

    #expect(
        registry.decision(
            forProviderID: "cloud.reasoning",
            privacyMode: .hybrid,
            requiredCapabilities: [.taxExplanation]
        ) == .blocked(.explicitConsentRequired)
    )
    #expect(
        registry.decision(
            forProviderID: "cloud.reasoning",
            privacyMode: .hybrid,
            consent: ModelProviderConsent(
                allowsNetworkAccess: true,
                allowsOffDeviceData: true,
                approvedProviderIDs: []
            ),
            requiredCapabilities: [.taxExplanation]
        ) == .blocked(.providerNotApproved)
    )
    #expect(
        registry.decision(
            forProviderID: "cloud.reasoning",
            privacyMode: .hybrid,
            consent: ModelProviderConsent(
                allowsNetworkAccess: true,
                allowsOffDeviceData: true,
                approvedProviderIDs: ["cloud.reasoning"]
            ),
            requiredCapabilities: [.taxExplanation]
        ) == .allowed
    )
}

@Test
func modelProviderPolicyRequiresRedactionControlsForOffDeviceInputScopes() async throws {
    let registry = ModelProviderRegistry(providers: [.localRules, testCloudProvider])
    let metadataOnlyConsent = ModelProviderConsent(
        allowsNetworkAccess: true,
        allowsOffDeviceData: true,
        approvedProviderIDs: ["cloud.reasoning"],
        redactionPolicy: .metadataOnly
    )
    let redactedSnippetConsent = ModelProviderConsent(
        allowsNetworkAccess: true,
        allowsOffDeviceData: true,
        approvedProviderIDs: ["cloud.reasoning"],
        redactionPolicy: .redactedSnippets
    )

    #expect(
        registry.decision(
            forProviderID: "cloud.reasoning",
            privacyMode: .hybrid,
            consent: metadataOnlyConsent,
            requiredCapabilities: [.taxExplanation],
            inputScope: .metadataOnly
        ) == .allowed
    )
    #expect(
        registry.decision(
            forProviderID: "cloud.reasoning",
            privacyMode: .hybrid,
            consent: metadataOnlyConsent,
            requiredCapabilities: [.taxExplanation],
            inputScope: .redactedSnippets
        ) == .blocked(.inputScopeNotAllowed)
    )
    #expect(
        registry.decision(
            forProviderID: "cloud.reasoning",
            privacyMode: .hybrid,
            consent: redactedSnippetConsent,
            requiredCapabilities: [.taxExplanation],
            inputScope: .redactedSnippets
        ) == .allowed
    )
    #expect(
        registry.decision(
            forProviderID: "cloud.reasoning",
            privacyMode: .externalAssistant,
            consent: redactedSnippetConsent,
            requiredCapabilities: [.taxExplanation],
            inputScope: .localWorkspaceData
        ) == .blocked(.inputScopeNotAllowed)
    )
    #expect(
        registry.decision(
            forProviderID: "local.rules",
            privacyMode: .airGapped,
            inputScope: .localWorkspaceData
        ) == .allowed
    )

    let probe = ModelProviderProbe()
    let executor = ModelProviderExecutor(
        registry: registry,
        providers: [
            "local.rules": LocalRulesModelProvider(),
            "cloud.reasoning": ProbeModelProvider(descriptor: testCloudProvider, probe: probe),
        ]
    )

    do {
        _ = try await executor.execute(
            providerID: "cloud.reasoning",
            request: ModelProviderRequest(
                capability: .taxExplanation,
                promptTemplateID: "tax.explain.v1",
                inputScope: .localWorkspaceData
            ),
            privacyMode: .hybrid,
            consent: redactedSnippetConsent
        )
        Issue.record("Expected input-scope policy rejection")
    } catch let error as ModelProviderExecutionError {
        #expect(
            error == .policyBlocked(
                providerID: "cloud.reasoning",
                reason: .inputScopeNotAllowed
            )
        )
    }

    #expect(probe.didRun == false)
}

@Test
func modelProviderActivityLogRecordsRunningCompletedAndBlockedExecutions() async throws {
    let registry = ModelProviderRegistry(providers: [.localRules, testCloudProvider])
    let log = ModelProviderActivityLog()
    let probe = ModelProviderActivityProbe()
    let consent = ModelProviderConsent(
        allowsNetworkAccess: true,
        allowsOffDeviceData: true,
        approvedProviderIDs: ["cloud.reasoning"],
        redactionPolicy: .redactedSnippets
    )
    let executor = ModelProviderExecutor(
        registry: registry,
        providers: [
            "local.rules": LocalRulesModelProvider(),
            "cloud.reasoning": ActivityInspectingProvider(
                descriptor: testCloudProvider,
                activityLog: log,
                probe: probe
            ),
        ],
        activityRecorder: log
    )

    let response = try await executor.execute(
        providerID: "cloud.reasoning",
        request: ModelProviderRequest(
            capability: .taxExplanation,
            promptTemplateID: "tax.explain.v1",
            inputScope: .redactedSnippets
        ),
        privacyMode: .hybrid,
        consent: consent
    )

    #expect(response.sentDataOffDevice)
    #expect(probe.observedRunningActivity)
    #expect(log.snapshots().map(\.phase) == [.running, .completed])
    #expect(log.latestSnapshot?.providerID == "cloud.reasoning")
    #expect(log.latestSnapshot?.requiresNetworkAccess == true)
    #expect(log.latestSnapshot?.sentDataOffDevice == true)

    let blockedLog = ModelProviderActivityLog()
    let blockedExecutor = ModelProviderExecutor(
        registry: registry,
        providers: [
            "local.rules": LocalRulesModelProvider(),
            "cloud.reasoning": ProbeModelProvider(descriptor: testCloudProvider),
        ],
        activityRecorder: blockedLog
    )

    do {
        _ = try await blockedExecutor.execute(
            providerID: "cloud.reasoning",
            request: ModelProviderRequest(
                capability: .taxExplanation,
                promptTemplateID: "tax.explain.v1",
                inputScope: .localWorkspaceData
            ),
            privacyMode: .hybrid,
            consent: consent
        )
        Issue.record("Expected input-scope policy rejection")
    } catch let error as ModelProviderExecutionError {
        #expect(
            error == .policyBlocked(
                providerID: "cloud.reasoning",
                reason: .inputScopeNotAllowed
            )
        )
    }

    #expect(blockedLog.snapshots().map(\.phase) == [.blocked])
    #expect(blockedLog.latestSnapshot?.blockReason == .inputScopeNotAllowed)
    #expect(blockedLog.latestSnapshot?.requiresNetworkAccess == true)
}

@Test
func modelProviderPolicyFiltersAllowedProvidersByCapabilityAndConsent() {
    let registry = ModelProviderRegistry(providers: [.localRules, testCloudProvider])

    #expect(
        registry.allowedProviders(
            privacyMode: .airGapped,
            requiredCapabilities: [.fileClassification]
        ).map(\.id) == ["local.rules"]
    )
    #expect(
        registry.allowedProviders(
            privacyMode: .airGapped,
            requiredCapabilities: [.taxExplanation]
        ).isEmpty
    )
    #expect(
        registry.allowedProviders(
            privacyMode: .externalAssistant,
            consent: ModelProviderConsent(
                allowsNetworkAccess: true,
                allowsOffDeviceData: true,
                approvedProviderIDs: ["cloud.reasoning"]
            ),
            requiredCapabilities: [.taxExplanation]
        ).map(\.id) == ["cloud.reasoning"]
    )
}

@Test
func modelProviderRegistryFlagsUnsafeProviderDescriptors() {
    let registry = ModelProviderRegistry(
        providers: [
            ModelProviderDescriptor(
                id: "duplicate",
                displayName: "",
                role: .cloudReasoning,
                location: .externalNetwork,
                capabilities: [],
                requiresNetworkAccess: false,
                sendsDataOffDevice: false,
                requiresExplicitConsent: true
            ),
            ModelProviderDescriptor(
                id: "duplicate",
                displayName: "Duplicate",
                role: .localSmall,
                location: .inProcess,
                capabilities: [.fileClassification],
                requiresNetworkAccess: false,
                sendsDataOffDevice: false,
                requiresExplicitConsent: false
            ),
        ]
    )

    let violations = registry.validateSafetyPolicy()
    #expect(violations.contains(.emptyDisplayName("duplicate")))
    #expect(violations.contains(.missingCapability("duplicate")))
    #expect(violations.contains(.externalProviderWithoutNetworkRequirement("duplicate")))
    #expect(violations.contains(.externalProviderWithoutOffDeviceFlag("duplicate")))
    #expect(violations.contains(.duplicateProviderID("duplicate")))
}

private let testCloudProvider = ModelProviderDescriptor(
    id: "cloud.reasoning",
    displayName: "Cloud reasoning provider",
    role: .cloudReasoning,
    location: .externalNetwork,
    capabilities: [
        .chatReasoning,
        .taxExplanation,
        .reconciliationExplanation,
    ],
    requiresNetworkAccess: true,
    sendsDataOffDevice: true,
    requiresExplicitConsent: true
)

private struct StubModelProvider: ModelProvider {
    let descriptor = ModelProviderDescriptor.localRules

    func generate(_ request: ModelProviderRequest) async throws -> ModelProviderResponse {
        ModelProviderResponse(
            providerID: descriptor.id,
            capability: request.capability,
            outputText: "classified",
            confidence: 0.9,
            sourceRefs: request.inputObjectRefs,
            sentDataOffDevice: descriptor.sendsDataOffDevice
        )
    }
}

private final class ModelProviderProbe: @unchecked Sendable {
    var didRun = false
}

private final class ModelProviderActivityProbe: @unchecked Sendable {
    private let lock = NSLock()
    private var observedRunning = false

    var observedRunningActivity: Bool {
        lock.lock()
        defer { lock.unlock() }
        return observedRunning
    }

    func observe(_ value: Bool) {
        lock.lock()
        observedRunning = observedRunning || value
        lock.unlock()
    }
}

private struct ActivityInspectingProvider: ModelProvider {
    let descriptor: ModelProviderDescriptor
    let activityLog: ModelProviderActivityLog
    let probe: ModelProviderActivityProbe

    func generate(_ request: ModelProviderRequest) async throws -> ModelProviderResponse {
        probe.observe(
            activityLog.latestSnapshot?.phase == .running &&
                activityLog.latestSnapshot?.providerID == descriptor.id &&
                activityLog.latestSnapshot?.requiresNetworkAccess == descriptor.requiresNetworkAccess
        )
        return ModelProviderResponse(
            providerID: descriptor.id,
            capability: request.capability,
            outputText: "probe",
            sourceRefs: request.inputObjectRefs,
            sentDataOffDevice: descriptor.sendsDataOffDevice
        )
    }
}

private struct ProbeModelProvider: ModelProvider {
    let descriptor: ModelProviderDescriptor
    let probe: ModelProviderProbe?

    init(descriptor: ModelProviderDescriptor, probe: ModelProviderProbe? = nil) {
        self.descriptor = descriptor
        self.probe = probe
    }

    func generate(_ request: ModelProviderRequest) async throws -> ModelProviderResponse {
        probe?.didRun = true
        return ModelProviderResponse(
            providerID: descriptor.id,
            capability: request.capability,
            outputText: "probe",
            sourceRefs: request.inputObjectRefs,
            sentDataOffDevice: descriptor.sendsDataOffDevice
        )
    }
}

private struct MismatchedResponseProvider: ModelProvider {
    let descriptor = ModelProviderDescriptor.localRules
    let responseProviderID: String

    func generate(_ request: ModelProviderRequest) async throws -> ModelProviderResponse {
        ModelProviderResponse(
            providerID: responseProviderID,
            capability: request.capability,
            outputText: "mismatch",
            sourceRefs: request.inputObjectRefs,
            sentDataOffDevice: false
        )
    }
}
