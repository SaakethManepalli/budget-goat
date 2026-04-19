import Foundation
import SwiftData
import BudgetCore

@Model
public final class ExchangeRateModel {
    public var baseCurrencyCodeRaw: String
    public var targetCurrencyCodeRaw: String
    public var rate: Double
    public var fetchedAt: Date

    public init(
        baseCurrencyCode: CurrencyCode,
        targetCurrencyCode: CurrencyCode,
        rate: Double,
        fetchedAt: Date
    ) {
        self.baseCurrencyCodeRaw = baseCurrencyCode.rawValue
        self.targetCurrencyCodeRaw = targetCurrencyCode.rawValue
        self.rate = rate
        self.fetchedAt = fetchedAt
    }

    public var baseCurrencyCode: CurrencyCode {
        get { CurrencyCode(rawValue: baseCurrencyCodeRaw) }
        set { baseCurrencyCodeRaw = newValue.rawValue }
    }

    public var targetCurrencyCode: CurrencyCode {
        get { CurrencyCode(rawValue: targetCurrencyCodeRaw) }
        set { targetCurrencyCodeRaw = newValue.rawValue }
    }

    public var isStale: Bool {
        Date().timeIntervalSince(fetchedAt) > 86_400
    }
}
