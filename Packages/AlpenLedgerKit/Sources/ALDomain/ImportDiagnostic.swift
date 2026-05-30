import Foundation

public enum ImportDiagnosticSeverity: String, Codable, CaseIterable, Sendable {
    case warning
    case error
}

public struct ImportDiagnostic: Hashable, Codable, Sendable {
    public let id: ImportDiagnosticID
    public let importJobId: ImportJobID
    public var severity: ImportDiagnosticSeverity
    public var code: String
    public var location: String?
    public var message: String
    public var createdAt: Date

    public init(
        id: ImportDiagnosticID = ImportDiagnosticID(),
        importJobId: ImportJobID,
        severity: ImportDiagnosticSeverity,
        code: String,
        location: String? = nil,
        message: String,
        createdAt: Date = .now
    ) {
        self.id = id
        self.importJobId = importJobId
        self.severity = severity
        self.code = code
        self.location = location
        self.message = message
        self.createdAt = createdAt
    }
}
