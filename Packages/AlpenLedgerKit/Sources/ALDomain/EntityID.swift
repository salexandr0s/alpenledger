import Foundation

public struct EntityID<Tag>: Hashable, Codable, Sendable, RawRepresentable, CustomStringConvertible {
    public let rawValue: UUID

    public init(rawValue: UUID) {
        self.rawValue = rawValue
    }

    public init() {
        self.rawValue = UUID()
    }

    public var description: String {
        rawValue.uuidString.lowercased()
    }
}

public enum WorkspaceTag: Sendable {}
public enum LegalEntityTag: Sendable {}
public enum TaxYearTag: Sendable {}
public enum LedgerAccountTag: Sendable {}
public enum FinancialAccountTag: Sendable {}
public enum CounterpartyTag: Sendable {}
public enum ImportJobTag: Sendable {}
public enum ImportDiagnosticTag: Sendable {}
public enum StatementImportTag: Sendable {}
public enum TransactionTag: Sendable {}
public enum JournalEntryTag: Sendable {}
public enum JournalLineTag: Sendable {}
public enum DocumentTag: Sendable {}
public enum EvidenceLinkTag: Sendable {}
public enum AuditEventTag: Sendable {}
public enum RequirementTag: Sendable {}
public enum IssueTag: Sendable {}
public enum TaxFactTag: Sendable {}
public enum FilingPackageTag: Sendable {}
public enum AgentProposalTag: Sendable {}
public enum AgentConversationTag: Sendable {}
public enum AgentMessageTag: Sendable {}
public enum AgentPendingApprovalTag: Sendable {}
public enum AgentRunTag: Sendable {}
public enum EntityWorkspaceTag: Sendable {}
public enum TaxProfileTag: Sendable {}
public enum TransactionCategoryTag: Sendable {}
public enum InvoiceRecordTag: Sendable {}
public enum VATPeriodTag: Sendable {}

public typealias WorkspaceID = EntityID<WorkspaceTag>
public typealias LegalEntityID = EntityID<LegalEntityTag>
public typealias TaxYearID = EntityID<TaxYearTag>
public typealias LedgerAccountID = EntityID<LedgerAccountTag>
public typealias FinancialAccountID = EntityID<FinancialAccountTag>
public typealias CounterpartyID = EntityID<CounterpartyTag>
public typealias ImportJobID = EntityID<ImportJobTag>
public typealias ImportDiagnosticID = EntityID<ImportDiagnosticTag>
public typealias StatementImportID = EntityID<StatementImportTag>
public typealias TransactionID = EntityID<TransactionTag>
public typealias JournalEntryID = EntityID<JournalEntryTag>
public typealias JournalLineID = EntityID<JournalLineTag>
public typealias DocumentID = EntityID<DocumentTag>
public typealias EvidenceLinkID = EntityID<EvidenceLinkTag>
public typealias AuditEventID = EntityID<AuditEventTag>
public typealias RequirementID = EntityID<RequirementTag>
public typealias IssueID = EntityID<IssueTag>
public typealias TaxFactID = EntityID<TaxFactTag>
public typealias FilingPackageID = EntityID<FilingPackageTag>
public typealias AgentProposalID = EntityID<AgentProposalTag>
public typealias AgentConversationID = EntityID<AgentConversationTag>
public typealias AgentMessageID = EntityID<AgentMessageTag>
public typealias AgentPendingApprovalID = EntityID<AgentPendingApprovalTag>
public typealias AgentRunID = EntityID<AgentRunTag>
public typealias EntityWorkspaceID = EntityID<EntityWorkspaceTag>
public typealias TaxProfileID = EntityID<TaxProfileTag>
public typealias TransactionCategoryID = EntityID<TransactionCategoryTag>
public typealias InvoiceRecordID = EntityID<InvoiceRecordTag>
public typealias VATPeriodID = EntityID<VATPeriodTag>
