import Foundation

public enum InvoiceDirection: String, Codable, CaseIterable, Sendable {
    case receivable
    case payable
}

public enum InvoiceStatus: String, Codable, CaseIterable, Sendable {
    case draft
    case sent
    case paid
    case overdue
    case cancelled
}

public struct InvoiceRecord: Hashable, Codable, Sendable {
    public let id: InvoiceRecordID
    public let documentId: DocumentID
    public let entityId: LegalEntityID
    public var invoiceNumber: String?
    public var counterpartyName: String
    public var issueDate: Date?
    public var dueDate: Date?
    public var totalAmountMinor: Int64
    public var currency: CurrencyCode
    public var direction: InvoiceDirection
    public var status: InvoiceStatus
    public var linkedTransactionId: TransactionID?
    public let createdAt: Date
    public var updatedAt: Date

    public init(
        id: InvoiceRecordID = InvoiceRecordID(),
        documentId: DocumentID,
        entityId: LegalEntityID,
        invoiceNumber: String? = nil,
        counterpartyName: String,
        issueDate: Date? = nil,
        dueDate: Date? = nil,
        totalAmountMinor: Int64,
        currency: CurrencyCode,
        direction: InvoiceDirection,
        status: InvoiceStatus = .draft,
        linkedTransactionId: TransactionID? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.documentId = documentId
        self.entityId = entityId
        self.invoiceNumber = invoiceNumber
        self.counterpartyName = counterpartyName
        self.issueDate = issueDate
        self.dueDate = dueDate
        self.totalAmountMinor = totalAmountMinor
        self.currency = currency
        self.direction = direction
        self.status = status
        self.linkedTransactionId = linkedTransactionId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
