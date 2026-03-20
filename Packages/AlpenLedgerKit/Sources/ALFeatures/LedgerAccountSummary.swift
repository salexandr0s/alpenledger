import Foundation
import ALDesignSystem
import ALDomain

public struct LedgerAccountSummary: Identifiable, Sendable {
    public let id: FinancialAccountID
    public let title: String
    public let subtitle: String
    public let accountTypeLabel: String
    public let balanceText: String
    public let statusText: String
    public let tone: StatusBadge.Tone
    public let systemImage: String

    public init(
        id: FinancialAccountID,
        title: String,
        subtitle: String,
        accountTypeLabel: String,
        balanceText: String,
        statusText: String,
        tone: StatusBadge.Tone,
        systemImage: String
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.accountTypeLabel = accountTypeLabel
        self.balanceText = balanceText
        self.statusText = statusText
        self.tone = tone
        self.systemImage = systemImage
    }
}
