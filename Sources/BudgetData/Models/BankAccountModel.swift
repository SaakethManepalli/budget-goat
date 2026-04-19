import Foundation
import SwiftData
import BudgetCore

@Model
public final class BankAccountModel {
    @Attribute(.unique) public var id: UUID
    @Attribute(.unique) public var plaidAccountId: String
    public var plaidItemId: String
    public var institutionId: String
    public var institutionName: String
    public var mask: String?
    public var displayName: String
    public var accountTypeRaw: String
    public var accountSubtype: String?
    public var currencyCodeRaw: String
    public var currentBalance: Decimal
    public var availableBalance: Decimal?
    public var creditLimit: Decimal?
    public var lastSyncedAt: Date
    public var isActive: Bool
    public var sortOrder: Int

    @Relationship(deleteRule: .cascade, inverse: \TransactionModel.account)
    public var transactions: [TransactionModel] = []

    public init(
        id: UUID = UUID(),
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
        self.accountTypeRaw = accountType.rawValue
        self.accountSubtype = accountSubtype
        self.currencyCodeRaw = currencyCode.rawValue
        self.currentBalance = currentBalance
        self.availableBalance = availableBalance
        self.creditLimit = creditLimit
        self.lastSyncedAt = lastSyncedAt
        self.isActive = isActive
        self.sortOrder = sortOrder
    }

    public var accountType: AccountType {
        get { AccountType(rawValue: accountTypeRaw) ?? .checking }
        set { accountTypeRaw = newValue.rawValue }
    }

    public var currencyCode: CurrencyCode {
        get { CurrencyCode(rawValue: currencyCodeRaw) }
        set { currencyCodeRaw = newValue.rawValue }
    }

    public func snapshot() -> AccountSnapshot {
        AccountSnapshot(
            id: id,
            plaidAccountId: plaidAccountId,
            plaidItemId: plaidItemId,
            institutionId: institutionId,
            institutionName: institutionName,
            mask: mask,
            displayName: displayName,
            accountType: accountType,
            accountSubtype: accountSubtype,
            currencyCode: currencyCode,
            currentBalance: currentBalance,
            availableBalance: availableBalance,
            creditLimit: creditLimit,
            lastSyncedAt: lastSyncedAt,
            isActive: isActive,
            sortOrder: sortOrder
        )
    }
}
