import Foundation

public enum LegalEntityKind: String, Codable, CaseIterable, Sendable {
    case naturalPerson
    case soleProprietor
    case corporation
}

public struct LegalEntity: Hashable, Codable, Sendable {
    public let id: LegalEntityID
    public let workspaceId: WorkspaceID
    public var kind: LegalEntityKind
    public var legalName: String
    public var displayName: String
    public var country: String
    public var canton: CantonCode?
    public var taxIdOrUID: String?
    public var fiscalYearStartMonth: Int
    public var fiscalYearStartDay: Int
    public let parentEntityId: LegalEntityID?

    public init(
        id: LegalEntityID = LegalEntityID(),
        workspaceId: WorkspaceID,
        kind: LegalEntityKind,
        legalName: String,
        displayName: String,
        country: String = "CH",
        canton: CantonCode? = nil,
        taxIdOrUID: String? = nil,
        fiscalYearStartMonth: Int = 1,
        fiscalYearStartDay: Int = 1,
        parentEntityId: LegalEntityID? = nil
    ) {
        self.id = id
        self.workspaceId = workspaceId
        self.kind = kind
        self.legalName = legalName
        self.displayName = displayName
        self.country = country
        self.canton = canton
        self.taxIdOrUID = taxIdOrUID
        self.fiscalYearStartMonth = fiscalYearStartMonth
        self.fiscalYearStartDay = fiscalYearStartDay
        self.parentEntityId = parentEntityId
    }
}
