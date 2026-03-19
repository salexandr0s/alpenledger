import Foundation
import ALAudit
import ALDomain
import ALStorage

public final class IssueService: @unchecked Sendable {
    private let storage: WorkspaceStorage
    private let repository: any IssueRepository
    private let auditLogger: AuditLogger

    public init(storage: WorkspaceStorage, auditLogger: AuditLogger) {
        self.storage = storage
        self.repository = storage.issueRepository
        self.auditLogger = auditLogger
    }

    public func listIssues(
        entityId: LegalEntityID? = nil,
        taxYearId: TaxYearID? = nil,
        status: IssueStatus? = nil
    ) throws -> [Issue] {
        try repository.fetchIssues(
            workspaceId: storage.manifest.workspace.id,
            entityId: entityId,
            taxYearId: taxYearId,
            status: status
        )
    }

    @discardableResult
    public func syncIssue(
        fingerprint: String,
        entityId: LegalEntityID?,
        taxYearId: TaxYearID?,
        code: IssueCode,
        severity: IssueSeverity,
        status: IssueStatus,
        summary: String,
        objectRef: ObjectRef,
        relatedRef: ObjectRef? = nil,
        now: Date
    ) throws -> Issue {
        let existing = try repository.fetchIssue(fingerprint: fingerprint)
        var issue = existing ?? Issue(
            fingerprint: fingerprint,
            workspaceId: storage.manifest.workspace.id,
            entityId: entityId,
            taxYearId: taxYearId,
            issueCode: code,
            severity: severity,
            status: status,
            summary: summary,
            objectRef: objectRef,
            relatedRef: relatedRef,
            firstDetectedAt: now,
            lastDetectedAt: now
        )

        let previousStatus = existing?.status
        issue.entityId = entityId
        issue.taxYearId = taxYearId
        issue.issueCode = code
        issue.severity = severity
        issue.status = status
        issue.summary = summary
        issue.objectRef = objectRef
        issue.relatedRef = relatedRef
        issue.lastDetectedAt = now

        try repository.saveIssue(issue)

        if previousStatus != .open, status == .open {
            try auditLogger.log(
                eventType: .issueOpened,
                objectRef: ObjectRef(kind: .issue, id: issue.id.rawValue),
                payload: summary
            )
        } else if previousStatus == .open, status == .resolved {
            try auditLogger.log(
                eventType: .issueResolved,
                objectRef: ObjectRef(kind: .issue, id: issue.id.rawValue),
                payload: summary
            )
        }

        return issue
    }
}
