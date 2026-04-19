import Foundation

public struct TransactionSnapshot: Identifiable, Hashable, Sendable, Codable {
    public let id: UUID
    public let plaidTransactionId: String
    public let accountId: UUID
    public let accountDisplayName: String
    public let amount: Decimal
    public let currencyCode: CurrencyCode
    public let amountInBaseCurrency: Decimal?
    public let authorizedDate: Date
    public let postedDate: Date?
    public let rawName: String
    public let merchantName: String?
    public let canonicalName: String?
    public let logoURL: URL?
    public let category: TransactionCategory?
    public let subcategory: String?
    public let categorySource: CategorySource
    public let categoryConfidence: Float?
    public let isPending: Bool
    public let isRecurring: Bool
    public let recurringPatternId: UUID?
    public let userNote: String?
    public let isFlagged: Bool
    public let isHidden: Bool

    public init(
        id: UUID,
        plaidTransactionId: String,
        accountId: UUID,
        accountDisplayName: String,
        amount: Decimal,
        currencyCode: CurrencyCode,
        amountInBaseCurrency: Decimal?,
        authorizedDate: Date,
        postedDate: Date?,
        rawName: String,
        merchantName: String?,
        canonicalName: String?,
        logoURL: URL?,
        category: TransactionCategory?,
        subcategory: String?,
        categorySource: CategorySource,
        categoryConfidence: Float?,
        isPending: Bool,
        isRecurring: Bool,
        recurringPatternId: UUID?,
        userNote: String?,
        isFlagged: Bool,
        isHidden: Bool
    ) {
        self.id = id
        self.plaidTransactionId = plaidTransactionId
        self.accountId = accountId
        self.accountDisplayName = accountDisplayName
        self.amount = amount
        self.currencyCode = currencyCode
        self.amountInBaseCurrency = amountInBaseCurrency
        self.authorizedDate = authorizedDate
        self.postedDate = postedDate
        self.rawName = rawName
        self.merchantName = merchantName
        self.canonicalName = canonicalName
        self.logoURL = logoURL
        self.category = category
        self.subcategory = subcategory
        self.categorySource = categorySource
        self.categoryConfidence = categoryConfidence
        self.isPending = isPending
        self.isRecurring = isRecurring
        self.recurringPatternId = recurringPatternId
        self.userNote = userNote
        self.isFlagged = isFlagged
        self.isHidden = isHidden
    }

    public var displayName: String {
        canonicalName ?? merchantName ?? rawName
    }

    public var signedAmount: Decimal { -amount }

    public var isCredit: Bool { amount < 0 }
}
