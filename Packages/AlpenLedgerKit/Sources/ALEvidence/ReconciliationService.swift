import Foundation
import ALAudit
import ALDomain
import ALStorage

public final class ReconciliationService: @unchecked Sendable {
    private let storage: WorkspaceStorage
    private let repository: any AgentProposalRepository
    private let evidenceLinkRepository: any EvidenceLinkRepository
    private let auditLogger: AuditLogger

    public init(storage: WorkspaceStorage, auditLogger: AuditLogger) {
        self.storage = storage
        self.repository = storage.agentProposalRepository
        self.evidenceLinkRepository = storage.evidenceLinkRepository
        self.auditLogger = auditLogger
    }

    public func listProposals(status: ProposalStatus? = nil) throws -> [AgentProposal] {
        try repository.fetchAgentProposals(workspaceId: storage.manifest.workspace.id, status: status)
    }

    @discardableResult
    public func syncDocumentLinkProposal(
        for document: Document,
        hasConfirmedLink: Bool,
        now: Date
    ) throws -> AgentProposal {
        let fingerprint = "document-link-review|\(document.id)"
        let summary = "Review document link for \(document.originalFilename)"
        let rationale = "Imported \(document.documentType.rawValue) has no confirmed transaction link."
        let existing = try repository.fetchAgentProposal(fingerprint: fingerprint)
        var proposal = existing ?? AgentProposal(
            fingerprint: fingerprint,
            workspaceId: storage.manifest.workspace.id,
            agentKind: .systemHeuristics,
            proposalType: .documentLinkReview,
            targetRef: ObjectRef(kind: .document, id: document.id.rawValue),
            summary: summary,
            rationale: rationale,
            confidence: 0.25,
            status: hasConfirmedLink ? .resolved : .pending,
            createdAt: now,
            decidedAt: hasConfirmedLink ? now : nil
        )

        let previousStatus = existing?.status
        proposal.summary = summary
        proposal.rationale = rationale
        proposal.confidence = 0.25
        proposal.targetRef = ObjectRef(kind: .document, id: document.id.rawValue)
        proposal.status = hasConfirmedLink ? .resolved : .pending
        proposal.decidedAt = hasConfirmedLink ? now : nil

        try repository.saveAgentProposal(proposal)

        if previousStatus != .pending, proposal.status == .pending {
            try auditLogger.log(
                eventType: .proposalCreated,
                objectRef: ObjectRef(kind: .agentProposal, id: proposal.id.rawValue),
                payload: proposal.summary
            )
        } else if previousStatus == .pending, proposal.status == .resolved {
            try auditLogger.log(
                eventType: .proposalResolved,
                objectRef: ObjectRef(kind: .agentProposal, id: proposal.id.rawValue),
                payload: proposal.summary
            )
        }

        return proposal
    }

    public func hasConfirmedDocumentLink(for transactionId: TransactionID) throws -> ObjectRef? {
        try firstConfirmedLinkedDocumentRef(for: ObjectRef(kind: .transaction, id: transactionId.rawValue))
    }

    public func hasConfirmedTransactionLink(for documentId: DocumentID) throws -> Bool {
        try firstConfirmedLinkedDocumentRef(for: ObjectRef(kind: .document, id: documentId.rawValue)) != nil
    }

    private func firstConfirmedLinkedDocumentRef(for objectRef: ObjectRef) throws -> ObjectRef? {
        let links = try evidenceLinkRepository.fetchEvidenceLinks(for: objectRef)
        return links.first(where: { link in
            link.status == .confirmed && (
                link.sourceRef.kind == .document || link.targetRef.kind == .document || link.sourceRef.kind == .transaction || link.targetRef.kind == .transaction
            )
        }).flatMap { link in
            if link.sourceRef != objectRef {
                return link.sourceRef
            }
            return link.targetRef
        }
    }
}
