import Foundation

public enum DomainError: Error, LocalizedError, Equatable, Sendable {
    case currencyMismatch(expected: String, actual: String)
    case invalidJournalLine
    case unbalancedJournalEntry
    case invalidWorkspaceName
    case duplicateStatementImport
    case workspaceNotFound
    case missingWorkspaceKey
    case unsupportedImportFormat
    case entityNotFound
    case taxYearNotFound
    case issueNotFound
    case invalidCurrencyCode(String)
    case invalidCantonCode(String)
    case csvParseError(row: Int, reason: String)

    public var errorDescription: String? {
        switch self {
        case let .currencyMismatch(expected, actual):
            "Currency mismatch. Expected \(expected), got \(actual)."
        case .invalidJournalLine:
            "Journal lines must contain exactly one non-zero side."
        case .unbalancedJournalEntry:
            "Journal entry lines must balance."
        case .invalidWorkspaceName:
            "Workspace names must not be empty."
        case .duplicateStatementImport:
            "This statement import was already processed."
        case .workspaceNotFound:
            "Workspace could not be found."
        case .missingWorkspaceKey:
            "Workspace encryption key is missing."
        case .unsupportedImportFormat:
            "The selected file is not supported by the current importer."
        case .entityNotFound:
            "Legal entity could not be found."
        case .taxYearNotFound:
            "Tax year could not be found."
        case .issueNotFound:
            "Issue could not be found."
        case let .invalidCurrencyCode(code):
            "Invalid ISO 4217 currency code: \(code)."
        case let .invalidCantonCode(code):
            "Invalid Swiss canton code: \(code)."
        case let .csvParseError(row, reason):
            "CSV parse error at row \(row): \(reason)."
        }
    }
}
