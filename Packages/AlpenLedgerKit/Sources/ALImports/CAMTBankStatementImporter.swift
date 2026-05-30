import Foundation
import ALDomain
import ALStorage

public enum CAMTBankStatementFormat: String, CaseIterable, Sendable {
    case camt052
    case camt053
    case camt054

    var parserKey: String {
        switch self {
        case .camt052:
            "camt.052.bankstatement"
        case .camt053:
            "camt.053.bankstatement"
        case .camt054:
            "camt.054.bankstatement"
        }
    }

    var sourceFormat: String {
        switch self {
        case .camt052:
            "camt.052"
        case .camt053:
            "camt.053"
        case .camt054:
            "camt.054"
        }
    }

    var displayName: String {
        switch self {
        case .camt052:
            "CAMT.052"
        case .camt053:
            "CAMT.053"
        case .camt054:
            "CAMT.054"
        }
    }

    var namespaceMarker: String {
        switch self {
        case .camt052:
            "camt.052"
        case .camt053:
            "camt.053"
        case .camt054:
            "camt.054"
        }
    }

    var documentMarker: String {
        switch self {
        case .camt052:
            "BkToCstmrAcctRpt"
        case .camt053:
            "BkToCstmrStmt"
        case .camt054:
            "BkToCstmrDbtCdtNtfctn"
        }
    }

    var reportElementName: String {
        switch self {
        case .camt052:
            "Rpt"
        case .camt053:
            "Stmt"
        case .camt054:
            "Ntfctn"
        }
    }
}

public final class CAMTBankStatementImporter: Importer, Sendable {
    public var parserKey: String { format.parserKey }
    public let parserVersion = "1.0.0"
    public let importJobKind: ImportJobKind = .bankStatementCAMT

    private let format: CAMTBankStatementFormat

    public init(format: CAMTBankStatementFormat = .camt053) {
        self.format = format
    }

    public func canRecognize(_ url: URL) throws -> Bool {
        guard ["xml", "camt"].contains(url.pathExtension.lowercased()) else {
            return false
        }
        let data = try Data(contentsOf: url)
        let prefix = String(decoding: data.prefix(8_192), as: UTF8.self)
        return prefix.contains(format.documentMarker) && prefix.contains(format.namespaceMarker)
    }

    public func parse(
        _ url: URL,
        accountId: FinancialAccountID,
        importJobId: ImportJobID,
        sourceBlobHash: String
    ) throws -> ImportedStatementPayload {
        let data = try Data(contentsOf: url)
        let parser = XMLParser(data: data)
        let delegate = CAMTStatementParser(
            accountId: accountId,
            importJobId: importJobId,
            sourceBlobHash: sourceBlobHash,
            sourceFingerprint: WorkspaceCrypto.sha256Hex(for: data),
            format: format,
            parserKey: parserKey,
            parserVersion: parserVersion
        )
        parser.delegate = delegate
        parser.shouldProcessNamespaces = true

        guard parser.parse() else {
            let reason = parser.parserError?.localizedDescription ?? delegate.parseError ?? "XML parser rejected the file"
            throw DomainError.statementParseError(format: format.displayName, reason: reason)
        }

        return try delegate.payload()
    }
}

private final class CAMTStatementParser: NSObject, XMLParserDelegate {
    private let accountId: FinancialAccountID
    private let importJobId: ImportJobID
    private let sourceBlobHash: String
    private let sourceFingerprint: String
    private let format: CAMTBankStatementFormat
    private let parserKey: String
    private let parserVersion: String

    private var path: [String] = []
    private var textStack: [String] = []
    private var attributeStack: [[String: String]] = []
    private var coverageStarts: [Date] = []
    private var coverageEnds: [Date] = []
    private var currentBalance: BalanceDraft?
    private var balances: [BalanceDraft] = []
    private var currentEntry: EntryDraft?
    private var entries: [EntryDraft] = []
    private var currentTransactionDetail: TransactionDetailDraft?
    private var entrySequence = 0
    fileprivate private(set) var parseError: String?
    private var diagnostics: [ImportDiagnostic] = []

