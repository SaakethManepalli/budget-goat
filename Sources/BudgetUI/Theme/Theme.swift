import SwiftUI
import BudgetCore

public enum Theme {
    public enum Palette {
        public static let primary = Color.accentColor
        #if os(iOS)
        public static let background = Color(.systemBackground)
        public static let secondary = Color(.secondarySystemBackground)
        public static let tertiary = Color(.tertiarySystemBackground)
        #else
        public static let background = Color.primary.opacity(0.02)
        public static let secondary = Color.primary.opacity(0.06)
        public static let tertiary = Color.primary.opacity(0.10)
        #endif
        public static let spend = Color.red
        public static let income = Color.green
        public static let neutral = Color.gray
    }

    public enum Spacing {
        public static let xs: CGFloat = 4
        public static let sm: CGFloat = 8
        public static let md: CGFloat = 16
        public static let lg: CGFloat = 24
        public static let xl: CGFloat = 32
    }

    public enum CornerRadius {
        public static let small: CGFloat = 8
        public static let medium: CGFloat = 12
        public static let large: CGFloat = 20
    }

    public enum Typography {
        public static let display = Font.system(size: 34, weight: .bold, design: .rounded)
        public static let heading = Font.system(size: 22, weight: .semibold, design: .rounded)
        public static let body = Font.system(size: 16, weight: .regular, design: .default)
        public static let caption = Font.system(size: 12, weight: .medium, design: .default)
        public static let mono = Font.system(size: 14, weight: .regular, design: .monospaced)
    }
}

public extension TransactionCategory {
    var color: Color {
        switch self {
        case .groceries:      .green
        case .dining:         .orange
        case .transportation: .blue
        case .utilities:      .yellow
        case .entertainment:  .purple
        case .health:         .pink
        case .shopping:       .indigo
        case .income:         .mint
        case .transfer:       .gray
        case .travel:         .teal
        case .subscriptions:  .cyan
        case .housing:        .brown
        case .education:      .red
        case .insurance:      .secondary
        case .investments:    .primary
        case .other:          .secondary
        }
    }
}
