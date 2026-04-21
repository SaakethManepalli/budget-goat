import SwiftUI
import BudgetCore

/// Premium monospaced amount display.
/// - Dollar and integer portion carry the weight.
/// - Cents render at 60% size + tertiary opacity (the "kerned cents" trick).
/// - Sign and currency glyph are rendered separately so they don't get
///   clipped by `contentTransition(.numericText)` when values animate.
public struct MonoAmount: View {
    public enum Size { case hero, large, medium, small }

    private let amount: Decimal
    private let currency: CurrencyCode
    private let size: Size
    private let signedStyle: Bool

    public init(
        _ amount: Decimal,
        currency: CurrencyCode = .usd,
        size: Size = .large,
        signed: Bool = false
    ) {
        self.amount = amount
        self.currency = currency
        self.size = size
        self.signedStyle = signed
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 0) {
            if signedStyle {
                Text(amount < 0 ? "+" : "−")
                    .font(integerFont)
                    .foregroundStyle(amount < 0 ? Theme.Palette.credit : Theme.Palette.primaryText)
                    .padding(.trailing, 2)
            }

            Text(symbol)
                .font(symbolFont)
                .foregroundStyle(Theme.Palette.secondaryText)
                .baselineOffset(baselineOffset)

            Text(integerPart)
                .font(integerFont)
                .foregroundStyle(Theme.Palette.primaryText)
                .contentTransition(.numericText(value: integerDouble))

            Text(".\(centsPart)")
                .font(centsFont)
                .foregroundStyle(Theme.Palette.tertiaryText)
                .baselineOffset(baselineOffset)
        }
        .animation(.snappy(duration: 0.35), value: amount)
    }

    // MARK: - Formatting

    private var absAmount: Decimal { abs(amount) }

    private var integerDouble: Double {
        (absAmount as NSDecimalNumber).doubleValue
    }

    private var integerPart: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        formatter.maximumFractionDigits = 0
        formatter.roundingMode = .down
        var truncated = Decimal()
        var mutable = absAmount
        NSDecimalRound(&truncated, &mutable, 0, .down)
        return formatter.string(from: truncated as NSDecimalNumber) ?? "0"
    }

    private var centsPart: String {
        var cents = absAmount * 100
        var truncated = Decimal()
        NSDecimalRound(&truncated, &cents, 0, .bankers)
        let intCents = (truncated as NSDecimalNumber).intValue % 100
        return String(format: "%02d", abs(intCents))
    }

    private var symbol: String { currency.symbol }

    // MARK: - Size ladder

    private var integerFont: Font {
        switch size {
        case .hero:   Theme.Typography.amountHero
        case .large:  Theme.Typography.amountLarge
        case .medium: Theme.Typography.amountMedium
        case .small:  Theme.Typography.amountSmall
        }
    }
    private var symbolFont: Font {
        switch size {
        case .hero:   .system(size: 24, weight: .light,  design: .rounded)
        case .large:  .system(size: 15, weight: .medium, design: .rounded)
        case .medium: .system(size: 11, weight: .medium, design: .rounded)
        case .small:  .system(size: 10, weight: .medium, design: .rounded)
        }
    }
    private var centsFont: Font {
        switch size {
        case .hero:   .system(size: 22, weight: .light,  design: .rounded).monospacedDigit()
        case .large:  .system(size: 15, weight: .medium, design: .rounded).monospacedDigit()
        case .medium: .system(size: 11, weight: .medium, design: .rounded).monospacedDigit()
        case .small:  .system(size: 10, weight: .medium, design: .rounded).monospacedDigit()
        }
    }
    private var baselineOffset: CGFloat {
        switch size {
        case .hero:   10
        case .large:   6
        case .medium:  3
        case .small:   2
        }
    }
}
