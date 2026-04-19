import Foundation
import SwiftData
import BudgetCore

@Model
public final class RecurringPatternModel {
    @Attribute(.unique) public var id: UUID
    public var canonicalMerchantName: String
    public var frequencyRaw: String
    public var meanAmount: Decimal
    public var stdDevAmount: Decimal
    public var currencyCodeRaw: String
    public var firstSeenAt: Date
    public var lastSeenAt: Date
    public var nextExpectedDate: Date?
    public var sampleCount: Int
    public var isActive: Bool
    public var isUserConfirmed: Bool

    public init(
        id: UUID = UUID(),
        canonicalMerchantName: String,
        frequency: RecurringFrequency,
        meanAmount: Decimal,
        stdDevAmount: Decimal,
        currencyCode: CurrencyCode,
        firstSeenAt: Date,
        lastSeenAt: Date,
        nextExpectedDate: Date?,
        sampleCount: Int,
        isActive: Bool = true,
        isUserConfirmed: Bool = false
    ) {
        self.id = id
        self.canonicalMerchantName = canonicalMerchantName
        self.frequencyRaw = frequency.rawValue
        self.meanAmount = meanAmount
        self.stdDevAmount = stdDevAmount
        self.currencyCodeRaw = currencyCode.rawValue
        self.firstSeenAt = firstSeenAt
        self.lastSeenAt = lastSeenAt
        self.nextExpectedDate = nextExpectedDate
        self.sampleCount = sampleCount
        self.isActive = isActive
        self.isUserConfirmed = isUserConfirmed
    }

    public var frequency: RecurringFrequency {
        get { RecurringFrequency(rawValue: frequencyRaw) ?? .irregular }
        set { frequencyRaw = newValue.rawValue }
    }

    public var currencyCode: CurrencyCode {
        get { CurrencyCode(rawValue: currencyCodeRaw) }
        set { currencyCodeRaw = newValue.rawValue }
    }

    public func snapshot() -> RecurringPatternSnapshot {
        RecurringPatternSnapshot(
            id: id,
            canonicalMerchantName: canonicalMerchantName,
            frequency: frequency,
            meanAmount: meanAmount,
            stdDevAmount: stdDevAmount,
            currencyCode: currencyCode,
            firstSeenAt: firstSeenAt,
            lastSeenAt: lastSeenAt,
            nextExpectedDate: nextExpectedDate,
            sampleCount: sampleCount,
            isActive: isActive,
            isUserConfirmed: isUserConfirmed
        )
    }
}
