import Foundation
import ALDomain
import ALStorage

public final class CSVBankStatementImporter: Importer, @unchecked Sendable {
    public let parserKey = "csv.bankstatement"
    public let parserVersion = "1.0.0"

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    public init() {}

    public func canRecognize(_ url: URL) throws -> Bool {
        guard url.pathExtension.lowercased() == "csv" else {
            return false
        }
        let header = try firstLine(of: url)
        return header == "booking_date,value_date,amount,currency,counterparty,memo,reference,balance"
    }

    public func parse(_ url: URL, accountId: FinancialAccountID, importJobId: ImportJobID, sourceBlobHash: String) throws -> ImportedStatementPayload {
        let lines = try String(contentsOf: url, encoding: .utf8)
            .components(separatedBy: .newlines)
            .filter { $0.isEmpty == false }
        guard lines.count > 1 else {
            throw DomainError.unsupportedImportFormat
        }

        let rows = lines.dropFirst().enumerated().map { index, line -> Transaction in
            let columns = line.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
            let bookingDate = dateFormatter.date(from: columns[0]) ?? .now
            let valueDate = columns[1].isEmpty ? nil : dateFormatter.date(from: columns[1])
            let amountMinor = Int64((Double(columns[2]) ?? 0) * 100)
            let balanceMinor = columns[7].isEmpty ? nil : Int64((Double(columns[7]) ?? 0) * 100)
            return Transaction(
                accountId: accountId,
                originKind: .imported,
                sourceLineRef: "csv:\(index + 2)",
                bookingDate: bookingDate,
                valueDate: valueDate,
                amountMinor: amountMinor,
                currency: columns[3],
                counterpartyName: columns[4],
                memo: columns[5],
                reference: columns[6].isEmpty ? nil : columns[6],
                balanceAfterMinor: balanceMinor
            )
        }

        let coverageStart = rows.map(\.bookingDate).min() ?? .now
        let coverageEnd = rows.map(\.bookingDate).max() ?? .now
        let statementImport = StatementImport(
            accountId: accountId,
            importJobId: importJobId,
            sourceBlobHash: sourceBlobHash,
            sourceFormat: "csv",
            sourceFingerprint: fingerprint(for: lines),
            coverageStart: coverageStart,
            coverageEnd: coverageEnd,
            openingBalanceMinor: rows.first?.balanceAfterMinor,
            closingBalanceMinor: rows.last?.balanceAfterMinor,
            parserVersion: parserVersion
        )
        let normalizedTransactions = rows.map {
            var transaction = $0
            transaction.statementImportId = statementImport.id
            return transaction
        }
        let parseLog = ParseLog(parserKey: parserKey, parserVersion: parserVersion, importedRowCount: normalizedTransactions.count)
        return ImportedStatementPayload(statementImport: statementImport, transactions: normalizedTransactions, parseLog: parseLog)
    }

    private func firstLine(of url: URL) throws -> String {
        let contents = try String(contentsOf: url, encoding: .utf8)
        return contents.components(separatedBy: .newlines).first ?? ""
    }

    private func fingerprint(for lines: [String]) -> String {
        let payload = lines.joined(separator: "\n")
        return SHA256Helper.hashHex(payload)
    }
}

private enum SHA256Helper {
    static func hashHex(_ string: String) -> String {
        WorkspaceCrypto.sha256Hex(for: Data(string.utf8))
    }
}