    init(
        accountId: FinancialAccountID,
        importJobId: ImportJobID,
        sourceBlobHash: String,
        sourceFingerprint: String,
        format: CAMTBankStatementFormat,
        parserKey: String,
        parserVersion: String
    ) {
        self.accountId = accountId
        self.importJobId = importJobId
        self.sourceBlobHash = sourceBlobHash
        self.sourceFingerprint = sourceFingerprint
        self.format = format
        self.parserKey = parserKey
        self.parserVersion = parserVersion
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        let name = normalizedElementName(elementName.isEmpty ? qName ?? "" : elementName)
        path.append(name)
        textStack.append("")
        attributeStack.append(attributeDict)

        if name == "Bal", currentEntry == nil {
            currentBalance = BalanceDraft()
        } else if name == "Ntry" {
            entrySequence += 1
            currentEntry = EntryDraft(sequence: entrySequence)
        } else if name == "TxDtls", currentEntry != nil {
            currentTransactionDetail = TransactionDetailDraft()
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard textStack.isEmpty == false else { return }
        textStack[textStack.count - 1].append(string)
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        let name = normalizedElementName(elementName.isEmpty ? qName ?? "" : elementName)
        let text = textStack.last?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let attributes = attributeStack.last ?? [:]

        defer {
            _ = path.popLast()
            _ = textStack.popLast()
            _ = attributeStack.popLast()
        }

        applyLeafValue(name: name, text: text, attributes: attributes)

        if name == "TxDtls", var entry = currentEntry {
            if let currentTransactionDetail {
                entry.transactionDetails.append(currentTransactionDetail)
                currentEntry = entry
            }
            currentTransactionDetail = nil
        } else if name == "Ntry" {
            if let currentEntry {
                entries.append(currentEntry)
            }
            currentEntry = nil
        } else if name == "Bal" {
            if let currentBalance {
                balances.append(currentBalance)
            }
            currentBalance = nil
        }
    }

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        self.parseError = parseError.localizedDescription
    }

    func payload() throws -> ImportedStatementPayload {
        var parsedTransactions: [Transaction] = []

        for entry in entries {
            let entryTransactions = makeTransactions(for: entry)
            if entryTransactions.isEmpty {
                appendWarning(
                    code: "camt.no_importable_transaction_details",
                    entrySequence: entry.sequence,
                    message: "Entry \(entry.sequence): no importable transaction details found"
                )
            }
            parsedTransactions.append(contentsOf: entryTransactions)
        }

        guard parsedTransactions.isEmpty == false else {
            throw DomainError.statementParseError(format: format.displayName, reason: "No valid entries were found")
        }

        let coverageStart = coverageStarts.min() ?? parsedTransactions.map(\.bookingDate).min()!
        let coverageEnd = coverageEnds.max() ?? parsedTransactions.map(\.bookingDate).max()!
        let statementImport = StatementImport(
            accountId: accountId,
            importJobId: importJobId,
            sourceBlobHash: sourceBlobHash,
            sourceFormat: format.sourceFormat,
            sourceFingerprint: sourceFingerprint,
            coverageStart: coverageStart,
            coverageEnd: coverageEnd,
            openingBalanceMinor: balanceMinor(typeCode: "OPBD"),
            closingBalanceMinor: balanceMinor(typeCode: "CLBD"),
            parserVersion: parserVersion
        )

        let normalizedTransactions = parsedTransactions.map { transaction in
            var transaction = transaction
            transaction.statementImportId = statementImport.id
            return transaction
        }
        return ImportedStatementPayload(
            statementImport: statementImport,
            transactions: normalizedTransactions,
            parseLog: ParseLog(
                parserKey: parserKey,
                parserVersion: parserVersion,
                importedRowCount: normalizedTransactions.count,
                diagnostics: diagnostics
            )
        )
    }

    private func applyLeafValue(name: String, text: String, attributes: [String: String]) {
        guard text.isEmpty == false else { return }

        if pathEnds(with: [format.reportElementName, "FrToDt", "FrDtTm"]) {
            if let date = parseCAMTDate(text) {
                coverageStarts.append(date)
            }
            return
        }
        if pathEnds(with: [format.reportElementName, "FrToDt", "ToDtTm"]) {
            if let date = parseCAMTDate(text) {
                coverageEnds.append(date)
            }
            return
        }

        if currentBalance != nil, currentEntry == nil {
            applyBalanceValue(name: name, text: text, attributes: attributes)
            return
        }

        guard currentEntry != nil else { return }

        if currentTransactionDetail != nil {
            applyTransactionDetailValue(name: name, text: text, attributes: attributes)
            return
        }

        applyEntryValue(name: name, text: text, attributes: attributes)
    }

