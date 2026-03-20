import Foundation
import ALDomain
import ALStorage

public final class FinancialAccountService: Sendable {
    private let repository: any FinancialAccountRepository

    public init(storage: WorkspaceStorage) {
        self.repository = storage.financialAccountRepository
    }

    public func listAccounts(entityId: LegalEntityID) throws -> [FinancialAccount] {
        try repository.fetchFinancialAccounts(entityId: entityId)
    }
}
