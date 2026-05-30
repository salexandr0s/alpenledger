import Foundation
import CryptoKit

public enum AgentToolSideEffect: String, Codable, CaseIterable, Sendable {
    case readOnly
    case proposal
    case issueUpdate
    case draftArtifact
    case confirmedWrite
}

public enum AgentToolScope: String, Codable, CaseIterable, Sendable {
    case financeRead
    case documentsRead
    case taxRead
    case reconcileRead
    case auditRead
    case issuesWrite
    case ledgerPropose
    case docsPropose
    case taxPropose
    case closingPropose
    case exportsGenerate
    case ledgerWrite
    case entityWrite
    case rulesWrite
}

public struct AgentToolDefinition: Hashable, Codable, Sendable {
    public let name: String
    public let sideEffect: AgentToolSideEffect
    public let requiredScopes: Set<AgentToolScope>
    public let returnsProvenance: Bool
    public let requiresUserConfirmation: Bool
    public let allowsUnrestrictedFileAccess: Bool
    public let allowsRawSQL: Bool
    public let allowsShellExecution: Bool

    public init(
        name: String,
        sideEffect: AgentToolSideEffect,
        requiredScopes: Set<AgentToolScope>,
        returnsProvenance: Bool,
        requiresUserConfirmation: Bool,
        allowsUnrestrictedFileAccess: Bool = false,
        allowsRawSQL: Bool = false,
        allowsShellExecution: Bool = false
    ) {
        self.name = name
        self.sideEffect = sideEffect
        self.requiredScopes = requiredScopes
        self.returnsProvenance = returnsProvenance
        self.requiresUserConfirmation = requiresUserConfirmation
        self.allowsUnrestrictedFileAccess = allowsUnrestrictedFileAccess
        self.allowsRawSQL = allowsRawSQL
        self.allowsShellExecution = allowsShellExecution
    }

    public var mutatesAuthoritativeData: Bool {
        sideEffect == .confirmedWrite
    }
}

public enum AgentToolPolicyViolation: Hashable, Sendable {
    case duplicateToolName(String)
    case missingScope(String)
    case missingProvenance(String)
    case confirmedWriteWithoutConfirmation(String)
    case unrestrictedFileAccessAllowed(String)
    case rawSQLAllowed(String)
    case shellExecutionAllowed(String)
}

public struct AgentToolRegistry: Hashable, Codable, Sendable {
    public let tools: [AgentToolDefinition]

    public init(tools: [AgentToolDefinition]) {
        self.tools = tools
    }

    public func definition(named name: String) -> AgentToolDefinition? {
        tools.first { $0.name == name }
    }

    public func validateSafetyPolicy() -> [AgentToolPolicyViolation] {
        var violations: [AgentToolPolicyViolation] = []
        var seenNames = Set<String>()

        for tool in tools {
            if seenNames.insert(tool.name).inserted == false {
                violations.append(.duplicateToolName(tool.name))
            }
            if tool.requiredScopes.isEmpty {
                violations.append(.missingScope(tool.name))
            }
            if tool.returnsProvenance == false {
                violations.append(.missingProvenance(tool.name))
            }
            if tool.mutatesAuthoritativeData && tool.requiresUserConfirmation == false {
                violations.append(.confirmedWriteWithoutConfirmation(tool.name))
            }
            if tool.allowsUnrestrictedFileAccess {
                violations.append(.unrestrictedFileAccessAllowed(tool.name))
            }
            if tool.allowsRawSQL {
                violations.append(.rawSQLAllowed(tool.name))
            }
            if tool.allowsShellExecution {
                violations.append(.shellExecutionAllowed(tool.name))
            }
        }

        return violations
    }

