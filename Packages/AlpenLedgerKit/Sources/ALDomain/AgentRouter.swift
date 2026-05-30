import Foundation

public enum AgentSpecialist: String, Codable, CaseIterable, Sendable {
    case intakeTriage
    case documentExtraction
    case transactionClassification
    case reconciliation
    case missingEvidence
    case personalTax
    case vat
    case businessYearEnd
    case filingPackager
    case cfoQA
    case explainabilityAudit
}

public enum AgentIntent: String, Codable, CaseIterable, Sendable {
    case documentIntake
    case transactionClassification
    case reconciliationReview
    case missingTaxEvidence
    case businessExpensesWithoutInvoices
    case vatExplanation
    case businessTaxExport
    case provenanceExplanation
    case generalFinanceQuestion
    case unsupported
}

public struct AgentRouterContext: Hashable, Codable, Sendable {
    public let workspaceId: WorkspaceID?
    public let activeEntityId: LegalEntityID?
    public let activeTaxYearId: TaxYearID?
    public let canton: CantonCode?

    public init(
        workspaceId: WorkspaceID? = nil,
        activeEntityId: LegalEntityID? = nil,
        activeTaxYearId: TaxYearID? = nil,
        canton: CantonCode? = nil
    ) {
        self.workspaceId = workspaceId
        self.activeEntityId = activeEntityId
        self.activeTaxYearId = activeTaxYearId
        self.canton = canton
    }

    public var objectRefs: [ObjectRef] {
        var refs: [ObjectRef] = []
        if let workspaceId {
            refs.append(ObjectRef(kind: .workspace, id: workspaceId.rawValue))
        }
        if let activeEntityId {
            refs.append(ObjectRef(kind: .legalEntity, id: activeEntityId.rawValue))
        }
        if let activeTaxYearId {
            refs.append(ObjectRef(kind: .taxYear, id: activeTaxYearId.rawValue))
        }
        return refs
    }
}

public struct AgentExecutionPlan: Hashable, Codable, Sendable {
    public let intent: AgentIntent
    public let specialists: [AgentSpecialist]
    public let toolNames: [String]
    public let unavailableToolNames: [String]
    public let requiredScopes: [AgentToolScope]
    public let contextRefs: [ObjectRef]
    public let clarificationQuestion: String?
    public let rationale: String

    public init(
        intent: AgentIntent,
        specialists: [AgentSpecialist],
        toolNames: [String],
        unavailableToolNames: [String] = [],
        requiredScopes: [AgentToolScope],
        contextRefs: [ObjectRef],
        clarificationQuestion: String? = nil,
        rationale: String
    ) {
        self.intent = intent
        self.specialists = specialists
        self.toolNames = toolNames
        self.unavailableToolNames = unavailableToolNames
        self.requiredScopes = requiredScopes
        self.contextRefs = contextRefs
        self.clarificationQuestion = clarificationQuestion
        self.rationale = rationale
    }

    public var needsClarification: Bool {
        clarificationQuestion != nil
    }
}

public struct AgentRouter: Sendable {
    private let toolRegistry: AgentToolRegistry
    private let availableSpecialists: Set<AgentSpecialist>

    public init(
        toolRegistry: AgentToolRegistry = .productionDefaults,
        availableSpecialists: Set<AgentSpecialist> = Set(AgentSpecialist.allCases)
    ) {
        self.toolRegistry = toolRegistry
        self.availableSpecialists = availableSpecialists
    }

