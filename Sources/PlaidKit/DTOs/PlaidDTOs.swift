import Foundation
import BudgetCore

struct LinkTokenResponse: Decodable, Sendable {
    let linkToken: String
    let expiration: Date?
}

struct ExchangeRequest: Encodable, Sendable {
    let publicToken: String
    let institutionId: String
}

struct ExchangeResponse: Decodable, Sendable {
    let itemId: String
    let institutionId: String
    let institutionName: String
    let accounts: [PlaidAccountDTO]
}

struct PlaidAccountDTO: Decodable, Sendable {
    let accountId: String
    let name: String
    let mask: String?
    let type: String
    let subtype: String?
    let isoCurrencyCode: String?

    func toDomain() -> LinkedAccount {
        LinkedAccount(
            plaidAccountId: accountId,
            name: name,
            mask: mask,
            type: AccountType(rawValue: type) ?? .checking,
            subtype: subtype,
            currencyCode: CurrencyCode(rawValue: isoCurrencyCode ?? "USD")
        )
    }
}

struct SyncRequest: Encodable, Sendable {
    let itemId: String
    let cursor: String?
    let count: Int
}

struct SyncResponse: Decodable, Sendable {
    let added: [PlaidTransactionDTO]
    let modified: [PlaidTransactionDTO]
    let removed: [PlaidRemovedDTO]
    let nextCursor: String
    let hasMore: Bool

    func toDomain() -> SyncDelta {
        SyncDelta(
            added: added.map { $0.toDomain() },
            modified: modified.map { $0.toDomain() },
            removed: removed.map(\.transactionId),
            nextCursor: nextCursor,
            hasMore: hasMore
        )
    }
}

struct PlaidRemovedDTO: Decodable, Sendable {
    let transactionId: String
}

struct PlaidTransactionDTO: Decodable, Sendable {
    let transactionId: String
    let accountId: String
    let amount: Double
    let isoCurrencyCode: String?
    let authorizedDate: String?
    let date: String
    let name: String
    let merchantName: String?
    let pending: Bool
    let personalFinanceCategory: PlaidCategoryDTO?
    let logoUrl: String?
    let location: PlaidLocationDTO?

    func toDomain() -> IngestedTransaction {
        let formatter = ISO8601DateFormatter.plaidDate
        let authorized = formatter.date(from: authorizedDate ?? date) ?? Date()
        let posted = formatter.date(from: date)
        return IngestedTransaction(
            plaidTransactionId: transactionId,
            plaidAccountId: accountId,
            amount: Decimal(amount),
            currencyCode: CurrencyCode(rawValue: isoCurrencyCode ?? "USD"),
            authorizedDate: authorized,
            postedDate: posted,
            rawName: name,
            merchantName: merchantName,
            category: personalFinanceCategory?.toDomain(),
            subcategory: personalFinanceCategory?.detailed,
            categoryConfidence: personalFinanceCategory?.confidenceLevel.flatMap(confidenceScore),
            isPending: pending,
            logoURL: logoUrl.flatMap(URL.init(string:)),
            merchantLatitude: location?.lat,
            merchantLongitude: location?.lon
        )
    }
}

struct PlaidLocationDTO: Decodable, Sendable {
    let lat: Double?
    let lon: Double?
}

struct PlaidCategoryDTO: Decodable, Sendable {
    let primary: String?
    let detailed: String?
    let confidenceLevel: String?

    func toDomain() -> TransactionCategory? {
        guard let primary else { return nil }
        return mapPlaidPFC(primary)
    }
}

private func confidenceScore(_ level: String) -> Float? {
    switch level.uppercased() {
    case "VERY_HIGH": 0.98
    case "HIGH":      0.90
    case "MEDIUM":    0.70
    case "LOW":       0.45
    case "UNKNOWN":   0.30
    default:          nil
    }
}

private func mapPlaidPFC(_ primary: String) -> TransactionCategory {
    switch primary.uppercased() {
    case "INCOME":                            .income
    case "TRANSFER_IN", "TRANSFER_OUT":       .transfer
    case "LOAN_PAYMENTS":                    .transfer
    case "BANK_FEES":                         .other
    case "ENTERTAINMENT":                     .entertainment
    case "FOOD_AND_DRINK":                    .dining
    case "GENERAL_MERCHANDISE":               .shopping
    case "HOME_IMPROVEMENT", "RENT_AND_UTILITIES": .housing
    case "MEDICAL":                           .health
    case "PERSONAL_CARE":                     .health
    case "GENERAL_SERVICES":                  .other
    case "GOVERNMENT_AND_NON_PROFIT":         .other
    case "TRANSPORTATION":                    .transportation
    case "TRAVEL":                            .travel
    default:                                   .other
    }
}

extension ISO8601DateFormatter {
    static let plaidDate: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate, .withDashSeparatorInDate]
        return f
    }()
}