    public static let productionDefaults = AgentToolRegistry(
        tools: [
            AgentToolDefinition(
                name: "finance.list_accounts",
                sideEffect: .readOnly,
                requiredScopes: [.financeRead],
                returnsProvenance: true,
                requiresUserConfirmation: false
            ),
            AgentToolDefinition(
                name: "finance.search_transactions",
                sideEffect: .readOnly,
                requiredScopes: [.financeRead],
                returnsProvenance: true,
                requiresUserConfirmation: false
            ),
            AgentToolDefinition(
                name: "finance.account_summary",
                sideEffect: .readOnly,
                requiredScopes: [.financeRead],
                returnsProvenance: true,
                requiresUserConfirmation: false
            ),
            AgentToolDefinition(
                name: "docs.search",
                sideEffect: .readOnly,
                requiredScopes: [.documentsRead],
                returnsProvenance: true,
                requiresUserConfirmation: false
            ),
            AgentToolDefinition(
                name: "docs.get_summary",
                sideEffect: .readOnly,
                requiredScopes: [.documentsRead],
                returnsProvenance: true,
                requiresUserConfirmation: false
            ),
            AgentToolDefinition(
                name: "reconcile.statement_coverage",
                sideEffect: .readOnly,
                requiredScopes: [.reconcileRead],
                returnsProvenance: true,
                requiresUserConfirmation: false
            ),
            AgentToolDefinition(
                name: "issues.list_open",
                sideEffect: .readOnly,
                requiredScopes: [.reconcileRead],
                returnsProvenance: true,
                requiresUserConfirmation: false
            ),
            AgentToolDefinition(
                name: "tax.list_requirements",
                sideEffect: .readOnly,
                requiredScopes: [.taxRead],
                returnsProvenance: true,
                requiresUserConfirmation: false
            ),
            AgentToolDefinition(
                name: "tax.preview_status",
                sideEffect: .readOnly,
                requiredScopes: [.taxRead],
                returnsProvenance: true,
                requiresUserConfirmation: false
            ),
            AgentToolDefinition(
                name: "tax.explain_fact",
                sideEffect: .readOnly,
                requiredScopes: [.taxRead],
                returnsProvenance: true,
                requiresUserConfirmation: false
            ),
            AgentToolDefinition(
                name: "audit.trace_object",
                sideEffect: .readOnly,
                requiredScopes: [.auditRead],
                returnsProvenance: true,
                requiresUserConfirmation: false
            ),
            AgentToolDefinition(
                name: "ledger.propose_mapping",
                sideEffect: .proposal,
                requiredScopes: [.ledgerPropose],
                returnsProvenance: true,
                requiresUserConfirmation: false
            ),
            AgentToolDefinition(
                name: "ledger.propose_split",
                sideEffect: .proposal,
                requiredScopes: [.ledgerPropose],
                returnsProvenance: true,
                requiresUserConfirmation: false
            ),
            AgentToolDefinition(
                name: "docs.propose_match",
                sideEffect: .proposal,
                requiredScopes: [.docsPropose],
                returnsProvenance: true,
                requiresUserConfirmation: false
            ),
            AgentToolDefinition(
                name: "tax.propose_override_reason",
                sideEffect: .proposal,
                requiredScopes: [.taxPropose],
                returnsProvenance: true,
                requiresUserConfirmation: false
            ),
            AgentToolDefinition(
                name: "issues.open_or_update",
                sideEffect: .issueUpdate,
                requiredScopes: [.issuesWrite],
                returnsProvenance: true,
                requiresUserConfirmation: false
            ),
            AgentToolDefinition(
                name: "closing.propose_accrual",
                sideEffect: .proposal,
                requiredScopes: [.closingPropose],
                returnsProvenance: true,
                requiresUserConfirmation: false
            ),
            AgentToolDefinition(
                name: "exports.generate_package",
                sideEffect: .draftArtifact,
                requiredScopes: [.exportsGenerate],
                returnsProvenance: true,
                requiresUserConfirmation: false
            ),
            AgentToolDefinition(
                name: "exports.validate",
                sideEffect: .readOnly,
                requiredScopes: [.exportsGenerate],
                returnsProvenance: true,
                requiresUserConfirmation: false
            ),
            AgentToolDefinition(
                name: "ledger.apply_draft_entry",
                sideEffect: .confirmedWrite,
                requiredScopes: [.ledgerWrite],
                returnsProvenance: true,
                requiresUserConfirmation: true
            ),
            AgentToolDefinition(
                name: "entities.merge_counterparties",
                sideEffect: .confirmedWrite,
                requiredScopes: [.entityWrite],
                returnsProvenance: true,
                requiresUserConfirmation: true
            ),
            AgentToolDefinition(
                name: "exports.finalize_package",
                sideEffect: .confirmedWrite,
                requiredScopes: [.exportsGenerate],
                returnsProvenance: true,
                requiresUserConfirmation: true
            ),
            AgentToolDefinition(
                name: "rules.accept_override",
                sideEffect: .confirmedWrite,
                requiredScopes: [.rulesWrite],
                returnsProvenance: true,
                requiresUserConfirmation: true
            ),
        ]
    )
}

