import Foundation

public enum EvidenceLinkType: String, Codable, CaseIterable, Sendable {
    case documentToTransaction
}

public enum EvidenceLinkStatus: String, Codable, CaseIterable, Sendable {
    case proposed
    case confirmed
    case revoked
}

public enum EvidenceActorKind: String, Codable, CaseIterable, Sendable {
    case user
    case agent
}

public struct EvidenceLink: Hashable, Codable, Sendable {
    public let id: EvidenceLinkID
    public var sourceRef: ObjectRef
    public var targetRef: ObjectRef
    public var linkType: EvidenceLinkType
    public var status: EvidenceLinkStatus
    public var confidence: Double
    public var createdByKind: EvidenceActorKind
    public var approvalRequired: Bool
    public var reason: String?

    public init(
        id: EvidenceLinkID = EvidenceLinkID(),
        sourceRef: ObjectRef,
        targetRef: ObjectRef,
        linkType: EvidenceLinkType = .documentToTransaction,
        status: EvidenceLinkStatus = .confirmed,
        confidence: Double = 1.0,
        createdByKind: EvidenceActorKind = .user,
        approvalRequired: Bool = false,
        reason: String? = nil
    ) {
        self.id = id
        self.sourceRef = sourceRef
        self.targetRef = targetRef
        self.linkType = linkType
        self.status = status
        self.confidence = confidence
        self.createdByKind = createdByKind
        self.approvalRequired = approvalRequired
        self.reason = reason
    }
}
