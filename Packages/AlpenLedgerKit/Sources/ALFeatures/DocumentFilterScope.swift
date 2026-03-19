import ALDomain

public enum DocumentFilterScope: String, CaseIterable, Hashable, Sendable, Identifiable {
    case all
    case receiptsAndInvoices
    case statements
    case certificates

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .all:
            return "All"
        case .receiptsAndInvoices:
            return "Receipts"
        case .statements:
            return "Statements"
        case .certificates:
            return "Certificates"
        }
    }

    public func matches(_ document: Document) -> Bool {
        switch self {
        case .all:
            return true
        case .receiptsAndInvoices:
            return document.documentType == .receipt || document.documentType == .invoice
        case .statements:
            return document.documentType == .bankStatement
        case .certificates:
            return document.documentType == .salaryCertificate
                || document.documentType == .healthInsuranceCertificate
                || document.documentType == .pillar3aCertificate
        }
    }
}
