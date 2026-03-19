import AppKit
import SwiftUI

public enum AppTheme {
    public static let spacingXXS: CGFloat = 4
    public static let spacingXS: CGFloat = 6
    public static let spacingS: CGFloat = 10
    public static let spacingM: CGFloat = 16
    public static let spacingL: CGFloat = 24
    public static let spacingXL: CGFloat = 32

    public static let cornerRadius: CGFloat = 12
    public static let largeCornerRadius: CGFloat = 16
    public static let panelPadding: CGFloat = 18
    public static let contentPadding: CGFloat = 24
    public static let narrowContentPadding: CGFloat = 18
    public static let sidebarIdealWidth: CGFloat = 230
    public static let inspectorIdealWidth: CGFloat = 300
    public static let chooserMaxWidth: CGFloat = 1040

    public static let surfaceColor = Color(nsColor: .controlBackgroundColor)
    public static let elevatedSurfaceColor = Color(nsColor: .textBackgroundColor)
    public static let secondarySurfaceColor = Color(nsColor: .underPageBackgroundColor)
    public static let strokeColor = Color(nsColor: .separatorColor).opacity(0.45)
    public static let subduedForegroundColor = Color.secondary
}
