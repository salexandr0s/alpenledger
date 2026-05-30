import Foundation

public enum ImportJobKind: String, Codable, CaseIterable, Sendable {
    case bankStatementCSV
    case bankStatementCAMT
    case documentIntake
}

public enum ImportJobStatus: String, Codable, CaseIterable, Sendable {
    case started
    case completed
    case cancelled
    case failed
}

public struct ImportJob: Hashable, Codable, Sendable {
    public let id: ImportJobID
    public let workspaceId: WorkspaceID
    public var kind: ImportJobKind
    public var source: String
    public var sourceBlobHash: String?
    public var sourceFingerprint: String?
    public var parserKey: String
    public var parserVersion: String
    public var status: ImportJobStatus
    public var startedAt: Date
    public var completedAt: Date?
    public var warningCount: Int

    public init(
        id: ImportJobID = ImportJobID(),
        workspaceId: WorkspaceID,
        kind: ImportJobKind,
        source: String,
        sourceBlobHash: String? = nil,
        sourceFingerprint: String? = nil,
        parserKey: String,
        parserVersion: String,
        status: ImportJobStatus = .started,
        startedAt: Date = .now,
        completedAt: Date? = nil,
        warningCount: Int = 0
    ) {
        self.id = id
        self.workspaceId = workspaceId
        self.kind = kind
        self.source = source
        self.sourceBlobHash = sourceBlobHash
        self.sourceFingerprint = sourceFingerprint
        self.parserKey = parserKey
        self.parserVersion = parserVersion
        self.status = status
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.warningCount = warningCount
    }
}
