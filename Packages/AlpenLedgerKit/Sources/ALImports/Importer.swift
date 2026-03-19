import Foundation
import ALDomain

public struct ImportedStatementPayload: Sendable {
    public let statementImport: StatementImport
    public let transactions: [Transaction]
    public let parseLog: ParseLog

    public init(statementImport: StatementImport, transactions: [Transaction], parseLog: ParseLog) {
        self.statementImport = statementImport
        self.transactions = transactions
        self.parseLog = parseLog
    }
}

public protocol Importer: Sendable {
    var parserKey: String { get }
    var parserVersion: String { get }
    func canRecognize(_ url: URL) throws -> Bool
    func parse(_ url: URL, accountId: FinancialAccountID, importJobId: ImportJobID, sourceBlobHash: String) throws -> ImportedStatementPayload
}
