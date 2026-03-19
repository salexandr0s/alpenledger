import Foundation

public struct ParseLog: Hashable, Sendable {
    public let parserKey: String
    public let parserVersion: String
    public let importedRowCount: Int
    public let warnings: [String]

    public init(parserKey: String, parserVersion: String, importedRowCount: Int, warnings: [String] = []) {
        self.parserKey = parserKey
        self.parserVersion = parserVersion
        self.importedRowCount = importedRowCount
        self.warnings = warnings
    }
}
