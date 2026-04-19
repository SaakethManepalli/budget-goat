import Foundation

public struct LinkedItem: Hashable, Sendable {
    public let itemId: String
    public let institutionId: String
    public let institutionName: String
    public let accounts: [LinkedAccount]

    public init(itemId: String, institutionId: String, institutionName: String, accounts: [LinkedAccount]) {
        self.itemId = itemId
        self.institutionId = institutionId
        self.institutionName = institutionName
        self.accounts = accounts
    }
}

public struct LinkedAccount: Hashable, Sendable {
    public let plaidAccountId: String
    public let name: String
    public let mask: String?
    public let type: AccountType
    public let subtype: String?
    public let currencyCode: CurrencyCode

    public init(
        plaidAccountId: String,
        name: String,
        mask: String?,
        type: AccountType,
        subtype: String?,
        currencyCode: CurrencyCode
    ) {
        self.plaidAccountId = plaidAccountId
        self.name = name
        self.mask = mask
        self.type = type
        self.subtype = subtype
        self.currencyCode = currencyCode
    }
}

public struct SyncDelta: Sendable {
    public let added: [IngestedTransaction]
    public let modified: [IngestedTransaction]
    public let removed: [String]
    public let nextCursor: String
    public let hasMore: Bool

    public init(
        added: [IngestedTransaction],
        modified: [IngestedTransaction],
        removed: [String],
        nextCursor: String,
        hasMore: Bool
    ) {
        self.added = added
        self.modified = modified
        self.removed = removed
        self.nextCursor = nextCursor
        self.hasMore = hasMore
    }
}

public struct IngestedTransaction: Sendable, Hashable {
    public let plaidTransactionId: String
    public let plaidAccountId: String
    public let amount: Decimal
    public let currencyCode: CurrencyCode
    public let authorizedDate: Date
    public let postedDate: Date?
    public let rawName: String
    public let merchantName: String?
    public let category: TransactionCategory?
    public let subcategory: String?
    public let categoryConfidence: Float?
    public let isPending: Bool
    public let logoURL: URL?
    public let merchantLatitude: Double?
    public let merchantLongitude: Double?

    public init(
        plaidTransactionId: String,
        plaidAccountId: String,
        amount: Decimal,
        currencyCode: CurrencyCode,
        authorizedDate: Date,
        postedDate: Date?,
        rawName: String,
        merchantName: String?,
        category: TransactionCategory?,
        subcategory: String?,
        categoryConfidence: Float?,
        isPending: Bool,
        logoURL: URL?,
        merchantLatitude: Double?,
        merchantLongitude: Double?
    ) {
        self.plaidTransactionId = plaidTransactionId
        self.plaidAccountId = plaidAccountId
        self.amount = amount
        self.currencyCode = currencyCode
        self.authorizedDate = authorizedDate
        self.postedDate = postedDate
        self.rawName = rawName
        self.merchantName = merchantName
        self.category = category
        self.subcategory = subcategory
        self.categoryConfidence = categoryConfidence
        self.isPending = isPending
        self.logoURL = logoURL
        self.merchantLatitude = merchantLatitude
        self.merchantLongitude = merchantLongitude
    }
}

public struct SyncSummary: Sendable, Hashable {
    public let added: Int
    public let modified: Int
    public let removed: Int
    public let durationSeconds: TimeInterval

    public init(added: Int, modified: Int, removed: Int, durationSeconds: TimeInterval) {
        self.added = added
        self.modified = modified
        self.removed = removed
        self.durationSeconds = durationSeconds
    }

    public var totalTouched: Int { added + modified + removed }
}
