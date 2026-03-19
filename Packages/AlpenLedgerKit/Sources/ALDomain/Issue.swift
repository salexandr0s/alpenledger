import Foundation

public enum IssueCode: String, Codable, CaseIterable, Sendable {
    case missingStatementCoverage
    case missingExpenseEvidence
}

public enum IssueSeverity: String, Codable, CaseIterable, Sendable {
    case warning
    case blocking
}

public enum IssueStatus: String, Codable, CaseIterable, Sendable {
    case open
    case resolved
}

public struct Issue: Hashable, Codable, Sendable {
    public let id: IssueID
    public var fingerprint: String
    public let workspaceId: WorkspaceID
    public var entityId: LegalEntityID?
    public var taxYearId: TaxYearID?
    public var issueCode: IssueCode
    public var severity: IssueSeverity
    public var status: IssueStatus
    public var summary: String
    public var objectRef: ObjectRef
    public var relatedRef: ObjectRef?
    public var firstDetectedAt: Date
    public var lastDetectedAt: Date

    public init(
        id: IssueID = IssueID(),
        fingerprint: String,
        workspaceId: WorkspaceID,
        entityId: LegalEntityID? = nil,
        taxYearId: TaxYearID? = nil,
        issueCode: IssueCode,
        severity: IssueSeverity,
        status: IssueStatus,
        summary: String,
        objectRef: ObjectRef,
        relatedRef: ObjectRef? = nil,
        firstDetectedAt: Date = .now,
        lastDetectedAt: Date = .now
    ) {
        self.id = id
        self.fingerprint = fingerprint
        self.workspaceId = workspaceId
        self.entityId = entityId
        self.taxYearId = taxYearId
        self.issueCode = issueCode
        self.severity = severity
        self.status = status
        self.summary = summary
        self.objectRef = objectRef
        self.relatedRef = relatedRef
        self.firstDetectedAt = firstDetectedAt
        self.lastDetectedAt = lastDetectedAt
    }
}
