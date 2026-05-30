import Foundation
import ALDomain
import ALStorage

public final class CSVBankStatementImporter: Importer, Sendable {
    public let parserKey = "csv.bankstatement"
    public let parserVersion = "1.2.0"

    static let defaultPresets: [CSVBankStatementPreset] = [
        CSVBankStatementPreset(
            key: "canonical.alpenledger",
            displayName: "AlpenLedger canonical CSV",
            aliases: [
                .bookingDate: ["booking_date", "booking date", "bookingdate", "date", "transaction date"],
                .valueDate: ["value_date", "value date", "valuedate", "valuta"],
                .amount: ["amount", "betrag"],
                .currency: ["currency", "ccy", "währung", "waehrung"],
                .counterparty: ["counterparty", "counterparty name", "name", "payee", "payer"],
                .memo: ["memo", "description", "booking text", "buchungstext"],
                .reference: ["reference", "ref", "referenz"],
                .balance: ["balance", "saldo"],
            ]
        ),
        CSVBankStatementPreset(
            key: "generic.swiss",
            displayName: "Generic Swiss bank CSV",
            aliases: [
                .bookingDate: ["buchungsdatum", "buchungstag", "booking date", "date", "datum"],
                .valueDate: ["valutadatum", "valuta", "value date"],
                .amount: ["betrag", "amount"],
                .debit: ["belastung", "debit", "lastschrift", "ausgang", "withdrawal"],
                .credit: ["gutschrift", "credit", "eingang", "deposit"],
                .currency: ["währung", "waehrung", "currency", "ccy"],
                .counterparty: ["gegenpartei", "begünstigter", "beguenstigter", "auftraggeber", "partner", "name"],
                .memo: ["buchungstext", "text", "mitteilung", "description", "memo"],
                .reference: ["referenz", "reference", "ref"],
                .balance: ["saldo", "balance"],
            ]
        ),
        CSVBankStatementPreset(
            key: "postfinance.ch",
            displayName: "PostFinance-style CSV",
            aliases: [
                .bookingDate: ["buchungsdatum", "date"],
                .valueDate: ["valutadatum", "valuta"],
                .debit: ["lastschrift in chf", "belastung in chf", "debit chf"],
                .credit: ["gutschrift in chf", "credit chf"],
                .counterparty: ["buchungstext", "details"],
                .memo: ["mitteilungen", "mitteilung", "description"],
                .reference: ["referenz", "reference"],
                .balance: ["saldo in chf", "saldo", "balance"],
            ]
        ),
    ]

    private let presets: [CSVBankStatementPreset]

    public init() {
        self.presets = Self.defaultPresets
    }

    init(presets: [CSVBankStatementPreset]) {
        self.presets = presets
    }

    public func canRecognize(_ url: URL) throws -> Bool {
        guard url.pathExtension.lowercased() == "csv" else {
            return false
        }
        let lines = try csvLines(from: url)
        return detectMapping(in: lines) != nil
    }

