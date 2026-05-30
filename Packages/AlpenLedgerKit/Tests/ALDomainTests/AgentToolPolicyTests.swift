import Foundation
import Testing
@testable import ALDomain

@Test
func productionAgentToolRegistryPassesSafetyPolicy() {
    #expect(AgentToolRegistry.productionDefaults.validateSafetyPolicy().isEmpty)
}

@Test
func confirmedWriteToolsRequireExplicitUserConfirmation() {
    let confirmedWriteTools = AgentToolRegistry.productionDefaults.tools
        .filter(\.mutatesAuthoritativeData)

    #expect(confirmedWriteTools.isEmpty == false)
    #expect(confirmedWriteTools.allSatisfy { $0.requiresUserConfirmation })
}

@Test
func productionAgentToolsDoNotExposeUnrestrictedRuntimeOrStorageAccess() {
    let productionTools = AgentToolRegistry.productionDefaults.tools

    #expect(productionTools.isEmpty == false)
    #expect(productionTools.allSatisfy { $0.allowsUnrestrictedFileAccess == false })
    #expect(productionTools.allSatisfy { $0.allowsRawSQL == false })
    #expect(productionTools.allSatisfy { $0.allowsShellExecution == false })
}

@Test
func agentToolPolicyRejectsUnsafeToolDefinitions() {
    let registry = AgentToolRegistry(
        tools: [
            AgentToolDefinition(
                name: "ledger.apply_draft_entry",
                sideEffect: .confirmedWrite,
                requiredScopes: [.ledgerWrite],
                returnsProvenance: true,
                requiresUserConfirmation: false
            ),
            AgentToolDefinition(
                name: "debug.raw_sql",
                sideEffect: .readOnly,
                requiredScopes: [],
                returnsProvenance: false,
                requiresUserConfirmation: false,
                allowsUnrestrictedFileAccess: true,
                allowsRawSQL: true,
                allowsShellExecution: true
            ),
            AgentToolDefinition(
                name: "debug.raw_sql",
                sideEffect: .readOnly,
                requiredScopes: [.financeRead],
                returnsProvenance: true,
                requiresUserConfirmation: false
            ),
        ]
    )

    let violations = registry.validateSafetyPolicy()
    #expect(violations.contains(.confirmedWriteWithoutConfirmation("ledger.apply_draft_entry")))
    #expect(violations.contains(.missingScope("debug.raw_sql")))
    #expect(violations.contains(.missingProvenance("debug.raw_sql")))
    #expect(violations.contains(.unrestrictedFileAccessAllowed("debug.raw_sql")))
    #expect(violations.contains(.rawSQLAllowed("debug.raw_sql")))
    #expect(violations.contains(.shellExecutionAllowed("debug.raw_sql")))
    #expect(violations.contains(.duplicateToolName("debug.raw_sql")))
}

@Test
func agentToolExecutorRunsReadOnlyToolWhenScopesAndProvenanceArePresent() throws {
    let documentRef = ObjectRef(kind: .document, id: "receipt-1")
    let executor = AgentToolExecutor(
        registry: .productionDefaults,
        handlers: [
            "docs.search": { invocation in
                #expect(invocation.grantedScopes == [.documentsRead])
                return AgentToolExecutionResult(
                    outputJSON: Data(#"{"matches":1}"#.utf8),
                    provenanceRefs: [documentRef]
                )
            },
        ]
    )

    let result = try executor.execute(
        AgentToolInvocation(
            toolName: "docs.search",
            grantedScopes: [.documentsRead]
        )
    )

    #expect(result.provenanceRefs == [documentRef])
}

@Test
func agentToolExecutorRejectsMissingScopeBeforeHandlerRuns() throws {
    let probe = AgentToolHandlerProbe()
    let executor = AgentToolExecutor(
        registry: .productionDefaults,
        handlers: [
            "tax.explain_fact": { _ in
                probe.didRun = true
                return AgentToolExecutionResult(
                    provenanceRefs: [ObjectRef(kind: .taxFact, id: "fact-1")]
                )
            },
        ]
    )

    do {
        _ = try executor.execute(
            AgentToolInvocation(
                toolName: "tax.explain_fact",
                grantedScopes: [.financeRead]
            )
        )
        Issue.record("Expected missing scope rejection")
    } catch let error as AgentToolExecutionError {
        #expect(
            error == .missingScopes(
                toolName: "tax.explain_fact",
                required: [.taxRead],
                granted: [.financeRead]
            )
        )
    }
    #expect(probe.didRun == false)
}

