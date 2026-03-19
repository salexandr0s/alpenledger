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
        currency: "CHF"
    )
    let creditLine = try JournalLine(
        journalEntryId: entryId,
        ledgerAccountId: LedgerAccountID(),
        debitMinor: 0,
        creditMinor: 1000,
        currency: "CHF"
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
        currency: "CHF"
    )
    let creditLine = try JournalLine(
        journalEntryId: entryId,
        ledgerAccountId: LedgerAccountID(),
        debitMinor: 0,
        creditMinor: 900,
        currency: "CHF"
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
