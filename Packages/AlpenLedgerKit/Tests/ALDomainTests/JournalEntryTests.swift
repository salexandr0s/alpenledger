import Foundation
import Testing
@testable import ALDomain

@Test
func journalEntryBalances() throws {
    let entityId = LegalEntityID()
    let entryId = JournalEntryID()
    let debitLine = try JournalLine(
        journalEntryId: entryId,
        ledgerAccountId: LedgerAccountID(),
        debitMinor: 1000,
        creditMinor: 0,
        currency: .chf
    )
    let creditLine = try JournalLine(
        journalEntryId: entryId,
        ledgerAccountId: LedgerAccountID(),
        debitMinor: 0,
        creditMinor: 1000,
        currency: .chf
    )

    let entry = try JournalEntry(
        id: entryId,
        entityId: entityId,
        entryNumber: "JE-1",
        effectiveDate: .now,
        createdBy: "test",
        lines: [debitLine, creditLine]
    )
    #expect(entry.lines.count == 2)
}

@Test
func journalEntryRejectsUnbalancedLines() throws {
    let entryId = JournalEntryID()
    let debitLine = try JournalLine(
        journalEntryId: entryId,
        ledgerAccountId: LedgerAccountID(),
        debitMinor: 1000,
        creditMinor: 0,
        currency: .chf
    )
    let creditLine = try JournalLine(
        journalEntryId: entryId,
        ledgerAccountId: LedgerAccountID(),
        debitMinor: 0,
        creditMinor: 900,
        currency: .chf
    )

    #expect(throws: DomainError.self) {
        _ = try JournalEntry(
            id: entryId,
            entityId: LegalEntityID(),
            entryNumber: "JE-2",
            effectiveDate: .now,
            createdBy: "test",
            lines: [debitLine, creditLine]
        )
    }
}

@Test
func journalEntryRejectsEmptyLines() throws {
    #expect(throws: DomainError.self) {
        _ = try JournalEntry(
            entityId: LegalEntityID(),
            entryNumber: "JE-EMPTY",
            effectiveDate: .now,
            createdBy: "test",
            lines: []
        )
    }
}

@Test
func journalLineCarriesTaxCodeMapping() throws {
    let line = try JournalLine(
        journalEntryId: JournalEntryID(),
        ledgerAccountId: LedgerAccountID(),
        debitMinor: 10810,
        creditMinor: 0,
        currency: .chf,
        taxCode: "CH-VAT-INPUT-STD"
    )

    #expect(line.taxCode == "CH-VAT-INPUT-STD")
}
