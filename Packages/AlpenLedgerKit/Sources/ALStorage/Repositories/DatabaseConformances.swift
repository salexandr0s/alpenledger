import Foundation
import GRDB
import ALDomain

extension EntityID: DatabaseValueConvertible {
    public var databaseValue: DatabaseValue {
        description.databaseValue
    }

    public static func fromDatabaseValue(_ dbValue: DatabaseValue) -> Self? {
        guard let rawValue = String.fromDatabaseValue(dbValue), let uuid = UUID(uuidString: rawValue) else {
            return nil
        }
        return Self(rawValue: uuid)
    }
}

extension ObjectRef: DatabaseValueConvertible {
    public var databaseValue: DatabaseValue {
        stringValue.databaseValue
    }

    public static func fromDatabaseValue(_ dbValue: DatabaseValue) -> ObjectRef? {
        guard let value = String.fromDatabaseValue(dbValue) else {
            return nil
        }
        return ObjectRef.parse(value)
    }
}

extension CurrencyCode: DatabaseValueConvertible {
    public var databaseValue: DatabaseValue {
        rawValue.databaseValue
    }

    public static func fromDatabaseValue(_ dbValue: DatabaseValue) -> CurrencyCode? {
        guard let raw = String.fromDatabaseValue(dbValue) else { return nil }
        return CurrencyCode(rawValue: raw)
    }
}

extension CantonCode: DatabaseValueConvertible {
    public var databaseValue: DatabaseValue {
        rawValue.databaseValue
    }

    public static func fromDatabaseValue(_ dbValue: DatabaseValue) -> CantonCode? {
        guard let raw = String.fromDatabaseValue(dbValue) else { return nil }
        return CantonCode(rawValue: raw)
    }
}

extension Workspace: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "workspaces"
}
extension LegalEntity: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "legalEntities"
}
extension TaxYear: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "taxYears"
}
extension VATPeriod: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "vatPeriods"
}
extension LedgerAccount: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "ledgerAccounts"
}
extension FinancialAccount: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "financialAccounts"
}
extension Counterparty: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "counterparties"
}
extension ImportJob: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "importJobs"
}
extension ImportDiagnostic: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "importDiagnostics"
}
extension StatementImport: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "statementImports"
}
extension Transaction: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "transactions"
}
extension Document: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "documents"
}
extension EvidenceLink: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "evidenceLinks"
}
extension Requirement: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "requirements"
}
extension Issue: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "issues"
}
extension AgentProposal: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "agentProposals"

    public init(row: Row) {
        self.init(
            id: row["id"],
            fingerprint: row["fingerprint"],
            workspaceId: row["workspaceId"],
            agentKind: AgentKind(rawValue: row["agentKind"]) ?? .systemHeuristics,
            proposalType: ProposalType(rawValue: row["proposalType"]) ?? .documentLinkReview,
            targetRef: row["targetRef"],
            relatedRef: row["relatedRef"],
            summary: row["summary"],
            rationale: row["rationale"],
            confidence: row["confidence"],
            missingFields: AgentProposal.decodeMissingFields(from: row["missingFields"]),
            question: row["question"],
            requiresManualReview: row["requiresManualReview"] ?? false,
            status: ProposalStatus(rawValue: row["status"]) ?? .pending,
            createdAt: row["createdAt"],
            decidedAt: row["decidedAt"],
            decidedBy: row["decidedBy"],
            decisionReason: row["decisionReason"]
        )
    }

    public func encode(to container: inout PersistenceContainer) {
        container["id"] = id
        container["fingerprint"] = fingerprint
        container["workspaceId"] = workspaceId
        container["agentKind"] = agentKind.rawValue
        container["proposalType"] = proposalType.rawValue
        container["targetRef"] = targetRef
        container["relatedRef"] = relatedRef
        container["summary"] = summary
        container["rationale"] = rationale
        container["confidence"] = confidence
        container["missingFields"] = AgentProposal.encodeMissingFields(missingFields)
        container["question"] = question
        container["requiresManualReview"] = requiresManualReview
        container["status"] = status.rawValue
        container["createdAt"] = createdAt
        container["decidedAt"] = decidedAt
        container["decidedBy"] = decidedBy
        container["decisionReason"] = decisionReason
    }

    private static func encodeMissingFields(_ missingFields: [String]) -> String {
        guard let data = try? JSONEncoder.alpenLedger.encode(missingFields),
              let string = String(data: data, encoding: .utf8)
        else {
            return "[]"
        }
        return string
    }

    private static func decodeMissingFields(from rawValue: String?) -> [String] {
        guard let rawValue,
              let data = rawValue.data(using: .utf8),
              let fields = try? JSONDecoder.alpenLedger.decode([String].self, from: data)
        else {
            return []
        }
        return fields
    }
}

