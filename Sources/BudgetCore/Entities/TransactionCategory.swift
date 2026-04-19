import Foundation

public enum TransactionCategory: String, Codable, CaseIterable, Sendable, Hashable {
    case groceries
    case dining
    case transportation
    case utilities
    case entertainment
    case health
    case shopping
    case income
    case transfer
    case travel
    case subscriptions
    case housing
    case education
    case insurance
    case investments
    case other

    public var displayName: String {
        switch self {
        case .groceries:      "Groceries"
        case .dining:         "Dining"
        case .transportation: "Transportation"
        case .utilities:      "Utilities"
        case .entertainment:  "Entertainment"
        case .health:         "Health"
        case .shopping:       "Shopping"
        case .income:         "Income"
        case .transfer:       "Transfer"
        case .travel:         "Travel"
        case .subscriptions:  "Subscriptions"
        case .housing:        "Housing"
        case .education:      "Education"
        case .insurance:      "Insurance"
        case .investments:    "Investments"
        case .other:          "Other"
        }
    }

    public var isExpense: Bool {
        self != .income && self != .transfer
    }

    public var systemIconName: String {
        switch self {
        case .groceries:      "cart.fill"
        case .dining:         "fork.knife"
        case .transportation: "car.fill"
        case .utilities:      "bolt.fill"
        case .entertainment:  "tv.fill"
        case .health:         "heart.fill"
        case .shopping:       "bag.fill"
        case .income:         "arrow.down.circle.fill"
        case .transfer:       "arrow.left.arrow.right"
        case .travel:         "airplane"
        case .subscriptions:  "repeat.circle.fill"
        case .housing:        "house.fill"
        case .education:      "graduationcap.fill"
        case .insurance:      "shield.fill"
        case .investments:    "chart.line.uptrend.xyaxis"
        case .other:          "questionmark.circle.fill"
        }
    }
}

public enum CategorySource: String, Codable, Sendable {
    case plaid
    case llm
    case manual
    case cache
}

public enum RecurringFrequency: String, Codable, CaseIterable, Sendable {
    case weekly
    case biweekly
    case monthly
    case quarterly
    case annual
    case irregular

    public var approximateDays: Double {
        switch self {
        case .weekly:    7
        case .biweekly:  14
        case .monthly:   30.44
        case .quarterly: 91.31
        case .annual:    365.25
        case .irregular: 0
        }
    }
}

public enum AccountType: String, Codable, CaseIterable, Sendable {
    case checking
    case savings
    case credit
    case investment
    case loan
}
