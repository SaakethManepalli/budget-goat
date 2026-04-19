import Foundation

public struct CurrencyCode: Hashable, Codable, Sendable, RawRepresentable, ExpressibleByStringLiteral {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue.uppercased()
    }

    public init(stringLiteral value: StringLiteralType) {
        self.rawValue = value.uppercased()
    }

    public static let usd: CurrencyCode = "USD"
    public static let eur: CurrencyCode = "EUR"
    public static let gbp: CurrencyCode = "GBP"
    public static let jpy: CurrencyCode = "JPY"
    public static let cad: CurrencyCode = "CAD"

    public var symbol: String {
        let locale = Locale(identifier: "en_US@currency=\(rawValue)")
        return locale.currencySymbol ?? rawValue
    }
}

public struct Money: Hashable, Codable, Sendable {
    public let amount: Decimal
    public let currency: CurrencyCode

    public init(amount: Decimal, currency: CurrencyCode) {
        self.amount = amount
        self.currency = currency
    }

    public func formatted(locale: Locale = .autoupdatingCurrent) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency.rawValue
        formatter.locale = locale
        return formatter.string(from: amount as NSDecimalNumber) ?? "\(currency.rawValue) \(amount)"
    }
}