extension AgentConversation: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "agentConversations"

    public init(row: Row) {
        self.init(
            id: row["id"],
            workspaceId: row["workspaceId"],
            title: row["title"],
            activeEntityId: row["activeEntityId"],
            activeTaxYearId: row["activeTaxYearId"],
            status: AgentConversationStatus(rawValue: row["status"]) ?? .active,
            createdAt: row["createdAt"],
            updatedAt: row["updatedAt"]
        )
    }

    public func encode(to container: inout PersistenceContainer) {
        container["id"] = id
        container["workspaceId"] = workspaceId
        container["title"] = title
        container["activeEntityId"] = activeEntityId
        container["activeTaxYearId"] = activeTaxYearId
        container["status"] = status.rawValue
        container["createdAt"] = createdAt
        container["updatedAt"] = updatedAt
    }
}

extension AgentMessage: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "agentMessages"

    public init(row: Row) {
        self.init(
            id: row["id"],
            conversationId: row["conversationId"],
            role: AgentMessageRole(rawValue: row["role"]) ?? .assistant,
            content: row["content"],
            sourceRefs: AgentStorageJSON.decodeObjectRefs(from: row["sourceRefs"]),
            unresolvedQuestions: AgentStorageJSON.decodeStrings(from: row["unresolvedQuestions"]),
            providerID: row["providerID"],
            promptTemplateID: row["promptTemplateID"],
            sentDataOffDevice: row["sentDataOffDevice"] ?? false,
            createdAt: row["createdAt"]
        )
    }

    public func encode(to container: inout PersistenceContainer) {
        container["id"] = id
        container["conversationId"] = conversationId
        container["role"] = role.rawValue
        container["content"] = content
        container["sourceRefs"] = AgentStorageJSON.encodeObjectRefs(sourceRefs)
        container["unresolvedQuestions"] = AgentStorageJSON.encodeStrings(unresolvedQuestions)
        container["providerID"] = providerID
        container["promptTemplateID"] = promptTemplateID
        container["sentDataOffDevice"] = sentDataOffDevice
        container["createdAt"] = createdAt
    }
}

