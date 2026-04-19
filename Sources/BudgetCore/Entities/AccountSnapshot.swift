import Foundation

public struct AccountSnapshot: Identifiable, Hashable, Sendable, Codable {
    public let id: UUID
    public let plaidAccountId: String
    public let plaidItemId: String
    public let institutionId: String
    public let institutionName: String
    public let mask: String?
    public let displayName: String
    public let accountType: AccountType
    public let accountSubtype: String?
    public let currencyCode: CurrencyCode
    public let currentBalance: Decimal
    public let availableBalance: Decimal?
    public let creditLimit: Decimal?
    public let lastSyncedAt: Date
    public let isActive: Bool
    public let sortOrder: Int

    public init(
        id: UUID,
        plaidAccountId: String,
        plaidItemId: String,
        institutionId: String,
        institutionName: String,
        mask: String?,
        displayName: String,
        accountType: AccountType,
        accountSubtype: String?,
        currencyCode: CurrencyCode,
        currentBalance: Decimal,
        availableBalance: Decimal?,
        creditLimit: Decimal?,
        lastSyncedAt: Date,
        isActive: Bool,
        sortOrder: Int
    ) {
        self.id = id
        self.plaidAccountId = plaidAccountId
        self.plaidItemId = plaidItemId
        self.institutionId = institutionId
        self.institutionName = institutionName
        self.mask = mask
        self.displayName = displayName
        self.accountType = accountType
        self.accountSubtype = accountSubtype
        self.currencyCode = currencyCode
        self.currentBalance = currentBalance
        self.availableBalance = availableBalance
        self.creditLimit = creditLimit
        self.lastSyncedAt = lastSyncedAt
        self.isActive = isActive
        self.sortOrder = sortOrder
    }

    public var maskedDisplay: String {
        if let mask { return "\(displayName) ··\(mask)" }
        return displayName
    }
}
