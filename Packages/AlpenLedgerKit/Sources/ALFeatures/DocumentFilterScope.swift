import ALDomain

public enum DocumentFilterScope: String, CaseIterable, Hashable, Sendable, Identifiable {
    case all
    case receiptsAndInvoices
    case statements
    case certificates
    case archived

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
        case .archived:
            return "Archived"
        }
    }

    public func matches(_ document: Document) -> Bool {
        switch self {
        case .all:
            return document.status == .active
        case .receiptsAndInvoices:
            return document.status == .active &&
                (document.documentType == .receipt || document.documentType == .invoice)
        case .statements:
            return document.status == .active && document.documentType == .bankStatement
        case .certificates:
            return document.status == .active && (document.documentType == .salaryCertificate
                || document.documentType == .healthInsuranceCertificate
                || document.documentType == .pillar3aCertificate
                || document.documentType == .eCH0196TaxStatement
                || document.documentType == .eCH0248PensionCertificate
                || document.documentType == .eCH0275HealthInsuranceCertificate)
        case .archived:
            return document.status == .archived
        }
    }
}