extension AgentRunTrace: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "agentRuns"

    public init(row: Row) {
        self.init(
            id: row["id"],
            conversationId: row["conversationId"],
            userMessageId: row["userMessageId"],
            assistantMessageId: row["assistantMessageId"],
            status: AgentRunStatus(rawValue: row["status"]) ?? .planned,
            intent: AgentIntent(rawValue: row["intent"]) ?? .unsupported,
            specialists: AgentStorageJSON.decodeSpecialists(from: row["specialists"]),
            plannedToolNames: AgentStorageJSON.decodeStrings(from: row["plannedToolNames"]),
            unavailableToolNames: AgentStorageJSON.decodeStrings(from: row["unavailableToolNames"]),
            requiredScopes: AgentStorageJSON.decodeScopes(from: row["requiredScopes"]),
            contextRefs: AgentStorageJSON.decodeObjectRefs(from: row["contextRefs"]),
            clarificationQuestion: row["clarificationQuestion"],
            rationale: row["rationale"],
            modelProviderID: row["modelProviderID"],
            modelCapability: {
                guard let rawValue: String = row["modelCapability"] else { return nil }
                return ModelProviderCapability(rawValue: rawValue)
            }(),
            promptTemplateID: row["promptTemplateID"],
            modelInputScope: {
                guard let rawValue: String = row["modelInputScope"] else { return nil }
                return ModelProviderInputScope(rawValue: rawValue)
            }(),
            sentDataOffDevice: row["sentDataOffDevice"] ?? false,
            toolCalls: AgentStorageJSON.decodeToolCalls(from: row["toolCalls"]),
            approvalDecisions: AgentStorageJSON.decodeApprovalDecisions(from: row["approvalDecisions"]),
            errorCode: row["errorCode"],
            startedAt: row["startedAt"],
            finishedAt: row["finishedAt"]
        )
    }

    public func encode(to container: inout PersistenceContainer) {
        container["id"] = id
        container["conversationId"] = conversationId
        container["userMessageId"] = userMessageId
        container["assistantMessageId"] = assistantMessageId
        container["status"] = status.rawValue
        container["intent"] = intent.rawValue
        container["specialists"] = AgentStorageJSON.encodeSpecialists(specialists)
        container["plannedToolNames"] = AgentStorageJSON.encodeStrings(plannedToolNames)
        container["unavailableToolNames"] = AgentStorageJSON.encodeStrings(unavailableToolNames)
        container["requiredScopes"] = AgentStorageJSON.encodeScopes(requiredScopes)
        container["contextRefs"] = AgentStorageJSON.encodeObjectRefs(contextRefs)
        container["clarificationQuestion"] = clarificationQuestion
        container["rationale"] = rationale
        container["modelProviderID"] = modelProviderID
        container["modelCapability"] = modelCapability?.rawValue
        container["promptTemplateID"] = promptTemplateID
        container["modelInputScope"] = modelInputScope?.rawValue
        container["sentDataOffDevice"] = sentDataOffDevice
        container["toolCalls"] = AgentStorageJSON.encodeToolCalls(toolCalls)
        container["approvalDecisions"] = AgentStorageJSON.encodeApprovalDecisions(approvalDecisions)
        container["errorCode"] = errorCode
        container["startedAt"] = startedAt
        container["finishedAt"] = finishedAt
    }
}

extension AgentPendingApproval: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "agentPendingApprovals"

    public init(row: Row) {
        self.init(
            id: row["id"],
            conversationId: row["conversationId"],
            toolName: row["toolName"],
            inputHash: row["inputHash"],
            inputSummary: row["inputSummary"],
            requiredScopes: AgentStorageJSON.decodeScopes(from: row["requiredScopes"]),
            targetRefs: AgentStorageJSON.decodeObjectRefs(from: row["targetRefs"]),
            status: AgentPendingApprovalStatus(rawValue: row["status"]) ?? .pending,
            requestedBy: row["requestedBy"],
            requestedAt: row["requestedAt"],
            decidedBy: row["decidedBy"],
            decidedAt: row["decidedAt"],
            decisionReason: row["decisionReason"]
        )
    }

    public func encode(to container: inout PersistenceContainer) {
        container["id"] = id
        container["conversationId"] = conversationId
        container["toolName"] = toolName
        container["inputHash"] = inputHash
        container["inputSummary"] = inputSummary
        container["requiredScopes"] = AgentStorageJSON.encodeScopes(requiredScopes)
        container["targetRefs"] = AgentStorageJSON.encodeObjectRefs(targetRefs)
        container["status"] = status.rawValue
        container["requestedBy"] = requestedBy
        container["requestedAt"] = requestedAt
        container["decidedBy"] = decidedBy
        container["decidedAt"] = decidedAt
        container["decisionReason"] = decisionReason
    }
}

private enum AgentStorageJSON {
    static func encodeObjectRefs(_ refs: [ObjectRef]) -> String {
        encode(refs)
    }

    static func decodeObjectRefs(from rawValue: String?) -> [ObjectRef] {
        decode([ObjectRef].self, from: rawValue) ?? []
    }

    static func encodeStrings(_ values: [String]) -> String {
        encode(values)
    }

    static func decodeStrings(from rawValue: String?) -> [String] {
        decode([String].self, from: rawValue) ?? []
    }

    static func encodeScopes(_ values: [AgentToolScope]) -> String {
        encode(values)
    }

    static func decodeScopes(from rawValue: String?) -> [AgentToolScope] {
        decode([AgentToolScope].self, from: rawValue) ?? []
    }

    static func encodeSpecialists(_ values: [AgentSpecialist]) -> String {
        encode(values)
    }

    static func decodeSpecialists(from rawValue: String?) -> [AgentSpecialist] {
        decode([AgentSpecialist].self, from: rawValue) ?? []
    }

