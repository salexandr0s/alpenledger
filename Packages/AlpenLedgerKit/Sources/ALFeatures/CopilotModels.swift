import Foundation
import ALDesignSystem
import ALDomain

public struct CopilotTaskDraft: Hashable, Sendable {
    public let answerId: String
    public let title: String
    public let summary: String
    public let sourceRef: ObjectRef?
    public let entityId: LegalEntityID?
    public let taxYearId: TaxYearID?

    public init(
        answerId: String,
        title: String,
        summary: String,
        sourceRef: ObjectRef?,
        entityId: LegalEntityID?,
        taxYearId: TaxYearID?
    ) {
        self.answerId = answerId
        self.title = title
        self.summary = summary
        self.sourceRef = sourceRef
        self.entityId = entityId
        self.taxYearId = taxYearId
    }
}

public enum CopilotAction: Hashable, Sendable {
    case openInbox(selection: InboxSelection?)
    case openTaxStudio(entityId: LegalEntityID?, taxYearId: TaxYearID?)
    case openLedger(accountId: FinancialAccountID?, transactionId: TransactionID?)
    case openDocuments(documentId: DocumentID?)
    case openSource(ObjectRef)
    case createTaskFromAnswer(CopilotTaskDraft)
}

public struct CopilotSnapshot: Sendable {
    public struct ContextItem: Identifiable, Sendable {
        public let id: String
        public let title: String
        public let value: String
        public let tone: StatusBadge.Tone
        public let systemImage: String

        public init(
            id: String,
            title: String,
            value: String,
            tone: StatusBadge.Tone,
            systemImage: String
        ) {
            self.id = id
            self.title = title
            self.value = value
            self.tone = tone
            self.systemImage = systemImage
        }
    }

    public struct PromptItem: Identifiable, Sendable {
        public let id: String
        public let title: String
        public let subtitle: String
        public let systemImage: String
        public let action: CopilotAction

        public init(id: String, title: String, subtitle: String, systemImage: String, action: CopilotAction) {
            self.id = id
            self.title = title
            self.subtitle = subtitle
            self.systemImage = systemImage
            self.action = action
        }
    }

    public struct SourceItem: Identifiable, Sendable {
        public let id: String
        public let title: String
        public let subtitle: String
        public let systemImage: String
        public let ref: ObjectRef

        public init(title: String, subtitle: String, systemImage: String, ref: ObjectRef) {
            self.id = ref.stringValue
            self.title = title
            self.subtitle = subtitle
            self.systemImage = systemImage
            self.ref = ref
        }
    }

    public struct ClaimItem: Identifiable, Sendable {
        public let id: String
        public let text: String
        public let kind: AgentAnswerClaimKind
        public let sourceRefs: [ObjectRef]

        public init(id: String, text: String, kind: AgentAnswerClaimKind, sourceRefs: [ObjectRef]) {
            self.id = id
            self.text = text
            self.kind = kind
            self.sourceRefs = sourceRefs
        }
    }

    public struct FollowUpQuestion: Identifiable, Sendable {
        public let id: String
        public let text: String
        public let sourceRefs: [ObjectRef]
        public let primaryActionTitle: String
        public let primaryAction: CopilotAction

        public init(
            id: String,
            text: String,
            sourceRefs: [ObjectRef],
            primaryActionTitle: String,
            primaryAction: CopilotAction
        ) {
            self.id = id
            self.text = text
            self.sourceRefs = sourceRefs
            self.primaryActionTitle = primaryActionTitle
            self.primaryAction = primaryAction
        }
    }

    public struct AnswerCard: Identifiable, Sendable {
        public let id: String
        public let question: String
        public let summary: String
        public let statusText: String
        public let tone: StatusBadge.Tone
        public let systemImage: String
        public let claims: [ClaimItem]
        public let sources: [SourceItem]
        public let followUpQuestions: [FollowUpQuestion]
        public let primaryActionTitle: String
        public let primaryAction: CopilotAction
        public let secondaryActionTitle: String?
        public let secondaryAction: CopilotAction?

        public init(
            id: String,
            question: String,
            summary: String,
            statusText: String,
            tone: StatusBadge.Tone,
            systemImage: String,
            claims: [ClaimItem],
            sources: [SourceItem],
            followUpQuestions: [FollowUpQuestion] = [],
            primaryActionTitle: String,
            primaryAction: CopilotAction,
            secondaryActionTitle: String? = nil,
            secondaryAction: CopilotAction? = nil
        ) {
            self.id = id
            self.question = question
            self.summary = summary
            self.statusText = statusText
            self.tone = tone
            self.systemImage = systemImage
            self.claims = claims
            self.sources = sources
            self.followUpQuestions = followUpQuestions
            self.primaryActionTitle = primaryActionTitle
            self.primaryAction = primaryAction
            self.secondaryActionTitle = secondaryActionTitle
            self.secondaryAction = secondaryAction
        }
    }

    public let title: String
    public let subtitle: String
    public let contextItems: [ContextItem]
    public let prompts: [PromptItem]
    public let answers: [AnswerCard]

    public init(
        title: String,
        subtitle: String,
        contextItems: [ContextItem],
        prompts: [PromptItem],
        answers: [AnswerCard]
    ) {
        self.title = title
        self.subtitle = subtitle
        self.contextItems = contextItems
        self.prompts = prompts
        self.answers = answers
    }
}
