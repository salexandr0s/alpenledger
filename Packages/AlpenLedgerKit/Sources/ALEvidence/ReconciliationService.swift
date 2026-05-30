import Foundation
import ALAudit
import ALDomain
import ALStorage

public final class ReconciliationService: Sendable {
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

    public func proposal(id: AgentProposalID) throws -> AgentProposal? {
        try repository.fetchAgentProposal(id: id)
    }

    @discardableResult
    public func approveDocumentMatchProposal(
        _ proposalId: AgentProposalID,
        actorId: String = "user",
        reason: String = "Approved document-to-transaction match.",
        now: Date = .now
    ) throws -> AgentProposal {
        guard var proposal = try repository.fetchAgentProposal(id: proposalId) else {
            throw DomainError.proposalNotFound
        }
        guard proposal.proposalType == .documentLinkReview else {
            throw DomainError.invalidProposal
        }
        guard let documentId = documentId(from: proposal.targetRef),
              let transactionRef = proposal.relatedRef,
              let transactionId = transactionId(from: transactionRef)
        else {
            throw DomainError.invalidProposal
        }
        if proposal.status == .rejected {
            throw DomainError.invalidProposal
        }

        let scope = try validateDocumentLink(documentId: documentId, transactionId: transactionId)
        if scope.document != scope.scopedDocument {
            try storage.documentRepository.saveDocument(scope.scopedDocument)
            try storage.searchIndex.indexDocument(scope.scopedDocument)
        }

        let documentRef = ObjectRef(kind: .document, id: documentId.rawValue)
        let confirmedLink = try confirmDocumentLink(
            documentRef: documentRef,
            transactionRef: transactionRef,
            reason: reason
        )

        if proposal.status != .resolved {
            proposal.status = .resolved
            proposal.decidedAt = now
            proposal.decidedBy = actorId
            proposal.decisionReason = reason
            try repository.saveAgentProposal(proposal)
            try auditLogger.log(
                actorType: .user,
                actorId: actorId,
                eventType: .proposalResolved,
                objectRef: ObjectRef(kind: .agentProposal, id: proposal.id.rawValue),
                payload: proposal.summary
            )
        }

        if let confirmedLink {
            try auditLogger.log(
                actorType: .user,
                actorId: actorId,
                eventType: .evidenceLinked,
                objectRef: ObjectRef(kind: .evidenceLink, id: confirmedLink.id.rawValue),
                payload: proposal.summary
            )
        }
        return proposal
    }

    @discardableResult
    public func rejectProposal(
        _ proposalId: AgentProposalID,
        actorId: String = "user",
        reason: String = "Rejected by user",
        now: Date = .now
    ) throws -> AgentProposal {
        guard var proposal = try repository.fetchAgentProposal(id: proposalId) else {
            throw DomainError.proposalNotFound
        }
        guard proposal.status != .rejected else {
            return proposal
        }

        proposal.status = .rejected
        proposal.decidedAt = now
        proposal.decidedBy = actorId
        proposal.decisionReason = reason
        try repository.saveAgentProposal(proposal)
        try auditLogger.log(
            actorType: .user,
            actorId: actorId,
            eventType: .proposalRejected,
            objectRef: ObjectRef(kind: .agentProposal, id: proposal.id.rawValue),
            payload: proposal.summary
        )
        return proposal
    }

    @discardableResult
    public func revokeDocumentMatchProposalApproval(
        _ proposalId: AgentProposalID,
        actorId: String = "user",
        reason: String = "Revoked approved document-to-transaction match.",
        now: Date = .now
    ) throws -> AgentProposal {
        guard var proposal = try repository.fetchAgentProposal(id: proposalId) else {
            throw DomainError.proposalNotFound
        }
        guard proposal.proposalType == .documentLinkReview,
              proposal.status == .resolved,
              let documentId = documentId(from: proposal.targetRef),
              let transactionRef = proposal.relatedRef,
              let transactionId = transactionId(from: transactionRef),
              try storage.documentRepository.fetchDocument(id: documentId) != nil,
              try storage.transactionRepository.fetchTransactions(ids: [transactionId]).isEmpty == false
        else {
            throw DomainError.invalidProposal
        }

        let documentRef = ObjectRef(kind: .document, id: documentId.rawValue)
        let revokedLinks = try revokeConfirmedDocumentLinks(
            documentRef: documentRef,
            transactionRef: transactionRef,
            reason: reason
        )
        guard revokedLinks.isEmpty == false else {
            throw DomainError.invalidProposal
        }

        proposal.status = .rejected
        proposal.decidedAt = now
        proposal.decidedBy = actorId
        proposal.decisionReason = reason
        try repository.saveAgentProposal(proposal)
        try auditLogger.log(
            actorType: .user,
            actorId: actorId,
            eventType: .proposalRejected,
            objectRef: ObjectRef(kind: .agentProposal, id: proposal.id.rawValue),
            payload: proposal.summary
        )
        for revokedLink in revokedLinks {
            try auditLogger.log(
                actorType: .user,
                actorId: actorId,
                eventType: .evidenceLinkRevoked,
                objectRef: ObjectRef(kind: .evidenceLink, id: revokedLink.id.rawValue),
                payload: proposal.summary
            )
        }
        return proposal
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
            relatedRef: nil,
            summary: summary,
            rationale: rationale,
            confidence: 0.25,
            status: hasConfirmedLink ? .resolved : .pending,
            createdAt: now,
            decidedAt: hasConfirmedLink ? now : nil
        )