    static func encodeToolCalls(_ values: [AgentRunToolCall]) -> String {
        encode(values)
    }

    static func decodeToolCalls(from rawValue: String?) -> [AgentRunToolCall] {
        decode([AgentRunToolCall].self, from: rawValue) ?? []
    }

    static func encodeApprovalDecisions(_ values: [AgentRunApprovalDecision]) -> String {
        encode(values)
    }

    static func decodeApprovalDecisions(from rawValue: String?) -> [AgentRunApprovalDecision] {
        decode([AgentRunApprovalDecision].self, from: rawValue) ?? []
    }

    private static func encode<T: Encodable>(_ value: T) -> String {
        guard let data = try? JSONEncoder.alpenLedger.encode(value),
              let string = String(data: data, encoding: .utf8)
        else {
            return "[]"
        }
        return string
    }

    private static func decode<T: Decodable>(_ type: T.Type, from rawValue: String?) -> T? {
        guard let rawValue,
              let data = rawValue.data(using: .utf8)
        else {
            return nil
        }
        return try? JSONDecoder.alpenLedger.decode(type, from: data)
    }
}

extension AuditEvent: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "auditEvents"
}

extension EntityWorkspace: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "entityWorkspaces"
}
extension TaxProfile: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "taxProfiles"
}
extension TransactionCategory: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "categories"
}
extension InvoiceRecord: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "invoiceRecords"
}
extension FilingPackage: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "filingPackages"
}

extension TaxFact: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "taxFacts"

    public init(row: Row) {
        self.init(
            id: row["id"],
            fingerprint: row["fingerprint"],
            entityId: row["entityId"],
            taxYearId: row["taxYearId"],
            jurisdictionCode: row["jurisdictionCode"],
            conceptCode: row["conceptCode"],
            valueType: TaxFactValueType(rawValue: row["valueType"]) ?? .text,
            moneyMinor: row["moneyMinor"],
            textValue: row["textValue"],
            boolValue: row["boolValue"],
            dateValue: row["dateValue"],
            currency: {
                guard let raw: String = row["currency"] else { return nil }
                return CurrencyCode(rawValue: raw)
            }(),
            status: TaxFactStatus(rawValue: row["status"]) ?? .derived,
            rulesetVersion: row["rulesetVersion"],
            provenanceRefs: TaxFact.decodeProvenanceRefs(from: row["provenanceRefs"]),
            confidence: row["confidence"],
            supersedesFactId: row["supersedesFactId"],
            isCurrent: row["isCurrent"],
            overrideReason: row["overrideReason"],
            createdAt: row["createdAt"],
            updatedAt: row["updatedAt"]
        )
    }

    public func encode(to container: inout PersistenceContainer) {
        container["id"] = id
        container["fingerprint"] = fingerprint
        container["entityId"] = entityId
        container["taxYearId"] = taxYearId
        container["jurisdictionCode"] = jurisdictionCode
        container["conceptCode"] = conceptCode
        container["valueType"] = valueType.rawValue
        container["moneyMinor"] = moneyMinor
        container["textValue"] = textValue
        container["boolValue"] = boolValue
        container["dateValue"] = dateValue
        container["currency"] = currency?.rawValue
        container["status"] = status.rawValue
        container["rulesetVersion"] = rulesetVersion
        container["provenanceRefs"] = TaxFact.encodeProvenanceRefs(provenanceRefs)
        container["confidence"] = confidence
        container["supersedesFactId"] = supersedesFactId
        container["isCurrent"] = isCurrent
        container["overrideReason"] = overrideReason
        container["createdAt"] = createdAt
        container["updatedAt"] = updatedAt
    }

    private static func encodeProvenanceRefs(_ refs: [ObjectRef]) -> String {
        guard let data = try? JSONEncoder.alpenLedger.encode(refs),
              let string = String(data: data, encoding: .utf8)
        else {
            return "[]"
        }
        return string
    }

    private static func decodeProvenanceRefs(from rawValue: String?) -> [ObjectRef] {
        guard let rawValue,
              let data = rawValue.data(using: .utf8),
              let refs = try? JSONDecoder.alpenLedger.decode([ObjectRef].self, from: data)
        else {
            return []
        }
        return refs
    }
}