@Test
func agentToolExecutorRequiresExplicitConfirmationForConfirmedWrites() throws {
    let probe = AgentToolHandlerProbe()
    let approvedInput = Data(#"{"entry":"draft-1"}"#.utf8)
    let executor = AgentToolExecutor(
        registry: .productionDefaults,
        handlers: [
            "ledger.apply_draft_entry": { _ in
                probe.didRun = true
                return AgentToolExecutionResult(
                    provenanceRefs: [ObjectRef(kind: .journalEntry, id: "entry-1")]
                )
            },
        ]
    )

    do {
        _ = try executor.execute(
            AgentToolInvocation(
                toolName: "ledger.apply_draft_entry",
                inputJSON: approvedInput,
                grantedScopes: [.ledgerWrite]
            )
        )
        Issue.record("Expected confirmation rejection")
    } catch let error as AgentToolExecutionError {
        #expect(error == .confirmationRequired("ledger.apply_draft_entry"))
    }
    #expect(probe.didRun == false)

    do {
        _ = try executor.execute(
            AgentToolInvocation(
                toolName: "ledger.apply_draft_entry",
                inputJSON: approvedInput,
                grantedScopes: [.ledgerWrite],
                confirmation: AgentToolConfirmation(
                    toolName: "ledger.apply_draft_entry",
                    approvedInputHash: AgentToolInputHash.hash(approvedInput),
                    approvedBy: "reviewer",
                    approvedAt: Date(timeIntervalSince1970: 0),
                    reason: "   "
                )
            )
        )
        Issue.record("Expected invalid confirmation rejection")
    } catch let error as AgentToolExecutionError {
        #expect(error == .invalidConfirmation("ledger.apply_draft_entry"))
    }
    #expect(probe.didRun == false)

    do {
        _ = try executor.execute(
            AgentToolInvocation(
                toolName: "ledger.apply_draft_entry",
                inputJSON: approvedInput,
                grantedScopes: [.ledgerWrite],
                confirmation: AgentToolConfirmation(
                    toolName: "ledger.apply_draft_entry",
                    approvedInputHash: AgentToolInputHash.hash(Data(#"{"entry":"different"}"#.utf8)),
                    approvedBy: "reviewer",
                    approvedAt: Date(timeIntervalSince1970: 0),
                    reason: "Reviewed draft entry and source receipt."
                )
            )
        )
        Issue.record("Expected input hash mismatch rejection")
    } catch let error as AgentToolExecutionError {
        #expect(error == .invalidConfirmation("ledger.apply_draft_entry"))
    }
    #expect(probe.didRun == false)

    let invocation = AgentToolInvocation(
        toolName: "ledger.apply_draft_entry",
        inputJSON: approvedInput,
        grantedScopes: [.ledgerWrite]
    )
    let result = try executor.execute(
        AgentToolInvocation(
            toolName: invocation.toolName,
            inputJSON: invocation.inputJSON,
            grantedScopes: invocation.grantedScopes,
            confirmation: AgentToolConfirmation.approving(
                invocation: invocation,
                approvedBy: "reviewer",
                approvedAt: Date(timeIntervalSince1970: 0),
                reason: "Reviewed draft entry and source receipt."
            )
        )
    )

    #expect(probe.didRun)
    #expect(result.provenanceRefs == [ObjectRef(kind: .journalEntry, id: "entry-1")])
}

@Test
func agentToolExecutorRejectsResultsWithoutRequiredProvenance() throws {
    let executor = AgentToolExecutor(
        registry: .productionDefaults,
        handlers: [
            "finance.account_summary": { _ in
                AgentToolExecutionResult(
                    outputJSON: Data(#"{"balanceMinor":1000}"#.utf8),
                    provenanceRefs: []
                )
            },
        ]
    )

    do {
        _ = try executor.execute(
            AgentToolInvocation(
                toolName: "finance.account_summary",
                grantedScopes: [.financeRead]
            )
        )
        Issue.record("Expected missing provenance rejection")
    } catch let error as AgentToolExecutionError {
        #expect(error == .missingResultProvenance("finance.account_summary"))
    }
}

@Test
func agentToolExecutorRejectsUnsafeRegistryBeforeRunningHandlers() throws {
    let probe = AgentToolHandlerProbe()
    let unsafeRegistry = AgentToolRegistry(
        tools: [
            AgentToolDefinition(
                name: "debug.raw_sql",
                sideEffect: .readOnly,
                requiredScopes: [.financeRead],
                returnsProvenance: true,
                requiresUserConfirmation: false,
                allowsRawSQL: true
            ),
        ]
    )
    let executor = AgentToolExecutor(
        registry: unsafeRegistry,
        handlers: [
            "debug.raw_sql": { _ in
                probe.didRun = true
                return AgentToolExecutionResult(
                    provenanceRefs: [ObjectRef(kind: .workspace, id: "workspace-1")]
                )
            },
        ]
    )

    do {
        _ = try executor.execute(
            AgentToolInvocation(
                toolName: "debug.raw_sql",
                grantedScopes: [.financeRead]
            )
        )
        Issue.record("Expected unsafe registry rejection")
    } catch let error as AgentToolExecutionError {
        #expect(error == .unsafeRegistry([.rawSQLAllowed("debug.raw_sql")]))
    }
    #expect(probe.didRun == false)
}

private final class AgentToolHandlerProbe: @unchecked Sendable {
    var didRun = false
}