    public func parse(_ url: URL, accountId: FinancialAccountID, importJobId: ImportJobID, sourceBlobHash: String) throws -> ImportedStatementPayload {
        let lines = try csvLines(from: url)
        guard lines.count > 1, let mapping = detectMapping(in: lines) else {
            throw DomainError.unsupportedImportFormat
        }
        let dateFormatters = makeDateFormatters()

        var diagnostics: [ImportDiagnostic] = []
        let rows: [Transaction] = lines.dropFirst().enumerated().compactMap { index, line in
            let csvRow = index + 2
            let columns = parseCSVRow(line, delimiter: mapping.delimiter)

            guard columns.count >= mapping.headerColumnCount else {
                diagnostics.append(csvWarning(
                    importJobId: importJobId,
                    row: csvRow,
                    code: "csv.expected_columns",
                    message: "Row \(csvRow): expected \(mapping.headerColumnCount) columns, got \(columns.count) - skipped"
                ))
                return nil
            }

            let bookingDateValue = mappedValue(.bookingDate, in: columns, mapping: mapping)
            guard let bookingDate = parseDate(bookingDateValue, using: dateFormatters) else {
                diagnostics.append(csvWarning(
                    importJobId: importJobId,
                    row: csvRow,
                    code: "csv.unparseable_booking_date",
                    message: "Row \(csvRow): unparseable booking date '\(bookingDateValue)' - skipped"
                ))
                return nil
            }

            let rawValueDate = mappedValue(.valueDate, in: columns, mapping: mapping)
            let valueDate = rawValueDate.isEmpty ? nil : parseDate(rawValueDate, using: dateFormatters)

            let amountMinor: Int64
            if let decimal = parseAmountDecimal(in: columns, mapping: mapping) {
                amountMinor = Money(majorUnits: decimal, currency: .chf).minorUnits
            } else {
                let rawAmount = [
                    mappedValue(.amount, in: columns, mapping: mapping),
                    mappedValue(.debit, in: columns, mapping: mapping),
                    mappedValue(.credit, in: columns, mapping: mapping),
                ]
                .filter { $0.isEmpty == false }
                .joined(separator: " / ")
                diagnostics.append(csvWarning(
                    importJobId: importJobId,
                    row: csvRow,
                    code: "csv.unparseable_amount",
                    message: "Row \(csvRow): unparseable amount '\(rawAmount)' - skipped"
                ))
                return nil
            }

            let balanceMinor: Int64?
            let rawBalance = mappedValue(.balance, in: columns, mapping: mapping)
            if rawBalance.isEmpty {
                balanceMinor = nil
            } else if let decimal = parseDecimal(rawBalance) {
                balanceMinor = Money(majorUnits: decimal, currency: .chf).minorUnits
            } else {
                balanceMinor = nil
            }
            let rawCurrency = mappedValue(.currency, in: columns, mapping: mapping)

            return Transaction(
                accountId: accountId,
                originKind: .imported,
                sourceLineRef: "csv:\(csvRow)",
                bookingDate: bookingDate,
                valueDate: valueDate,
                amountMinor: amountMinor,
                currency: CurrencyCode(rawValue: rawCurrency) ?? .chf,
                counterpartyName: mappedValue(.counterparty, in: columns, mapping: mapping),
                memo: mappedValue(.memo, in: columns, mapping: mapping),
                reference: mappedValue(.reference, in: columns, mapping: mapping).nilIfEmpty,
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
        let parseLog = ParseLog(
            parserKey: parserKey,
            parserVersion: parserVersion,
            importedRowCount: normalizedTransactions.count,
            diagnostics: diagnostics
        )
        return ImportedStatementPayload(statementImport: statementImport, transactions: normalizedTransactions, parseLog: parseLog)
    }

    private func csvWarning(
        importJobId: ImportJobID,
        row: Int,
        code: String,
        message: String
    ) -> ImportDiagnostic {
        ImportDiagnostic(
            importJobId: importJobId,
            severity: .warning,
            code: code,
            location: "csv:\(row)",
            message: message
        )
    }

    private func csvLines(from url: URL) throws -> [String] {
        try String(contentsOf: url, encoding: .utf8)
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
    }

    private func detectMapping(in lines: [String]) -> CSVColumnMapping? {
        guard let header = lines.first else { return nil }
        for delimiter in [",", ";", "\t"] {
            let headerColumns = parseCSVRow(header, delimiter: Character(delimiter))
            guard headerColumns.count > 1 else { continue }
            let normalizedHeaders = headerColumns.map(normalizeHeader)
            for preset in presets {
                var indices: [CSVBankStatementField: Int] = [:]
                for field in CSVBankStatementField.allCases {
                    let aliases = preset.normalizedAliases(for: field)
                    guard aliases.isEmpty == false else { continue }
                    if let index = normalizedHeaders.firstIndex(where: { aliases.contains($0) }) {
                        indices[field] = index
                    }
                }
                if indices[.bookingDate] != nil,
                   indices[.amount] != nil || indices[.debit] != nil || indices[.credit] != nil {
                    return CSVColumnMapping(
                        preset: preset,
                        delimiter: Character(delimiter),
                        headerColumnCount: headerColumns.count,
                        indices: indices
                    )
                }
            }
        }
        return nil
    }

    private func parseCSVRow(_ line: String, delimiter: Character) -> [String] {
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
                } else if char == delimiter {
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

    private func makeDateFormatters() -> [DateFormatter] {
        [
            "yyyy-MM-dd",
            "dd.MM.yyyy",
            "dd/MM/yyyy",
            "dd-MM-yyyy",
            "yyyy/MM/dd",
            "yyyyMMdd",
        ].map { format in
            let formatter = DateFormatter()
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = format
            return formatter
        }
    }

    private func parseDate(_ value: String, using formatters: [DateFormatter]) -> Date? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return nil }
        return formatters.lazy.compactMap { $0.date(from: trimmed) }.first
    }

    private func parseAmountDecimal(in columns: [String], mapping: CSVColumnMapping) -> Decimal? {
        if let decimal = parseDecimal(mappedValue(.amount, in: columns, mapping: mapping)) {
            return decimal
        }

        let debit = parseDecimal(mappedValue(.debit, in: columns, mapping: mapping)).map(abs)
        let credit = parseDecimal(mappedValue(.credit, in: columns, mapping: mapping)).map(abs)
        switch (debit, credit) {
        case let (.some(debit), .some(credit)):
            return credit - debit
        case let (.some(debit), .none):
            return -debit
        case let (.none, .some(credit)):
            return credit
        case (.none, .none):
            return nil
        }
    }

    private func parseDecimal(_ rawValue: String) -> Decimal? {
        var value = rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\u{00a0}", with: "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: "’", with: "")
        guard value.isEmpty == false else { return nil }

        var isNegative = false
        if value.hasPrefix("("), value.hasSuffix(")") {
            isNegative = true
            value.removeFirst()
            value.removeLast()
        }
        if value.hasPrefix("-") {
            isNegative = true
            value.removeFirst()
        } else if value.hasPrefix("+") {
            value.removeFirst()
        }

        value = value.filter { character in
            character.isNumber || character == "," || character == "."
        }
        guard value.isEmpty == false else { return nil }

        if value.contains(","), value.contains(".") {
            if value.lastIndex(of: ",")! > value.lastIndex(of: ".")! {
                value = value.replacingOccurrences(of: ".", with: "")
                value = value.replacingOccurrences(of: ",", with: ".")
            } else {
                value = value.replacingOccurrences(of: ",", with: "")
            }
        } else if let commaIndex = value.lastIndex(of: ",") {
            let fractionalDigits = value.distance(from: value.index(after: commaIndex), to: value.endIndex)
            if fractionalDigits == 3 {
                value = value.replacingOccurrences(of: ",", with: "")
            } else {
                value = value.replacingOccurrences(of: ",", with: ".")
            }
        } else if let dotIndex = value.lastIndex(of: ".") {
            let fractionalDigits = value.distance(from: value.index(after: dotIndex), to: value.endIndex)
            if fractionalDigits == 3 {
                value = value.replacingOccurrences(of: ".", with: "")
            }
        }

        guard let decimal = Decimal(string: value, locale: Locale(identifier: "en_US_POSIX")) else {
            return nil
        }
        return isNegative ? -decimal : decimal
    }

