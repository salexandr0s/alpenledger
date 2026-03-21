import Foundation
import GRDB
import ALDomain

public protocol InvoiceRecordRepository: Sendable {
    func fetchInvoiceRecords(entityId: LegalEntityID) throws -> [InvoiceRecord]
    func fetchInvoiceRecord(id: InvoiceRecordID) throws -> InvoiceRecord?
    func fetchInvoiceRecord(documentId: DocumentID) throws -> InvoiceRecord?
    func saveInvoiceRecord(_ invoiceRecord: InvoiceRecord) throws
    func deleteInvoiceRecord(id: InvoiceRecordID) throws
}

public final class GRDBInvoiceRecordRepository: InvoiceRecordRepository, Sendable {
    private let dbPool: DatabasePool

    public init(dbPool: DatabasePool) {
        self.dbPool = dbPool
    }

    public func fetchInvoiceRecords(entityId: LegalEntityID) throws -> [InvoiceRecord] {
        try dbPool.read { db in
            try InvoiceRecord
                .filter(Column("entityId") == entityId)
                .order(Column("createdAt").desc)
                .fetchAll(db)
        }
    }

    public func fetchInvoiceRecord(id: InvoiceRecordID) throws -> InvoiceRecord? {
        try dbPool.read { db in
            try InvoiceRecord.fetchOne(db, key: id)
        }
    }

    public func fetchInvoiceRecord(documentId: DocumentID) throws -> InvoiceRecord? {
        try dbPool.read { db in
            try InvoiceRecord
                .filter(Column("documentId") == documentId)
                .fetchOne(db)
        }
    }

    public func saveInvoiceRecord(_ invoiceRecord: InvoiceRecord) throws {
        try dbPool.write { db in
            try invoiceRecord.save(db)
        }
    }

    public func deleteInvoiceRecord(id: InvoiceRecordID) throws {
        try dbPool.write { db in
            _ = try InvoiceRecord.deleteOne(db, key: id)
        }
    }
}