    private func applyBalanceValue(name: String, text: String, attributes: [String: String]) {
        guard var balance = currentBalance else { return }
        if pathEnds(with: ["Bal", "Tp", "CdOrPrtry", "Cd"]) {
            balance.typeCode = text
        } else if pathEnds(with: ["Bal", "Amt"]) {
            let parsed = parseMoney(text, currencyAttribute: attributes["Ccy"])
            balance.amountMinor = parsed?.minorUnits
        } else if pathEnds(with: ["Bal", "CdtDbtInd"]) {
            balance.creditDebitIndicator = text
        } else if pathEnds(with: ["Bal", "Dt", "Dt"]) || pathEnds(with: ["Bal", "Dt", "DtTm"]) {
            balance.date = parseCAMTDate(text)
        }
        currentBalance = balance
    }

    private func applyEntryValue(name: String, text: String, attributes: [String: String]) {
        guard var entry = currentEntry else { return }
        if directChild(of: "Ntry", named: "Amt") {
            let parsed = parseMoney(text, currencyAttribute: attributes["Ccy"])
            entry.amountMinor = parsed?.minorUnits
            entry.currency = parsed?.currency
        } else if directChild(of: "Ntry", named: "CdtDbtInd") {
            entry.creditDebitIndicator = text
        } else if pathEnds(with: ["Ntry", "BookgDt", "Dt"]) || pathEnds(with: ["Ntry", "BookgDt", "DtTm"]) {
            entry.bookingDate = parseCAMTDate(text)
        } else if pathEnds(with: ["Ntry", "ValDt", "Dt"]) || pathEnds(with: ["Ntry", "ValDt", "DtTm"]) {
            entry.valueDate = parseCAMTDate(text)
        } else if directChild(of: "Ntry", named: "NtryRef") || directChild(of: "Ntry", named: "AcctSvcrRef") {
            entry.reference = firstUseful(entry.reference, text)
        } else if directChild(of: "Ntry", named: "AddtlNtryInf") {
            entry.memoParts.append(text)
        }
        currentEntry = entry
    }

    private func applyTransactionDetailValue(name: String, text: String, attributes: [String: String]) {
        guard var detail = currentTransactionDetail else { return }
        if pathEnds(with: ["TxDtls", "AmtDtls", "TxAmt", "Amt"]) || directChild(of: "TxDtls", named: "Amt") {
            let parsed = parseMoney(text, currencyAttribute: attributes["Ccy"])
            detail.amountMinor = parsed?.minorUnits
            detail.currency = parsed?.currency
        } else if directChild(of: "TxDtls", named: "CdtDbtInd") {
            detail.creditDebitIndicator = text
        } else if name == "Nm", path.contains("RltdPties") {
            detail.counterpartyName = firstUseful(detail.counterpartyName, text)
        } else if name == "Ustrd", path.contains("RmtInf") {
            detail.memoParts.append(text)
        } else if name == "AddtlTxInf" {
            detail.memoParts.append(text)
        } else if path.contains("Refs"), ["EndToEndId", "AcctSvcrRef", "InstrId", "TxId"].contains(name) {
            if text != "NOTPROVIDED" {
                detail.references.append(text)
            }
        }
        currentTransactionDetail = detail
    }

    private func makeTransactions(for entry: EntryDraft) -> [Transaction] {
        let details = entry.transactionDetails.isEmpty ? [TransactionDetailDraft()] : entry.transactionDetails
        if details.count > 1 && details.contains(where: { $0.amountMinor == nil }) {
            appendWarning(
                code: "camt.split_details_missing_amounts",
                entrySequence: entry.sequence,
                message: "Entry \(entry.sequence): split entry details without detail amounts were skipped"
            )
            return []
        }

        return details.enumerated().compactMap { detailIndex, detail in
            guard let bookingDate = entry.bookingDate else {
                appendWarning(
                    code: "camt.missing_booking_date",
                    entrySequence: entry.sequence,
                    detailIndex: detailIndex,
                    message: "Entry \(entry.sequence): missing booking date"
                )
                return nil
            }
            let unsignedAmount = detail.amountMinor ?? entry.amountMinor
            guard let unsignedAmount else {
                appendWarning(
                    code: "camt.missing_amount",
                    entrySequence: entry.sequence,
                    detailIndex: detailIndex,
                    message: "Entry \(entry.sequence): missing amount"
                )
                return nil
            }
            let currency = detail.currency ?? entry.currency ?? .chf
            let indicator = detail.creditDebitIndicator ?? entry.creditDebitIndicator
            let amountMinor = signedAmount(unsignedAmount, indicator: indicator)
            let memo = (detail.memoParts + entry.memoParts).joined(separator: " | ")
            let counterparty = detail.counterpartyName ?? "Unknown counterparty"
            if detail.counterpartyName == nil {
                appendWarning(
                    code: "camt.missing_counterparty_name",
                    entrySequence: entry.sequence,
                    detailIndex: detailIndex,
                    message: "Entry \(entry.sequence): missing counterparty name"
                )
            }
            let references = detail.references + [entry.reference].compactMap { $0 }
            let sourceLineRef = detailIndex == 0 && details.count == 1
                ? "camt:\(entry.sequence)"
                : "camt:\(entry.sequence).\(detailIndex + 1)"

            return Transaction(
                accountId: accountId,
                originKind: .imported,
                sourceLineRef: sourceLineRef,
                bookingDate: bookingDate,
                valueDate: entry.valueDate,
                amountMinor: amountMinor,
                currency: currency,
                counterpartyName: counterparty,
                memo: memo,
                reference: references.first,
                balanceAfterMinor: nil
            )
        }
    }