    private func mappedValue(
        _ field: CSVBankStatementField,
        in columns: [String],
        mapping: CSVColumnMapping
    ) -> String {
        guard let index = mapping.indices[field], columns.indices.contains(index) else {
            return ""
        }
        return columns[index].trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func normalizeHeader(_ rawValue: String) -> String {
        rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\u{feff}"))
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .lowercased()
            .filter { $0.isLetter || $0.isNumber }
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

struct CSVBankStatementPreset: Sendable, Equatable {
    let key: String
    let displayName: String
    fileprivate let aliases: [CSVBankStatementField: [String]]

    fileprivate func normalizedAliases(for field: CSVBankStatementField) -> Set<String> {
        Set((aliases[field] ?? []).map(Self.normalizeAlias))
    }

    private static func normalizeAlias(_ rawValue: String) -> String {
        rawValue
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .lowercased()
            .filter { $0.isLetter || $0.isNumber }
    }
}

private struct CSVColumnMapping {
    let preset: CSVBankStatementPreset
    let delimiter: Character
    let headerColumnCount: Int
    let indices: [CSVBankStatementField: Int]
}

fileprivate enum CSVBankStatementField: CaseIterable, Sendable {
    case bookingDate
    case valueDate
    case amount
    case debit
    case credit
    case currency
    case counterparty
    case memo
    case reference
    case balance
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
