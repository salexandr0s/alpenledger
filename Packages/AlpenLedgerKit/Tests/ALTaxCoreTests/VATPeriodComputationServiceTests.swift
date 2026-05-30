import Foundation
import Testing
@testable import ALDomain
@testable import ALTaxCH
@testable import ALTaxCore

@Test
func swissVATCodeBookContainsCurrentOfficialRates() {
    let codeBook = SwissVATCodeBook.current2026()
    let date = isoDate("2026-05-01T00:00:00Z")

    #expect(codeBook.code("CH-VAT-OUTPUT-STD", on: date)?.rateBasisPoints == 810)
    #expect(codeBook.code("CH-VAT-OUTPUT-RED", on: date)?.rateBasisPoints == 260)
    #expect(codeBook.code("CH-VAT-OUTPUT-ACC", on: date)?.rateBasisPoints == 380)
    #expect(codeBook.code("CH-VAT-INPUT-STD", on: date)?.treatment == .inputTax)
}

@Test
func vatPeriodReconcilesSwissFixtureTotals() throws {
    let fixture = try loadVATFixture()
    let entityId = LegalEntityID()
    let period = VATPeriod(
        entityId: entityId,
        periodStart: fixture.period.startDate,
        periodEnd: fixture.period.endDate,
        currency: fixture.period.currency
    )
    let transactions = fixture.transactions.map { $0.transaction(accountId: FinancialAccountID()) }
    let report = VATPeriodComputationService(codeBook: SwissVATCodeBook.current2026())
        .reconcile(period: period, transactions: transactions)

    #expect(report.jurisdictionCode == fixture.jurisdiction)
    #expect(report.rulesetVersion == fixture.rulesetVersion)
    #expect(report.lines.count == fixture.expected.lineCount)
    #expect(report.outputTaxMinor == fixture.expected.outputTaxMinor)
    #expect(report.inputTaxMinor == fixture.expected.inputTaxMinor)
    #expect(report.netTaxPayableMinor == fixture.expected.netTaxPayableMinor)
    #expect(report.issues.count == fixture.expected.issueCount)
    #expect(report.lines.map(\.vatAmountMinor) == [810, 260, 380, 405, 260, 0])
    #expect(report.lines.map(\.taxableBaseMinor) == [10_000, 10_000, 10_000, 5_000, 10_000, 50_000])
}

@Test
func vatPeriodReportsMissingAndInvalidTaxCodes() {
    let accountId = FinancialAccountID()
    let period = VATPeriod(
        entityId: LegalEntityID(),
        periodStart: isoDate("2026-04-01T00:00:00Z"),
        periodEnd: isoDate("2026-06-30T23:59:59Z"),
        currency: .chf
    )
    let transactions = [
        Transaction(
            accountId: accountId,
            sourceLineRef: "fixture:missing",
            bookingDate: isoDate("2026-05-01T00:00:00Z"),
            amountMinor: 10810,
            currency: .chf,
            counterpartyName: "Missing Code AG",
            memo: "Missing VAT code"
        ),
        Transaction(
            accountId: accountId,
            sourceLineRef: "fixture:invalid",
            bookingDate: isoDate("2026-05-02T00:00:00Z"),
            amountMinor: 10810,
            currency: .chf,
            counterpartyName: "Invalid Code AG",
            memo: "Invalid VAT code",
            taxCode: "CH-VAT-UNKNOWN"
        ),
    ]

    let report = VATPeriodComputationService(codeBook: SwissVATCodeBook.current2026())
        .reconcile(period: period, transactions: transactions)

    #expect(report.lines.isEmpty)
    #expect(report.blockerCount == 2)
    #expect(report.issues.map(\.code) == ["vat.missing_tax_code", "vat.unknown_tax_code"])
}

@Test
func vatPeriodWarnsWhenTaxDirectionDoesNotMatchTransactionSign() {
    let period = VATPeriod(
        entityId: LegalEntityID(),
        periodStart: isoDate("2026-04-01T00:00:00Z"),
        periodEnd: isoDate("2026-06-30T23:59:59Z"),
        currency: .chf
    )
    let transaction = Transaction(
        accountId: FinancialAccountID(),
        sourceLineRef: "fixture:refund",
        bookingDate: isoDate("2026-05-01T00:00:00Z"),
        amountMinor: -10810,
        currency: .chf,
        counterpartyName: "Refunded Customer AG",
        memo: "Credit note refund",
        taxCode: "CH-VAT-OUTPUT-STD"
    )

    let report = VATPeriodComputationService(codeBook: SwissVATCodeBook.current2026())
        .reconcile(period: period, transactions: [transaction])

    #expect(report.lines.count == 1)
    #expect(report.outputTaxMinor == 810)
    #expect(report.issues.map(\.code) == ["vat.output_code_on_debit"])
    #expect(report.issues.first?.severity == .warning)
}

private struct VATFixture: Decodable {
    let jurisdiction: String
    let rulesetVersion: String
    let period: VATFixturePeriod
    let transactions: [VATFixtureTransaction]
    let expected: VATFixtureExpected
}

private struct VATFixturePeriod: Decodable {
    let start: String
    let end: String
    let currency: CurrencyCode

    var startDate: Date { isoDate(start) }
    var endDate: Date { isoDate(end) }
}

private struct VATFixtureTransaction: Decodable {
    let id: UUID
    let bookingDate: String
    let amountMinor: Int64
    let currency: CurrencyCode
    let counterpartyName: String
    let memo: String
    let taxCode: String?

    func transaction(accountId: FinancialAccountID) -> Transaction {
        Transaction(
            id: TransactionID(rawValue: id),
            accountId: accountId,
            sourceLineRef: "vat-fixture:\(id.uuidString.lowercased())",
            bookingDate: isoDate(bookingDate),
            amountMinor: amountMinor,
            currency: currency,
            counterpartyName: counterpartyName,
            memo: memo,
            taxCode: taxCode,
            reviewState: .reviewed
        )
    }
}

private struct VATFixtureExpected: Decodable {
    let lineCount: Int
    let outputTaxMinor: Int64
    let inputTaxMinor: Int64
    let netTaxPayableMinor: Int64
    let issueCount: Int
}

private func loadVATFixture() throws -> VATFixture {
    let url = try fixtureURL("Fixtures/VAT/simple-quarter-2026.json")
    let data = try Data(contentsOf: url)
    return try JSONDecoder.alpenLedger.decode(VATFixture.self, from: data)
}

private func fixtureURL(_ relativePath: String) throws -> URL {
    let packageRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    return packageRoot.appendingPathComponent(relativePath)
}

private func isoDate(_ text: String) -> Date {
    ISO8601DateFormatter().date(from: text)!
}
