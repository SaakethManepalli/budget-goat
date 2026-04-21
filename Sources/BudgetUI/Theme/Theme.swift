import SwiftUI
import BudgetCore

public enum Theme {

    public enum Palette {
        /// OLED-true black. Pixels are physically off on modern iPhones — this is
        /// what creates the "floating card" effect on top.
        public static let foundation      = Color.black

        /// Glass surfaces — cards never use a solid fill; they stack
        /// `.ultraThinMaterial` on top of foundation so blur + refraction
        /// does the visual work.
        public static let glassTint       = Color.white.opacity(0.04)
        public static let glassBorder     = Color.white.opacity(0.08)
        public static let glassHighlight  = Color.white.opacity(0.14)

        /// Signal colors — used sparingly on figures only, never on chrome.
        public static let credit  = Color(red: 0.23, green: 0.83, blue: 0.64)   // mint
        public static let debit   = Color(red: 0.96, green: 0.38, blue: 0.38)   // coral
        public static let accent  = Color(red: 0.79, green: 0.66, blue: 0.30)   // champagne
        public static let primaryText   = Color(red: 0.97, green: 0.96, blue: 0.94) // cream
        public static let secondaryText = Color.white.opacity(0.55)
        public static let tertiaryText  = Color.white.opacity(0.32)

        // Legacy aliases — existing views reference these; do not remove
        // until every view has migrated to the explicit semantic names above.
        public static let primary    = accent
        public static let background = foundation
        public static let secondary  = glassTint
        public static let tertiary   = glassHighlight
        public static let spend      = debit
        public static let income     = credit
        public static let neutral    = secondaryText
    }

    public enum Spacing {
        public static let hairline: CGFloat = 1
        public static let xs: CGFloat = 4
        public static let sm: CGFloat = 8
        public static let md: CGFloat = 16
        public static let lg: CGFloat = 24
        public static let xl: CGFloat = 32
        public static let xxl: CGFloat = 48
    }

    public enum Radius {
        public static let small: CGFloat = 10
        public static let medium: CGFloat = 16
        public static let large: CGFloat = 24
        public static let card: CGFloat = 28
    }

    /// Legacy alias — existing views use Theme.CornerRadius
    public typealias CornerRadius = Radius

    public enum Typography {
        // Chrome / UI copy — system display
        public static let display   = Font.system(size: 34, weight: .semibold, design: .default).leading(.tight)
        public static let heading   = Font.system(size: 22, weight: .medium,   design: .default).leading(.tight)
        public static let body      = Font.system(size: 15, weight: .regular,  design: .default)
        public static let caption   = Font.system(size: 12, weight: .medium,   design: .default).width(.condensed)
        public static let micro     = Font.system(size: 10, weight: .medium).smallCaps()

        // Legacy alias — existing views
        public static let mono      = Font.system(size: 14, weight: .regular, design: .monospaced)

        // Financial figures — monospaced digits, optical sizing
        public static let amountHero    = Font.system(size: 48, weight: .light,  design: .rounded).monospacedDigit()
        public static let amountLarge   = Font.system(size: 28, weight: .medium, design: .rounded).monospacedDigit()
        public static let amountMedium  = Font.system(size: 17, weight: .medium, design: .rounded).monospacedDigit()
        public static let amountSmall   = Font.system(size: 14, weight: .medium, design: .rounded).monospacedDigit()
    }
}

public extension TransactionCategory {
    /// Legacy alias — existing views use `.color` expecting chart tint.
    var color: Color { chartTint }

    var signalColor: Color {
        switch self {
        case .income:        Theme.Palette.credit
        case .transfer:      Theme.Palette.secondaryText
        default:             Theme.Palette.debit
        }
    }

    // Muted accent color per category for chart segmentation
    var chartTint: Color {
        switch self {
        case .groceries:      Color(red: 0.40, green: 0.70, blue: 0.55)
        case .dining:         Color(red: 0.88, green: 0.55, blue: 0.35)
        case .transportation: Color(red: 0.45, green: 0.60, blue: 0.80)
        case .utilities:      Color(red: 0.80, green: 0.70, blue: 0.35)
        case .entertainment:  Color(red: 0.68, green: 0.45, blue: 0.78)
        case .health:         Color(red: 0.85, green: 0.58, blue: 0.70)
        case .shopping:       Color(red: 0.55, green: 0.50, blue: 0.82)
        case .income:         Theme.Palette.credit
        case .transfer:       Theme.Palette.secondaryText
        case .travel:         Color(red: 0.40, green: 0.75, blue: 0.78)
        case .subscriptions:  Color(red: 0.45, green: 0.72, blue: 0.82)
        case .housing:        Color(red: 0.70, green: 0.55, blue: 0.40)
        case .education:      Color(red: 0.92, green: 0.45, blue: 0.45)
        case .insurance:      Color.white.opacity(0.5)
        case .investments:    Theme.Palette.accent
        case .other:          Theme.Palette.tertiaryText
        }
    }
}