    private func appendWarning(
        code: String,
        entrySequence: Int,
        detailIndex: Int? = nil,
        message: String
    ) {
        let location: String
        if let detailIndex {
            location = "camt:\(entrySequence).\(detailIndex + 1)"
        } else {
            location = "camt:\(entrySequence)"
        }
        diagnostics.append(ImportDiagnostic(
            importJobId: importJobId,
            severity: .warning,
            code: code,
            location: location,
            message: message
        ))
    }

    private func balanceMinor(typeCode: String) -> Int64? {
        let candidates = balances.filter { $0.typeCode == typeCode && $0.amountMinor != nil }
        let balance: BalanceDraft?
        switch typeCode {
        case "OPBD":
            balance = candidates.min { lhs, rhs in
                (lhs.date ?? .distantFuture) < (rhs.date ?? .distantFuture)
            } ?? candidates.first
        case "CLBD":
            balance = candidates.max { lhs, rhs in
                (lhs.date ?? .distantPast) < (rhs.date ?? .distantPast)
            } ?? candidates.last
        default:
            balance = candidates.first
        }

        guard let balance, let amountMinor = balance.amountMinor
        else {
            return nil
        }
        return signedAmount(amountMinor, indicator: balance.creditDebitIndicator)
    }

    private func parseMoney(_ text: String, currencyAttribute: String?) -> Money? {
        guard let decimal = Decimal(string: text) else { return nil }
        let currency = currencyAttribute.flatMap(CurrencyCode.init(rawValue:)) ?? .chf
        return Money(majorUnits: decimal, currency: currency)
    }

    private func parseCAMTDate(_ text: String) -> Date? {
        if let date = ISO8601DateFormatter().date(from: text) {
            return date
        }
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: text)
    }

    private func signedAmount(_ amountMinor: Int64, indicator: String?) -> Int64 {
        switch indicator {
        case "DBIT":
            -abs(amountMinor)
        case "CRDT":
            abs(amountMinor)
        default:
            amountMinor
        }
    }

    private func directChild(of parentName: String, named childName: String) -> Bool {
        path.count >= 2 && path[path.count - 2] == parentName && path.last == childName
    }

    private func pathEnds(with suffix: [String]) -> Bool {
        guard suffix.count <= path.count else { return false }
        return Array(path.suffix(suffix.count)) == suffix
    }

    private func firstUseful(_ current: String?, _ candidate: String) -> String? {
        if let current, current.isEmpty == false {
            return current
        }
        return candidate.isEmpty ? nil : candidate
    }
}

private struct BalanceDraft {
    var typeCode: String?
    var amountMinor: Int64?
    var creditDebitIndicator: String?
    var date: Date?
}

private struct EntryDraft {
    let sequence: Int
    var amountMinor: Int64?
    var currency: CurrencyCode?
    var creditDebitIndicator: String?
    var bookingDate: Date?
    var valueDate: Date?
    var reference: String?
    var memoParts: [String] = []
    var transactionDetails: [TransactionDetailDraft] = []
}

private struct TransactionDetailDraft {
    var amountMinor: Int64?
    var currency: CurrencyCode?
    var creditDebitIndicator: String?
    var counterpartyName: String?
    var references: [String] = []
    var memoParts: [String] = []
}

private func normalizedElementName(_ name: String) -> String {
    name.split(separator: ":").last.map(String.init) ?? name
}
