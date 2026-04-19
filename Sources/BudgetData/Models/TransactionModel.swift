import Foundation
import SwiftData
import BudgetCore

@Model
public final class TransactionModel {
    @Attribute(.unique) public var id: UUID
    @Attribute(.unique) public var plaidTransactionId: String

    public var amount: Decimal
    public var currencyCodeRaw: String
    public var amountInBaseCurrency: Decimal?

    public var authorizedDate: Date
    public var postedDate: Date?

    public var rawName: String
    public var merchantName: String?
    public var canonicalName: String?
    public var logoURLString: String?

    public var categoryRaw: String?
    public var subcategory: String?
    public var categorySourceRaw: String
    public var categoryConfidence: Float?

    public var isPending: Bool
    public var isRecurring: Bool
    public var recurringPatternId: UUID?

    public var merchantLatitude: Double?
    public var merchantLongitude: Double?

    public var userNote: String?
    public var isFlagged: Bool
    public var isHidden: Bool
    public var userCategoryOverrideRaw: String?

    public var account: BankAccountModel?

    public init(
        id: UUID = UUID(),
        plaidTransactionId: String,
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
        merchantLatitude: Double?,
        merchantLongitude: Double?,
        account: BankAccountModel?
    ) {
        self.id = id
        self.plaidTransactionId = plaidTransactionId
        self.amount = amount
        self.currencyCodeRaw = currencyCode.rawValue
        self.amountInBaseCurrency = amountInBaseCurrency
        self.authorizedDate = authorizedDate
        self.postedDate = postedDate
        self.rawName = rawName
        self.merchantName = merchantName
        self.canonicalName = canonicalName
        self.logoURLString = logoURL?.absoluteString
        self.categoryRaw = category?.rawValue
        self.subcategory = subcategory
        self.categorySourceRaw = categorySource.rawValue
        self.categoryConfidence = categoryConfidence
        self.isPending = isPending
        self.isRecurring = isRecurring
        self.recurringPatternId = recurringPatternId
        self.merchantLatitude = merchantLatitude
        self.merchantLongitude = merchantLongitude
        self.userNote = nil
        self.isFlagged = false
        self.isHidden = false
        self.userCategoryOverrideRaw = nil
        self.account = account
    }

    public var currencyCode: CurrencyCode {
        get { CurrencyCode(rawValue: currencyCodeRaw) }
        set { currencyCodeRaw = newValue.rawValue }
    }

    public var category: TransactionCategory? {
        get {
            if let override = userCategoryOverrideRaw,
               let cat = TransactionCategory(rawValue: override) { return cat }
            return categoryRaw.flatMap(TransactionCategory.init(rawValue:))
        }
    }

    public var categorySource: CategorySource {
        get { CategorySource(rawValue: categorySourceRaw) ?? .plaid }
        set { categorySourceRaw = newValue.rawValue }
    }

    public var logoURL: URL? {
        logoURLString.flatMap(URL.init(string:))
    }

    public func snapshot() -> TransactionSnapshot {
        TransactionSnapshot(
            id: id,
            plaidTransactionId: plaidTransactionId,
            accountId: account?.id ?? UUID(),
            accountDisplayName: account?.displayName ?? "Unknown",
            amount: amount,
            currencyCode: currencyCode,
            amountInBaseCurrency: amountInBaseCurrency,
            authorizedDate: authorizedDate,
            postedDate: postedDate,
            rawName: rawName,
            merchantName: merchantName,
            canonicalName: canonicalName,
            logoURL: logoURL,
            category: category,
            subcategory: subcategory,
            categorySource: categorySource,
            categoryConfidence: categoryConfidence,
            isPending: isPending,
            isRecurring: isRecurring,
            recurringPatternId: recurringPatternId,
            userNote: userNote,
            isFlagged: isFlagged,
            isHidden: isHidden
        )
    }

    public func apply(ingested dto: IngestedTransaction, baseConverter: (Decimal, CurrencyCode) -> Decimal?) {
        amount = dto.amount
        currencyCode = dto.currencyCode
        amountInBaseCurrency = baseConverter(dto.amount, dto.currencyCode)
        authorizedDate = dto.authorizedDate
        postedDate = dto.postedDate
        rawName = dto.rawName
        merchantName = dto.merchantName
        logoURLString = dto.logoURL?.absoluteString
        if userCategoryOverrideRaw == nil {
            categoryRaw = dto.category?.rawValue
            subcategory = dto.subcategory
            categoryConfidence = dto.categoryConfidence
            categorySourceRaw = CategorySource.plaid.rawValue
        }
        isPending = dto.isPending
        merchantLatitude = dto.merchantLatitude
        merchantLongitude = dto.merchantLongitude
    }
}
