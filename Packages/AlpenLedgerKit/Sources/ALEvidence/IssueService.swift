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

    public func issue(id: IssueID) throws -> Issue? {
        try repository.fetchIssue(id: id)
    }

    @discardableResult
    public func resolveIssue(_ issueId: IssueID, now: Date = .now) throws -> Issue {
        try updateIssueStatus(issueId, status: .resolved, eventType: .issueResolved, now: now)
    }

    @discardableResult
    public func dismissIssue(_ issueId: IssueID, now: Date = .now) throws -> Issue {
        try updateIssueStatus(issueId, status: .dismissed, eventType: .issueDismissed, now: now)
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
        let resolvedStatus: IssueStatus
        if previousStatus == .dismissed, status == .open {
            resolvedStatus = .dismissed
        } else {
            resolvedStatus = status
        }
        issue.entityId = entityId
        issue.taxYearId = taxYearId
        issue.issueCode = code
        issue.severity = severity
        issue.status = resolvedStatus
        issue.summary = summary
        issue.objectRef = objectRef
        issue.relatedRef = relatedRef
        issue.lastDetectedAt = now

        try repository.saveIssue(issue)

        if previousStatus != .open, resolvedStatus == .open {
            try auditLogger.log(
                eventType: .issueOpened,
                objectRef: ObjectRef(kind: .issue, id: issue.id.rawValue),
                payload: summary
            )
        } else if previousStatus != .resolved, resolvedStatus == .resolved {
            try auditLogger.log(
                eventType: .issueResolved,
                objectRef: ObjectRef(kind: .issue, id: issue.id.rawValue),
                payload: summary
            )
        }

        return issue
    }

    @discardableResult
    private func updateIssueStatus(
        _ issueId: IssueID,
        status: IssueStatus,
        eventType: AuditEventType,
        now: Date
    ) throws -> Issue {
        guard var issue = try repository.fetchIssue(id: issueId) else {
            throw DomainError.workspaceNotFound
        }
        guard issue.status != status else {
            return issue
        }

        issue.status = status
        issue.lastDetectedAt = now
        try repository.saveIssue(issue)
        try auditLogger.log(
            actorType: .user,
            actorId: "user",
            eventType: eventType,
            objectRef: ObjectRef(kind: .issue, id: issue.id.rawValue),
            payload: issue.summary
        )
        return issue
    }
}
