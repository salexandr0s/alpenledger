import Foundation
import ALDomain
import ALStorage

public final class TransactionService: Sendable {
    private let transactionRepository: any TransactionRepository
    private let evidenceLinkRepository: any EvidenceLinkRepository

    public init(storage: WorkspaceStorage) {
        self.transactionRepository = storage.transactionRepository
        self.evidenceLinkRepository = storage.evidenceLinkRepository
    }

    public func listTransactions(accountId: FinancialAccountID) throws -> [Transaction] {
        try transactionRepository.fetchTransactions(accountId: accountId)
    }

    public func linkedDocumentIDs(for transactionId: TransactionID) throws -> [DocumentID] {
        let objectRef = ObjectRef(kind: .transaction, id: transactionId.rawValue)
        let links = try evidenceLinkRepository.fetchEvidenceLinks(for: objectRef)
        return links.filter { $0.status == .confirmed }.compactMap { link in
            if link.sourceRef.kind == .document, let uuid = UUID(uuidString: link.sourceRef.id) {
                return DocumentID(rawValue: uuid)
            }
            if link.targetRef.kind == .document, let uuid = UUID(uuidString: link.targetRef.id) {
                return DocumentID(rawValue: uuid)
            }
            return nil
        }
    }
}
