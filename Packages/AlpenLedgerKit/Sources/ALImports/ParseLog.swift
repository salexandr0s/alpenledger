import Foundation
import ALDomain

public struct ParseLog: Hashable, Sendable {
    public let parserKey: String
    public let parserVersion: String
    public let importedRowCount: Int
    public let diagnostics: [ImportDiagnostic]

    public var warnings: [String] {
        diagnostics
            .filter { $0.severity == .warning }
            .map(\.message)
    }

    public var errors: [String] {
        diagnostics
            .filter { $0.severity == .error }
            .map(\.message)
    }

    public init(
        parserKey: String,
        parserVersion: String,
        importedRowCount: Int,
        diagnostics: [ImportDiagnostic] = []
    ) {
        self.parserKey = parserKey
        self.parserVersion = parserVersion
        self.importedRowCount = importedRowCount
        self.diagnostics = diagnostics
    }
}
