import Foundation

public enum DocumentOrigin: String, Codable, CaseIterable, Sendable {
    case userImport
    case importPipeline
}

public enum DocumentType: String, Codable, CaseIterable, Sendable {
    case unknown
    case receipt
    case invoice
    case qrBill
    case bankStatement
    case salaryCertificate
    case healthInsuranceCertificate
    case pillar3aCertificate
    case eCH0196TaxStatement
    case eCH0248PensionCertificate
    case eCH0275HealthInsuranceCertificate
}

public enum MetadataStatus: String, Codable, CaseIterable, Sendable {
    case proposed
    case confirmed
}

public enum DocumentStatus: String, Codable, CaseIterable, Sendable {
    case active
    case archived
}

public struct Document: Hashable, Codable, Sendable {
    public let id: DocumentID
    public let workspaceId: WorkspaceID
    public let importJobId: ImportJobID?
    public let blobHash: String
    public var originalFilename: String
    public var mediaType: String
    public var origin: DocumentOrigin
    public var documentType: DocumentType
    public var issueDate: Date?
    public let detectedEntityId: LegalEntityID?
    public var entityId: LegalEntityID?
    public let detectedTaxYearId: TaxYearID?
    public var extractedText: String?
    public var metadataStatus: MetadataStatus
    public var parseVersion: String
    public var status: DocumentStatus
    public var archivedAt: Date?
    public var archivedBy: String?
    public var archiveReason: String?

    public init(
        id: DocumentID = DocumentID(),
        workspaceId: WorkspaceID,
        importJobId: ImportJobID? = nil,
        blobHash: String,
        originalFilename: String,
        mediaType: String,
        origin: DocumentOrigin = .userImport,
        documentType: DocumentType = .unknown,
        issueDate: Date? = nil,
        detectedEntityId: LegalEntityID? = nil,
        entityId: LegalEntityID? = nil,
        detectedTaxYearId: TaxYearID? = nil,
        extractedText: String? = nil,
        metadataStatus: MetadataStatus = .proposed,
        parseVersion: String = "v1",
        status: DocumentStatus = .active,
        archivedAt: Date? = nil,
        archivedBy: String? = nil,
        archiveReason: String? = nil
    ) {
        self.id = id
        self.workspaceId = workspaceId
        self.importJobId = importJobId
        self.blobHash = blobHash
        self.originalFilename = originalFilename
        self.mediaType = mediaType
        self.origin = origin
        self.documentType = documentType
        self.issueDate = issueDate
        self.detectedEntityId = detectedEntityId
        self.entityId = entityId
        self.detectedTaxYearId = detectedTaxYearId
        self.extractedText = extractedText
        self.metadataStatus = metadataStatus
        self.parseVersion = parseVersion
        self.status = status
        self.archivedAt = archivedAt
        self.archivedBy = archivedBy
        self.archiveReason = archiveReason
    }
}
