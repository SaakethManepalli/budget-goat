import Foundation
import SwiftData
import BudgetCore

@Model
public final class BudgetModel {
    @Attribute(.unique) public var id: UUID
    public var categoryRaw: String
    public var monthlyLimit: Decimal
    public var currencyCodeRaw: String
    public var monthStart: Date
    public var notifyAtPercent: Int
    public var rollover: Bool

    public init(
        id: UUID = UUID(),
        category: TransactionCategory,
        monthlyLimit: Decimal,
        currencyCode: CurrencyCode,
        monthStart: Date,
        notifyAtPercent: Int,
        rollover: Bool
    ) {
        self.id = id
        self.categoryRaw = category.rawValue
        self.monthlyLimit = monthlyLimit
        self.currencyCodeRaw = currencyCode.rawValue
        self.monthStart = monthStart
        self.notifyAtPercent = notifyAtPercent
        self.rollover = rollover
    }

    public var category: TransactionCategory {
        get { TransactionCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    public var currencyCode: CurrencyCode {
        get { CurrencyCode(rawValue: currencyCodeRaw) }
        set { currencyCodeRaw = newValue.rawValue }
    }
}
