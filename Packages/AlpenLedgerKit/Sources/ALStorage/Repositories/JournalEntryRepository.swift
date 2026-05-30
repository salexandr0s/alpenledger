import Foundation
import GRDB
import ALDomain

public protocol JournalEntryRepository: Sendable {
    func fetchJournalEntry(id: JournalEntryID) throws -> JournalEntry?
    func fetchJournalEntry(entityId: LegalEntityID, entryNumber: String) throws -> JournalEntry?
    func fetchJournalEntries(entityId: LegalEntityID, taxYearId: TaxYearID?) throws -> [JournalEntry]
    func saveJournalEntry(_ entry: JournalEntry) throws
}

public final class GRDBJournalEntryRepository: JournalEntryRepository, Sendable {
    private let dbPool: DatabasePool

    public init(dbPool: DatabasePool) {
        self.dbPool = dbPool
    }

    public func fetchJournalEntry(id: JournalEntryID) throws -> JournalEntry? {
        try dbPool.read { db in
            guard let row = try Row.fetchOne(
                db,
                sql: "SELECT * FROM journalEntries WHERE id = ?",
                arguments: [id]
            ) else {
                return nil
            }
            return try decodeJournalEntry(row: row, db: db)
        }
    }

    public func fetchJournalEntry(entityId: LegalEntityID, entryNumber: String) throws -> JournalEntry? {
        try dbPool.read { db in
            guard let row = try Row.fetchOne(
                db,
                sql: "SELECT * FROM journalEntries WHERE entityId = ? AND entryNumber = ?",
                arguments: [entityId, entryNumber]
            ) else {
                return nil
            }
            return try decodeJournalEntry(row: row, db: db)
        }
    }

    public func fetchJournalEntries(entityId: LegalEntityID, taxYearId: TaxYearID? = nil) throws -> [JournalEntry] {
        try dbPool.read { db in
            let rows: [Row]
            if let taxYearId {
                rows = try Row.fetchAll(
                    db,
                    sql: """
                    SELECT *
                    FROM journalEntries
                    WHERE entityId = ? AND taxYearId = ?
                    ORDER BY effectiveDate DESC, entryNumber DESC
                    """,
                    arguments: [entityId, taxYearId]
                )
            } else {
                rows = try Row.fetchAll(
                    db,
                    sql: """
                    SELECT *
                    FROM journalEntries
                    WHERE entityId = ?
                    ORDER BY effectiveDate DESC, entryNumber DESC
                    """,
                    arguments: [entityId]
                )
            }
            return try rows.map { try decodeJournalEntry(row: $0, db: db) }
        }
    }

    public func saveJournalEntry(_ entry: JournalEntry) throws {
        guard entry.lines.allSatisfy({ $0.journalEntryId == entry.id }) else {
            throw DomainError.invalidJournalLine
        }

        try dbPool.write { db in
            let exists = try String.fetchOne(
                db,
                sql: "SELECT id FROM journalEntries WHERE id = ?",
                arguments: [entry.id]
            ) != nil

            if exists {
                try db.execute(
                    sql: """
                    UPDATE journalEntries
                    SET entityId = ?,
                        taxYearId = ?,
                        entryNumber = ?,
                        effectiveDate = ?,
                        kind = ?,
                        status = ?,
                        memo = ?,
                        reversalOfId = ?,
                        createdBy = ?,
                        approvedBy = ?,
                        approvedAt = ?
                    WHERE id = ?
                    """,
                    arguments: journalEntryArguments(entry, includeIdAtEnd: true)
                )
            } else {
                try db.execute(
                    sql: """
                    INSERT INTO journalEntries (
                        id,
                        entityId,
                        taxYearId,
                        entryNumber,
                        effectiveDate,
                        kind,
                        status,
                        memo,
                        reversalOfId,
                        createdBy,
                        approvedBy,
                        approvedAt
                    )
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    arguments: journalEntryArguments(entry, includeIdAtBeginning: true)
                )
            }

            try db.execute(
                sql: "DELETE FROM journalLines WHERE journalEntryId = ?",
                arguments: [entry.id]
            )

            for line in entry.lines {
                try db.execute(
                    sql: """
                    INSERT INTO journalLines (
                        id,
                        journalEntryId,
                        ledgerAccountId,
                        debitMinor,
                        creditMinor,
                        currency,
                        taxCode,
                        sourceObjectRef,
                        memo
                    )
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    arguments: [
                        line.id,
                        line.journalEntryId,
                        line.ledgerAccountId,
                        line.debitMinor,
                        line.creditMinor,
                        line.currency.rawValue,
                        line.taxCode,
                        line.sourceObjectRef?.stringValue,
                        line.memo,
                    ]
                )
            }
        }
    }

    private func decodeJournalEntry(row: Row, db: Database) throws -> JournalEntry {
        let entryId: JournalEntryID = row["id"]
        let lineRows = try Row.fetchAll(
            db,
            sql: "SELECT * FROM journalLines WHERE journalEntryId = ? ORDER BY rowid",
            arguments: [entryId]
        )
        let lines = try lineRows.map(decodeJournalLine(row:))

        let kindRaw: String = row["kind"]
        let statusRaw: String = row["status"]
        guard let kind = JournalEntryKind(rawValue: kindRaw),
              let status = JournalEntryStatus(rawValue: statusRaw)
        else {
            throw DomainError.invalidJournalLine
        }

        return try JournalEntry(
            id: entryId,
            entityId: row["entityId"],
            taxYearId: row["taxYearId"],
            entryNumber: row["entryNumber"],
            effectiveDate: row["effectiveDate"],
            kind: kind,
            status: status,
            memo: row["memo"],
            reversalOfId: row["reversalOfId"],
            createdBy: row["createdBy"],
            approvedBy: row["approvedBy"],
            approvedAt: row["approvedAt"],
            lines: lines
        )
    }

    private func decodeJournalLine(row: Row) throws -> JournalLine {
        try JournalLine(
            id: row["id"],
            journalEntryId: row["journalEntryId"],
            ledgerAccountId: row["ledgerAccountId"],
            debitMinor: row["debitMinor"],
            creditMinor: row["creditMinor"],
            currency: row["currency"],
            taxCode: row["taxCode"],
            sourceObjectRef: row["sourceObjectRef"],
            memo: row["memo"]
        )
    }

    private func journalEntryArguments(
        _ entry: JournalEntry,
        includeIdAtBeginning: Bool = false,
        includeIdAtEnd: Bool = false
    ) -> StatementArguments {
        var arguments = StatementArguments()
        if includeIdAtBeginning {
            arguments += [entry.id]
        }
        arguments += [
            entry.entityId,
            entry.taxYearId,
            entry.entryNumber,
            entry.effectiveDate,
            entry.kind.rawValue,
            entry.status.rawValue,
            entry.memo,
            entry.reversalOfId,
            entry.createdBy,
            entry.approvedBy,
            entry.approvedAt,
        ]
        if includeIdAtEnd {
            arguments += [entry.id]
        }
        return arguments
    }
}
