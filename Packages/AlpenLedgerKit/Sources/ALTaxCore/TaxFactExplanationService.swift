import Foundation
import ALDomain
import ALStorage

public struct TaxFactSourceSummary: Hashable, Sendable {
    public let sourceRef: ObjectRef
    public let title: String
    public let detail: String

    public init(sourceRef: ObjectRef, title: String, detail: String) {
        self.sourceRef = sourceRef
        self.title = title
        self.detail = detail
    }
}

public struct TaxFactExplanation: Hashable, Sendable {
    public let fact: TaxFact
    public let summary: String
    public let sourceSummaries: [TaxFactSourceSummary]
    public let missingSourceRefs: [ObjectRef]
    public let overrideReason: String?

    public init(
        fact: TaxFact,
        summary: String,
        sourceSummaries: [TaxFactSourceSummary],
        missingSourceRefs: [ObjectRef],
        overrideReason: String?
    ) {
        self.fact = fact
        self.summary = summary
        self.sourceSummaries = sourceSummaries
        self.missingSourceRefs = missingSourceRefs
        self.overrideReason = overrideReason
    }
}

public final class TaxFactExplanationService: Sendable {
    private let storage: WorkspaceStorage

    public init(storage: WorkspaceStorage) {
        self.storage = storage
    }

    public func explainFact(_ factId: TaxFactID) throws -> TaxFactExplanation {
        guard let fact = try storage.taxFactRepository.fetchTaxFact(id: factId) else {
            throw DomainError.taxFactNotFound
        }

        var sourceSummaries: [TaxFactSourceSummary] = []
        var missingSourceRefs: [ObjectRef] = []
        for sourceRef in fact.provenanceRefs {
            if let summary = try sourceSummary(for: sourceRef) {
                sourceSummaries.append(summary)
            } else {
                missingSourceRefs.append(sourceRef)
            }
        }

        return TaxFactExplanation(
            fact: fact,
            summary: summary(for: fact, sourceCount: sourceSummaries.count, missingCount: missingSourceRefs.count),
            sourceSummaries: sourceSummaries,
            missingSourceRefs: missingSourceRefs,
            overrideReason: fact.overrideReason
        )
    }

    private func sourceSummary(for sourceRef: ObjectRef) throws -> TaxFactSourceSummary? {
        switch sourceRef.kind {
        case .document:
            guard let uuid = UUID(uuidString: sourceRef.id),
                  let document = try storage.documentRepository.fetchDocument(id: DocumentID(rawValue: uuid))
            else {
                return nil
            }
            return TaxFactSourceSummary(
                sourceRef: sourceRef,
                title: document.originalFilename,
                detail: "\(document.documentType.rawValue), \(document.metadataStatus.rawValue)"
            )
        case .transaction:
            guard let uuid = UUID(uuidString: sourceRef.id),
                  let transaction = try storage.transactionRepository.fetchTransactions(ids: [TransactionID(rawValue: uuid)]).first
            else {
                return nil
            }
            return TaxFactSourceSummary(
                sourceRef: sourceRef,
                title: transaction.counterpartyName,
                detail: transaction.memo
            )
        default:
            return nil
        }
    }

    private func summary(for fact: TaxFact, sourceCount: Int, missingCount: Int) -> String {
        if fact.status == .overridden {
            return "Tax fact \(fact.conceptCode) is a user override with \(sourceCount) resolved source ref(s) and \(missingCount) missing source ref(s)."
        }
        return "Tax fact \(fact.conceptCode) is \(fact.status.rawValue) with \(sourceCount) resolved source ref(s) and \(missingCount) missing source ref(s)."
    }
}
