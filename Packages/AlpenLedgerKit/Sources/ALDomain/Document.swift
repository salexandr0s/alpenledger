import Foundation

public enum DocumentOrigin: String, Codable, CaseIterable, Sendable {
    case userImport
    case importPipeline
}

public enum DocumentType: String, Codable, CaseIterable, Sendable {
    case unknown
    case receipt
    case invoice
    case bankStatement
}

public enum MetadataStatus: String, Codable, CaseIterable, Sendable {
    case proposed
    case confirmed
}

public struct Document: Hashable, Codable, Sendable {
    public let id: DocumentID
    public let workspaceId: WorkspaceID
    public var importJobId: ImportJobID?
    public var blobHash: String
    public var originalFilename: String
    public var mediaType: String
    public var origin: DocumentOrigin
    public var documentType: DocumentType
    public var issueDate: Date?
    public var detectedEntityId: LegalEntityID?
    public var detectedTaxYearId: TaxYearID?
    public var extractedText: String?
    public var metadataStatus: MetadataStatus
    public var parseVersion: String

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
        detectedTaxYearId: TaxYearID? = nil,
        extractedText: String? = nil,
        metadataStatus: MetadataStatus = .proposed,
        parseVersion: String = "v1"
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
        self.detectedTaxYearId = detectedTaxYearId
        self.extractedText = extractedText
        self.metadataStatus = metadataStatus
        self.parseVersion = parseVersion
    }
}
