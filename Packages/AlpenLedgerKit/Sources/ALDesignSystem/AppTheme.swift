import AppKit
import SwiftUI

public enum AppTheme {
    public static let spacingXXS: CGFloat = 4
    public static let spacingXS: CGFloat = 6
    public static let spacingS: CGFloat = 10
    public static let spacingM: CGFloat = 16
    public static let spacingL: CGFloat = 24
    public static let spacingXL: CGFloat = 32
    public static let spacingXXL: CGFloat = 40

    public static let cornerRadius: CGFloat = 8
    public static let largeCornerRadius: CGFloat = 10
    public static let panelPadding: CGFloat = 18
    public static let groupedPanelPadding: CGFloat = 16
    public static let compactPanelPadding: CGFloat = 14
    public static let contentPadding: CGFloat = 20
    public static let narrowContentPadding: CGFloat = 16
    public static let sidebarSectionSpacing: CGFloat = 8
    public static let sidebarRowVerticalPadding: CGFloat = 7
    public static let sidebarRowIconWidth: CGFloat = 18
    public static let tableRowVerticalPadding: CGFloat = 6
    public static let tableCellHorizontalPadding: CGFloat = 8
    public static let inspectorSectionSpacing: CGFloat = 14
    public static let inspectorRowSpacing: CGFloat = 10
    public static let emptyStateSpacing: CGFloat = 12
    public static let emptyStateActionSpacing: CGFloat = 8
    public static let sidebarIdealWidth: CGFloat = 230
    public static let inspectorIdealWidth: CGFloat = 280
    public static let chooserMaxWidth: CGFloat = 1040
    public static let emptyStateMaxWidth: CGFloat = 320

    public static let ledgerDateColumnWidth: CGFloat = 96
    public static let ledgerCounterpartyMinWidth: CGFloat = 240
    public static let ledgerCounterpartyIdealWidth: CGFloat = 320
    public static let ledgerAmountColumnWidth: CGFloat = 124
    public static let ledgerReviewColumnWidth: CGFloat = 108
    public static let documentsFilenameMinWidth: CGFloat = 280
    public static let documentsFilenameIdealWidth: CGFloat = 380
    public static let documentsTypeColumnWidth: CGFloat = 150
    public static let documentsIssueDateColumnWidth: CGFloat = 110
    public static let documentsStatusColumnWidth: CGFloat = 104

    public static let windowChromeColor = Color(nsColor: .windowBackgroundColor)
    public static let surfaceColor = Color(nsColor: .controlBackgroundColor)
    public static let elevatedSurfaceColor = Color(nsColor: .textBackgroundColor)
    public static let secondarySurfaceColor = Color(nsColor: .underPageBackgroundColor)
    public static let tertiarySurfaceColor = Color(nsColor: .quaternaryLabelColor).opacity(0.08)
    public static let subtleSurfaceColor = Color(nsColor: .controlBackgroundColor).opacity(0.55)
    public static let emphasizedSurfaceColor = Color(nsColor: .textBackgroundColor)
    public static let accentSurfaceColor = Color.accentColor.opacity(0.08)
    public static let strokeColor = Color(nsColor: .separatorColor).opacity(0.45)
    public static let strongStrokeColor = Color(nsColor: .separatorColor).opacity(0.65)
    public static let subduedForegroundColor = Color.secondary
    public static let symbolRenderingMode: SymbolRenderingMode = .hierarchical

    public static let pageTitleFont: Font = .title2
    public static let pageSubtitleFont: Font = .body
    public static let sectionTitleFont: Font = .headline
    public static let sectionSubtitleFont: Font = .subheadline
    public static let metaFont: Font = .subheadline
    public static let prominentMetricValueFont: Font = .title2
    public static let compactMetricValueFont: Font = .headline
    public static let windowTitleFont: Font = .headline
    public static let windowSubtitleFont: Font = .subheadline
    public static let paneTitleFont: Font = sectionTitleFont
    public static let paneSubtitleFont: Font = sectionSubtitleFont
    public static let sidebarTitleFont: Font = .body
    public static let sidebarSubtitleFont: Font = .subheadline
    public static let sidebarSectionHeaderFont: Font = .caption
    public static let inspectorLabelFont: Font = .subheadline
    public static let inspectorValueFont: Font = .body
    public static let summaryTitleFont: Font = metaFont
    public static let summaryValueFont: Font = prominentMetricValueFont
    public static let emptyStateTitleFont: Font = .headline
    public static let emptyStateSubtitleFont: Font = .subheadline

    public static let chromeAnimation = Animation.smooth(duration: 0.18)
    public static let countAnimation = Animation.snappy(duration: 0.18, extraBounce: 0)

    public static func panelAnimation(reduceMotion: Bool) -> Animation {
        reduceMotion ? .easeOut(duration: 0.12) : .snappy(duration: 0.2, extraBounce: 0)
    }

    public static func chromeTransition(reduceMotion: Bool) -> AnyTransition {
        reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top))
    }

    public static func inspectorTransition(reduceMotion: Bool) -> AnyTransition {
        reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .trailing))
    }
}
