import Foundation
import ALDomain
import ALStorage

public final class CSVBankStatementImporter: Importer, Sendable {
    public let parserKey = "csv.bankstatement"
    public let parserVersion = "1.1.0"

    public init() {}

    private func makeDateFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }

    public func canRecognize(_ url: URL) throws -> Bool {
        guard url.pathExtension.lowercased() == "csv" else {
            return false
        }
        let header = try firstLine(of: url)
        return header == "booking_date,value_date,amount,currency,counterparty,memo,reference,balance"
    }

    public func parse(_ url: URL, accountId: FinancialAccountID, importJobId: ImportJobID, sourceBlobHash: String) throws -> ImportedStatementPayload {
        let df = makeDateFormatter()
        let lines = try String(contentsOf: url, encoding: .utf8)
            .components(separatedBy: .newlines)
            .filter { $0.isEmpty == false }
        guard lines.count > 1 else {
            throw DomainError.unsupportedImportFormat
        }

        var warnings: [String] = []
        let rows: [Transaction] = lines.dropFirst().enumerated().compactMap { index, line in
            let csvRow = index + 2
            let columns = parseCSVRow(line)

            guard columns.count >= 8 else {
                warnings.append("Row \(csvRow): expected 8 columns, got \(columns.count) — skipped")
                return nil
            }

            guard let bookingDate = df.date(from: columns[0]) else {
                warnings.append("Row \(csvRow): unparseable booking date '\(columns[0])' — skipped")
                return nil
            }

            let valueDate = columns[1].isEmpty ? nil : df.date(from: columns[1])

            let amountMinor: Int64
            if let decimal = Decimal(string: columns[2]) {
                amountMinor = Money(majorUnits: decimal, currency: .chf).minorUnits
            } else {
                warnings.append("Row \(csvRow): unparseable amount '\(columns[2])' — skipped")
                return nil
            }

            let balanceMinor: Int64?
            if columns[7].isEmpty {
                balanceMinor = nil
            } else if let decimal = Decimal(string: columns[7]) {
                balanceMinor = Money(majorUnits: decimal, currency: .chf).minorUnits
            } else {
                balanceMinor = nil
            }

            return Transaction(
                accountId: accountId,
                originKind: .imported,
                sourceLineRef: "csv:\(csvRow)",
                bookingDate: bookingDate,
                valueDate: valueDate,
                amountMinor: amountMinor,
                currency: CurrencyCode(rawValue: columns[3]) ?? .chf,
                counterpartyName: columns[4],
                memo: columns[5],
                reference: columns[6].isEmpty ? nil : columns[6],
                balanceAfterMinor: balanceMinor
            )
        }

        guard rows.isEmpty == false else {
            throw DomainError.csvParseError(row: 0, reason: "No valid rows after parsing — all rows were skipped")
        }
        let coverageStart = rows.map(\.bookingDate).min()!
        let coverageEnd = rows.map(\.bookingDate).max()!
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
        let parseLog = ParseLog(parserKey: parserKey, parserVersion: parserVersion, importedRowCount: normalizedTransactions.count, warnings: warnings)
        return ImportedStatementPayload(statementImport: statementImport, transactions: normalizedTransactions, parseLog: parseLog)
    }

    private func parseCSVRow(_ line: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false
        var i = line.startIndex

        while i < line.endIndex {
            let char = line[i]
            if inQuotes {
                if char == "\"" {
                    let next = line.index(after: i)
                    if next < line.endIndex, line[next] == "\"" {
                        current.append("\"")
                        i = line.index(after: next)
                    } else {
                        inQuotes = false
                        i = line.index(after: i)
                    }
                } else {
                    current.append(char)
                    i = line.index(after: i)
                }
            } else {
                if char == "\"" {
                    inQuotes = true
                    i = line.index(after: i)
                } else if char == "," {
                    fields.append(current)
                    current = ""
                    i = line.index(after: i)
                } else {
                    current.append(char)
                    i = line.index(after: i)
                }
            }
        }
        fields.append(current)
        return fields
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
