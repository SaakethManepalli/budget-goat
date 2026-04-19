import Foundation

public struct BudgetSnapshot: Identifiable, Hashable, Sendable, Codable {
    public let id: UUID
    public let category: TransactionCategory
    public let monthlyLimit: Decimal
    public let currencyCode: CurrencyCode
    public let monthStart: Date
    public let notifyAtPercent: Int
    public let rollover: Bool
    public let spent: Decimal

    public init(
        id: UUID,
        category: TransactionCategory,
        monthlyLimit: Decimal,
        currencyCode: CurrencyCode,
        monthStart: Date,
        notifyAtPercent: Int,
        rollover: Bool,
        spent: Decimal
    ) {
        self.id = id
        self.category = category
        self.monthlyLimit = monthlyLimit
        self.currencyCode = currencyCode
        self.monthStart = monthStart
        self.notifyAtPercent = notifyAtPercent
        self.rollover = rollover
        self.spent = spent
    }

    public var remaining: Decimal { monthlyLimit - spent }

    public var progress: Double {
        guard monthlyLimit > 0 else { return 0 }
        let ratio = (spent as NSDecimalNumber).doubleValue / (monthlyLimit as NSDecimalNumber).doubleValue
        return min(max(ratio, 0), 1.25)
    }

    public var isOverBudget: Bool { spent > monthlyLimit }

    public var shouldNotify: Bool {
        notifyAtPercent > 0 && progress * 100 >= Double(notifyAtPercent)
    }
}

public struct RecurringPatternSnapshot: Identifiable, Hashable, Sendable, Codable {
    public let id: UUID
    public let canonicalMerchantName: String
    public let frequency: RecurringFrequency
    public let meanAmount: Decimal
    public let stdDevAmount: Decimal
    public let currencyCode: CurrencyCode
    public let firstSeenAt: Date
    public let lastSeenAt: Date
    public let nextExpectedDate: Date?
    public let sampleCount: Int
    public let isActive: Bool
    public let isUserConfirmed: Bool

    public init(
        id: UUID,
        canonicalMerchantName: String,
        frequency: RecurringFrequency,
        meanAmount: Decimal,
        stdDevAmount: Decimal,
        currencyCode: CurrencyCode,
        firstSeenAt: Date,
        lastSeenAt: Date,
        nextExpectedDate: Date?,
        sampleCount: Int,
        isActive: Bool,
        isUserConfirmed: Bool
    ) {
        self.id = id
        self.canonicalMerchantName = canonicalMerchantName
        self.frequency = frequency
        self.meanAmount = meanAmount
        self.stdDevAmount = stdDevAmount
        self.currencyCode = currencyCode
        self.firstSeenAt = firstSeenAt
        self.lastSeenAt = lastSeenAt
        self.nextExpectedDate = nextExpectedDate
        self.sampleCount = sampleCount
        self.isActive = isActive
        self.isUserConfirmed = isUserConfirmed
    }
}
