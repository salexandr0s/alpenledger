import Foundation
import ALDomain
import ALStorage

public final class LedgerAccountService: Sendable {
    private let repository: any LedgerAccountRepository

    public init(storage: WorkspaceStorage) {
        self.repository = storage.ledgerAccountRepository
    }

    public func listAccounts(entityId: LegalEntityID) throws -> [LedgerAccount] {
        try repository.fetchLedgerAccounts(entityId: entityId)
    }
}
