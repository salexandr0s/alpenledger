import Foundation
import Testing
@testable import ALImports
@testable import ALDomain

@Test
func decimalPrecision1999() throws {
    let csv = """
    booking_date,value_date,amount,currency,counterparty,memo,reference,balance
    2026-01-15,2026-01-15,19.99,CHF,Shop,Item,REF1,1019.99
    """
    let url = try writeTempCSV(csv)
    let importer = CSVBankStatementImporter()
    let payload = try importer.parse(url, accountId: FinancialAccountID(), importJobId: ImportJobID(), sourceBlobHash: "test")

    #expect(payload.transactions.count == 1)
    #expect(payload.transactions[0].amountMinor == 1999)
    #expect(payload.transactions[0].balanceAfterMinor == 101999)
}

@Test
func quotedFieldsWithCommas() throws {
    let csv = """
    booking_date,value_date,amount,currency,counterparty,memo,reference,balance
    2026-01-15,2026-01-15,100.00,CHF,"Smith, Jones & Co.",Payment,REF1,100.00
    """
    let url = try writeTempCSV(csv)
    let importer = CSVBankStatementImporter()
    let payload = try importer.parse(url, accountId: FinancialAccountID(), importJobId: ImportJobID(), sourceBlobHash: "test")

    #expect(payload.transactions.count == 1)
    #expect(payload.transactions[0].counterpartyName == "Smith, Jones & Co.")
}

@Test
func quotedFieldsWithEscapedQuotes() throws {
    let csv = """
    booking_date,value_date,amount,currency,counterparty,memo,reference,balance
    2026-01-15,2026-01-15,50.00,CHF,"The ""Best"" Shop",Payment,REF1,50.00
    """
    let url = try writeTempCSV(csv)
    let importer = CSVBankStatementImporter()
    let payload = try importer.parse(url, accountId: FinancialAccountID(), importJobId: ImportJobID(), sourceBlobHash: "test")

    #expect(payload.transactions.count == 1)
    #expect(payload.transactions[0].counterpartyName == "The \"Best\" Shop")
}

@Test
func unparseableDateSkipsRowWithWarning() throws {
    let csv = """
    booking_date,value_date,amount,currency,counterparty,memo,reference,balance
    2026-01-15,2026-01-15,100.00,CHF,Valid,Payment,REF1,100.00
    not-a-date,2026-01-15,200.00,CHF,Invalid,Payment,REF2,300.00
    """
    let url = try writeTempCSV(csv)
    let importer = CSVBankStatementImporter()
    let payload = try importer.parse(url, accountId: FinancialAccountID(), importJobId: ImportJobID(), sourceBlobHash: "test")

    #expect(payload.transactions.count == 1)
    #expect(payload.parseLog.warnings.count == 1)
    #expect(payload.parseLog.warnings[0].contains("unparseable"))
}

@Test
func missingColumnsSkipsRowWithWarning() throws {
    let csv = """
    booking_date,value_date,amount,currency,counterparty,memo,reference,balance
    2026-01-15,2026-01-15,100.00,CHF,Valid,Payment,REF1,100.00
    2026-01-16,short
    """
    let url = try writeTempCSV(csv)
    let importer = CSVBankStatementImporter()
    let payload = try importer.parse(url, accountId: FinancialAccountID(), importJobId: ImportJobID(), sourceBlobHash: "test")

    #expect(payload.transactions.count == 1)
    #expect(payload.parseLog.warnings.count == 1)
    #expect(payload.parseLog.warnings[0].contains("columns"))
}

@Test
func unparseableAmountSkipsRowWithWarning() throws {
    let csv = """
    booking_date,value_date,amount,currency,counterparty,memo,reference,balance
    2026-01-15,2026-01-15,100.00,CHF,Valid,Payment,REF1,100.00
    2026-01-16,2026-01-16,abc,CHF,Invalid,Payment,REF2,100.00
    """
    let url = try writeTempCSV(csv)
    let importer = CSVBankStatementImporter()
    let payload = try importer.parse(url, accountId: FinancialAccountID(), importJobId: ImportJobID(), sourceBlobHash: "test")

    #expect(payload.transactions.count == 1)
    #expect(payload.parseLog.warnings.count == 1)
    #expect(payload.parseLog.warnings[0].contains("unparseable amount"))
    #expect(payload.parseLog.warnings[0].contains("skipped"))
}

private func writeTempCSV(_ content: String) throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension("csv")
    try content.write(to: url, atomically: true, encoding: .utf8)
    return url
}