        let previousStatus = existing?.status
        let resolvedStatus: ProposalStatus
        if previousStatus == .rejected, hasConfirmedLink == false {
            resolvedStatus = .rejected
        } else {
            resolvedStatus = hasConfirmedLink ? .resolved : .pending
        }
        proposal.summary = summary
        proposal.rationale = rationale
        proposal.confidence = 0.25
        proposal.targetRef = ObjectRef(kind: .document, id: document.id.rawValue)
        proposal.relatedRef = nil
        proposal.status = resolvedStatus
        switch resolvedStatus {
        case .pending:
            proposal.decidedAt = nil
            proposal.decidedBy = nil
            proposal.decisionReason = nil
        case .resolved:
            proposal.decidedAt = now
            proposal.decidedBy = "system"
            proposal.decisionReason = "Confirmed document-to-transaction link exists."
        case .rejected:
            proposal.decidedAt = existing?.decidedAt ?? now
            proposal.decidedBy = existing?.decidedBy ?? "user"
            proposal.decisionReason = existing?.decisionReason ?? "Rejected by user"
        }

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
                link.sourceRef.kind == .document ||
                    link.targetRef.kind == .document ||
                    link.sourceRef.kind == .transaction ||
                    link.targetRef.kind == .transaction
            )
        }).flatMap { link in
            if link.sourceRef != objectRef {
                return link.sourceRef
            }
            return link.targetRef
        }
    }

    private func confirmDocumentLink(
        documentRef: ObjectRef,
        transactionRef: ObjectRef,
        reason: String
    ) throws -> EvidenceLink? {
        let existingLinks = try evidenceLinkRepository.fetchEvidenceLinks(for: transactionRef)
        if existingLinks.contains(where: {
            $0.status == .confirmed &&
                (($0.sourceRef == documentRef && $0.targetRef == transactionRef) ||
                    ($0.sourceRef == transactionRef && $0.targetRef == documentRef))
        }) {
            return nil
        }

        let link = EvidenceLink(
            sourceRef: documentRef,
            targetRef: transactionRef,
            linkType: .documentToTransaction,
            status: .confirmed,
            confidence: 1.0,
            createdByKind: .user,
            approvalRequired: false,
            reason: reason
        )
        try evidenceLinkRepository.saveEvidenceLink(link)
        return link
    }

    private func revokeConfirmedDocumentLinks(
        documentRef: ObjectRef,
        transactionRef: ObjectRef,
        reason: String
    ) throws -> [EvidenceLink] {
        let existingLinks = try evidenceLinkRepository.fetchEvidenceLinks(for: transactionRef)
        let matchingLinks = existingLinks.filter {
            $0.status == .confirmed &&
                (($0.sourceRef == documentRef && $0.targetRef == transactionRef) ||
                    ($0.sourceRef == transactionRef && $0.targetRef == documentRef))
        }

        var revokedLinks: [EvidenceLink] = []
        for var link in matchingLinks {
            link.status = .revoked
            link.reason = reason
            try evidenceLinkRepository.saveEvidenceLink(link)
            revokedLinks.append(link)
        }
        return revokedLinks
    }

    private func validateDocumentLink(
        documentId: DocumentID,
        transactionId: TransactionID
    ) throws -> (document: Document, scopedDocument: Document, transaction: Transaction, account: FinancialAccount) {
        guard let document = try storage.documentRepository.fetchDocument(id: documentId),
              document.workspaceId == storage.manifest.workspace.id,
              document.status == .active,
              let transaction = try storage.transactionRepository.fetchTransactions(ids: [transactionId]).first,
              let account = try storage.financialAccountRepository.fetchFinancialAccount(id: transaction.accountId)
        else {
            throw DomainError.invalidEvidenceLink
        }

        return (
            document,
            try scopedDocument(document, entityId: account.entityId),
            transaction,
            account
        )
    }

    private func scopedDocument(_ document: Document, entityId: LegalEntityID) throws -> Document {
        if let documentEntityId = document.entityId {
            guard documentEntityId == entityId else {
                throw DomainError.invalidEvidenceLink
            }
            return document
        }

        var scopedDocument = document
        scopedDocument.entityId = entityId
        return scopedDocument
    }

    private func documentId(from ref: ObjectRef) -> DocumentID? {
        guard ref.kind == .document, let uuid = UUID(uuidString: ref.id) else { return nil }
        return DocumentID(rawValue: uuid)
    }

    private func transactionId(from ref: ObjectRef) -> TransactionID? {
        guard ref.kind == .transaction, let uuid = UUID(uuidString: ref.id) else { return nil }
        return TransactionID(rawValue: uuid)
    }
}
