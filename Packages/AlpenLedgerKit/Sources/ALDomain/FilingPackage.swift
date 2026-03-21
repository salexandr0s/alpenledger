import Foundation

public enum FilingPackageStatus: String, Codable, CaseIterable, Sendable {
    case draft
    case generated
    case submitted
    case accepted
}

public struct FilingPackage: Hashable, Codable, Sendable {
    public let id: FilingPackageID
    public let entityId: LegalEntityID
    public let taxYearId: TaxYearID
    public var status: FilingPackageStatus
    public var generatedAt: Date?
    public var submittedAt: Date?
    public var snapshotHash: String?
    public var exportFormat: String
    public let createdAt: Date
    public var updatedAt: Date

    public init(
        id: FilingPackageID = FilingPackageID(),
        entityId: LegalEntityID,
        taxYearId: TaxYearID,
        status: FilingPackageStatus = .draft,
        generatedAt: Date? = nil,
        submittedAt: Date? = nil,
        snapshotHash: String? = nil,
        exportFormat: String,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.entityId = entityId
        self.taxYearId = taxYearId
        self.status = status
        self.generatedAt = generatedAt
        self.submittedAt = submittedAt
        self.snapshotHash = snapshotHash
        self.exportFormat = exportFormat
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