public struct AgentToolConfirmation: Hashable, Sendable {
    public let toolName: String
    public let approvedInputHash: String
    public let approvedBy: String
    public let approvedAt: Date
    public let reason: String

    public init(
        toolName: String,
        approvedInputHash: String = AgentToolInputHash.hash(Data()),
        approvedBy: String,
        approvedAt: Date,
        reason: String
    ) {
        self.toolName = toolName
        self.approvedInputHash = approvedInputHash
        self.approvedBy = approvedBy
        self.approvedAt = approvedAt
        self.reason = reason
    }

    public static func approving(
        invocation: AgentToolInvocation,
        approvedBy: String,
        approvedAt: Date,
        reason: String
    ) -> AgentToolConfirmation {
        AgentToolConfirmation(
            toolName: invocation.toolName,
            approvedInputHash: invocation.inputHash,
            approvedBy: approvedBy,
            approvedAt: approvedAt,
            reason: reason
        )
    }

    public func isExplicitApproval(for invocation: AgentToolInvocation) -> Bool {
        toolName == invocation.toolName
            && approvedInputHash == invocation.inputHash
            && approvedBy.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            && reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }
}

public enum AgentToolInputHash: Sendable {
    public static let algorithm = "sha256"

    public static func hash(_ data: Data) -> String {
        let digest = SHA256.hash(data: data)
            .map { String(format: "%02x", $0) }
            .joined()
        return "\(algorithm):\(digest)"
    }
}

public struct AgentToolInvocation: Sendable {
    public let toolName: String
    public let inputJSON: Data
    public let grantedScopes: Set<AgentToolScope>
    public let confirmation: AgentToolConfirmation?

    public init(
        toolName: String,
        inputJSON: Data = Data(),
        grantedScopes: Set<AgentToolScope>,
        confirmation: AgentToolConfirmation? = nil
    ) {
        self.toolName = toolName
        self.inputJSON = inputJSON
        self.grantedScopes = grantedScopes
        self.confirmation = confirmation
    }

    public var inputHash: String {
        AgentToolInputHash.hash(inputJSON)
    }
}

public struct AgentToolExecutionResult: Sendable {
    public let outputJSON: Data
    public let provenanceRefs: [ObjectRef]

    public init(outputJSON: Data = Data(), provenanceRefs: [ObjectRef]) {
        self.outputJSON = outputJSON
        self.provenanceRefs = provenanceRefs
    }
}

public enum AgentToolExecutionError: Error, Hashable, Sendable {
    case unsafeRegistry([AgentToolPolicyViolation])
    case unregisteredTool(String)
    case missingScopes(toolName: String, required: Set<AgentToolScope>, granted: Set<AgentToolScope>)
    case confirmationRequired(String)
    case invalidConfirmation(String)
    case missingResultProvenance(String)
}

public struct AgentToolExecutor: Sendable {
    public typealias Handler = @Sendable (AgentToolInvocation) throws -> AgentToolExecutionResult

    private let registry: AgentToolRegistry
    private let handlers: [String: Handler]

    public init(registry: AgentToolRegistry, handlers: [String: Handler]) {
        self.registry = registry
        self.handlers = handlers
    }

    public func execute(_ invocation: AgentToolInvocation) throws -> AgentToolExecutionResult {
        let violations = registry.validateSafetyPolicy()
        guard violations.isEmpty else {
            throw AgentToolExecutionError.unsafeRegistry(violations)
        }

        guard let definition = registry.definition(named: invocation.toolName),
              let handler = handlers[invocation.toolName]
        else {
            throw AgentToolExecutionError.unregisteredTool(invocation.toolName)
        }

        let missingScopes = definition.requiredScopes.subtracting(invocation.grantedScopes)
        guard missingScopes.isEmpty else {
            throw AgentToolExecutionError.missingScopes(
                toolName: invocation.toolName,
                required: definition.requiredScopes,
                granted: invocation.grantedScopes
            )
        }

        if definition.requiresUserConfirmation {
            guard let confirmation = invocation.confirmation else {
                throw AgentToolExecutionError.confirmationRequired(invocation.toolName)
            }
            guard confirmation.isExplicitApproval(for: invocation) else {
                throw AgentToolExecutionError.invalidConfirmation(invocation.toolName)
            }
        }

        let result = try handler(invocation)
        if definition.returnsProvenance && result.provenanceRefs.isEmpty {
            throw AgentToolExecutionError.missingResultProvenance(invocation.toolName)
        }

        return result
    }
}