    public func plan(
        for userMessage: String,
        context: AgentRouterContext = AgentRouterContext()
    ) -> AgentExecutionPlan {
        let normalizedMessage = userMessage.normalizedForAgentRouting
        let intent = classifyIntent(normalizedMessage)
        let requestedSpecialists = specialists(for: intent)
        let requestedTools = toolNames(for: intent)
        let knownTools = requestedTools.filter { toolRegistry.definition(named: $0) != nil }
        let unavailableTools = requestedTools.filter { toolRegistry.definition(named: $0) == nil }
        let specialists = requestedSpecialists.filter { availableSpecialists.contains($0) }
        let scopes = requiredScopes(for: knownTools)
        let clarificationQuestion = clarificationQuestion(
            for: intent,
            context: context,
            plannedTools: knownTools
        )

        return AgentExecutionPlan(
            intent: intent,
            specialists: specialists,
            toolNames: knownTools,
            unavailableToolNames: unavailableTools,
            requiredScopes: scopes,
            contextRefs: context.objectRefs,
            clarificationQuestion: clarificationQuestion,
            rationale: rationale(for: intent, normalizedMessage: normalizedMessage)
        )
    }

    private func classifyIntent(_ normalizedMessage: String) -> AgentIntent {
        if normalizedMessage.containsAny(of: ["unsupported raw sql", "run shell", "delete database"]) {
            return .unsupported
        }
        if normalizedMessage.containsAny(of: ["why", "explain", "where did", "where is", "who approved", "audit trail"]) &&
            normalizedMessage.containsAny(of: ["tax fact", "value", "number", "entry", "document", "transaction", "proposal"]) {
            return .provenanceExplanation
        }
        if normalizedMessage.containsAny(of: ["vat", "mwst", "tva"]) &&
            normalizedMessage.containsAny(of: ["high", "why", "due", "quarter", "payable", "receivable"]) {
            return .vatExplanation
        }
        if normalizedMessage.containsAny(of: ["corporate tax export", "business tax export", "prepare my corporate", "prepare my business tax", "year end", "year-end"]) {
            return .businessTaxExport
        }
        if normalizedMessage.containsAny(of: ["expense", "expenses", "receipt", "invoice", "invoices"]) &&
            normalizedMessage.containsAny(of: ["lack", "missing", "without", "unmatched", "no invoice", "no receipt"]) {
            return .businessExpensesWithoutInvoices
        }
        if normalizedMessage.containsAny(of: ["missing", "ready", "readiness", "blocker", "blockers", "checklist"]) &&
            normalizedMessage.containsAny(of: ["tax", "return", "filing", "canton", "zurich", "zuerich"]) {
            return .missingTaxEvidence
        }
        if normalizedMessage.containsAny(of: ["reconcile", "match", "duplicate", "statement gap", "transfer"]) {
            return .reconciliationReview
        }
        if normalizedMessage.containsAny(of: ["categorize", "classify transaction", "map transaction", "account mapping"]) {
            return .transactionClassification
        }
        if normalizedMessage.containsAny(of: ["import", "upload", "scan", "ocr", "extract document", "new file"]) {
            return .documentIntake
        }
        if normalizedMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .unsupported
        }
        return .generalFinanceQuestion
    }

    private func specialists(for intent: AgentIntent) -> [AgentSpecialist] {
        switch intent {
        case .documentIntake:
            [.intakeTriage, .documentExtraction]
        case .transactionClassification:
            [.transactionClassification]
        case .reconciliationReview:
            [.reconciliation, .missingEvidence]
        case .missingTaxEvidence:
            [.personalTax, .missingEvidence]
        case .businessExpensesWithoutInvoices:
            [.cfoQA, .missingEvidence]
        case .vatExplanation:
            [.vat, .cfoQA]
        case .businessTaxExport:
            [.businessYearEnd, .filingPackager]
        case .provenanceExplanation:
            [.explainabilityAudit]
        case .generalFinanceQuestion:
            [.cfoQA]
        case .unsupported:
            []
        }
    }

    private func toolNames(for intent: AgentIntent) -> [String] {
        switch intent {
        case .documentIntake:
            ["docs.search", "docs.get_summary", "issues.open_or_update"]
        case .transactionClassification:
            ["finance.search_transactions", "ledger.propose_mapping"]
        case .reconciliationReview:
            ["reconcile.statement_coverage", "finance.search_transactions", "docs.search", "issues.list_open"]
        case .missingTaxEvidence:
            ["tax.list_requirements", "tax.preview_status", "reconcile.statement_coverage", "issues.list_open"]
        case .businessExpensesWithoutInvoices:
            ["finance.search_transactions", "docs.search", "issues.list_open"]
        case .vatExplanation:
            ["tax.preview_status", "finance.search_transactions", "issues.list_open", "exports.validate"]
        case .businessTaxExport:
            ["issues.list_open", "tax.preview_status", "exports.validate", "exports.generate_package"]
        case .provenanceExplanation:
            ["audit.trace_object", "tax.explain_fact"]
        case .generalFinanceQuestion:
            ["finance.account_summary", "finance.search_transactions", "docs.search", "issues.list_open"]
        case .unsupported:
            []
        }
    }

    private func requiredScopes(for toolNames: [String]) -> [AgentToolScope] {
        var scopes: [AgentToolScope] = []
        var seenScopes = Set<AgentToolScope>()

        for toolName in toolNames {
            guard let definition = toolRegistry.definition(named: toolName) else {
                continue
            }
            for scope in definition.requiredScopes.sorted(by: { $0.rawValue < $1.rawValue }) where seenScopes.insert(scope).inserted {
                scopes.append(scope)
            }
        }

        return scopes
    }

    private func clarificationQuestion(
        for intent: AgentIntent,
        context: AgentRouterContext,
        plannedTools: [String]
    ) -> String? {
        guard intent != .unsupported else {
            return "What finance, document, tax, or reconciliation question should I route?"
        }

        let requiresEntity = plannedTools.contains { toolName in
            guard let definition = toolRegistry.definition(named: toolName) else {
                return false
            }
            return definition.requiredScopes.intersection([
                .financeRead,
                .documentsRead,
                .taxRead,
                .reconcileRead,
                .ledgerPropose,
                .docsPropose,
                .taxPropose,
                .closingPropose,
                .exportsGenerate,
            ]).isEmpty == false
        }
        if requiresEntity && context.activeEntityId == nil {
            return "Which entity should I use for this request?"
        }

        switch intent {
        case .missingTaxEvidence, .vatExplanation, .businessTaxExport, .provenanceExplanation:
            if context.activeTaxYearId == nil {
                return "Which tax year should I use for this request?"
            }
        case .documentIntake, .transactionClassification, .reconciliationReview,
             .businessExpensesWithoutInvoices, .generalFinanceQuestion, .unsupported:
            break
        }

        return nil
    }

    private func rationale(for intent: AgentIntent, normalizedMessage: String) -> String {
        switch intent {
        case .documentIntake:
            "The request references import or document extraction, so it should start with intake and document tools."
        case .transactionClassification:
            "The request asks for transaction classification or mapping, so it should use finance lookup before proposal tools."
        case .reconciliationReview:
            "The request references matching, duplicates, transfers, or statement gaps, so it should use reconciliation and evidence lookup."
        case .missingTaxEvidence:
            "The request asks what is missing for a filing, so it should combine tax requirements, tax status, statement coverage, and open issues."
        case .businessExpensesWithoutInvoices:
            "The request asks for expenses lacking evidence, so it should compare finance transactions, documents, and open issues."
        case .vatExplanation:
            "The request asks about VAT movement, so it should inspect tax status, finance activity, validation issues, and open issues."
        case .businessTaxExport:
            "The request asks for a business or corporate tax export, so it should check blockers before generating any draft package."
        case .provenanceExplanation:
            "The request asks why a value exists or who approved it, so it should use audit and explanation tools."
        case .generalFinanceQuestion:
            "The request is a general finance question, so it should use read-only finance, document, and issue tools."
        case .unsupported:
            normalizedMessage.isEmpty
                ? "The message is empty."
                : "The request asks for an unsafe or unsupported action and should not be routed to a mutating tool."
        }
    }
}

private extension String {
    var normalizedForAgentRouting: String {
        folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .lowercased()
    }

    func containsAny(of needles: [String]) -> Bool {
        needles.contains { contains($0) }
    }
}
