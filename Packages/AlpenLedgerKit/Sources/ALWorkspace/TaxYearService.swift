import Foundation
import ALDomain
import ALStorage

public final class TaxYearService: Sendable {
    private let repository: any TaxYearRepository

    public init(storage: WorkspaceStorage) {
        self.repository = storage.taxYearRepository
    }

    public func listTaxYears(entityId: LegalEntityID) throws -> [TaxYear] {
        try repository.fetchTaxYears(entityId: entityId)
    }
}
