import Foundation

public enum StatementImportStatus: String, Codable, CaseIterable, Sendable {
    case imported
    case duplicate
}

public struct StatementImport: Hashable, Codable, Sendable {
    public let id: StatementImportID
    public let accountId: FinancialAccountID
    public let importJobId: ImportJobID
    public var sourceBlobHash: String
    public var sourceFormat: String
    public var sourceFingerprint: String
    public var coverageStart: Date
    public var coverageEnd: Date
    public var openingBalanceMinor: Int64?
    public var closingBalanceMinor: Int64?
    public var parserVersion: String
    public var status: StatementImportStatus

    public init(
        id: StatementImportID = StatementImportID(),
        accountId: FinancialAccountID,
        importJobId: ImportJobID,
        sourceBlobHash: String,
        sourceFormat: String,
        sourceFingerprint: String,
        coverageStart: Date,
        coverageEnd: Date,
        openingBalanceMinor: Int64? = nil,
        closingBalanceMinor: Int64? = nil,
        parserVersion: String,
        status: StatementImportStatus = .imported
    ) {
        self.id = id
        self.accountId = accountId
        self.importJobId = importJobId
        self.sourceBlobHash = sourceBlobHash
        self.sourceFormat = sourceFormat
        self.sourceFingerprint = sourceFingerprint
        self.coverageStart = coverageStart
        self.coverageEnd = coverageEnd
        self.openingBalanceMinor = openingBalanceMinor
        self.closingBalanceMinor = closingBalanceMinor
        self.parserVersion = parserVersion
        self.status = status
    }
}
