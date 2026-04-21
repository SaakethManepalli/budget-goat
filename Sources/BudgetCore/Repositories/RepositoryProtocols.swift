import Foundation

public enum TransactionSortOrder: Sendable {
    case dateDescending
    case dateAscending
    case amountDescending
    case amountAscending
}

public struct TransactionQuery: Sendable {
    public var accountId: UUID?
    public var category: TransactionCategory?
    public var dateRange: ClosedRange<Date>?
    public var searchText: String?
    public var isRecurringOnly: Bool
    public var includeHidden: Bool
    public var sortOrder: TransactionSortOrder

    public init(
        accountId: UUID? = nil,
        category: TransactionCategory? = nil,
        dateRange: ClosedRange<Date>? = nil,
        searchText: String? = nil,
        isRecurringOnly: Bool = false,
        includeHidden: Bool = false,
        sortOrder: TransactionSortOrder = .dateDescending
    ) {
        self.accountId = accountId
        self.category = category
        self.dateRange = dateRange
        self.searchText = searchText
        self.isRecurringOnly = isRecurringOnly
        self.includeHidden = includeHidden
        self.sortOrder = sortOrder
    }
}

public protocol TransactionRepository: Sendable {
    func fetchPage(query: TransactionQuery, offset: Int, limit: Int) async throws -> [TransactionSnapshot]
    func fetch(id: UUID) async throws -> TransactionSnapshot?
    func fetchAllForExport() async throws -> [TransactionSnapshot]
    func apply(delta: SyncDelta, forItemId: String) async throws
    func updateUserCategory(id: UUID, category: TransactionCategory) async throws
    func updateNote(id: UUID, note: String?) async throws
    func setFlagged(id: UUID, flagged: Bool) async throws
    func setHidden(id: UUID, hidden: Bool) async throws
    func totalSpent(category: TransactionCategory, monthStart: Date, in: CurrencyCode) async throws -> Decimal
    func deleteAll() async throws
}

public protocol AccountRepository: Sendable {
    func fetchAll() async throws -> [AccountSnapshot]
    func fetch(id: UUID) async throws -> AccountSnapshot?
    func fetchByItemId(_ itemId: String) async throws -> [AccountSnapshot]
    func register(item: LinkedItem) async throws
    func updateBalance(id: UUID, current: Decimal, available: Decimal?) async throws
    func remove(itemId: String) async throws
    func updateDisplayName(id: UUID, displayName: String) async throws
    func deleteAll() async throws
}

public protocol BudgetRepository: Sendable {
    func fetchAll(forMonth: Date) async throws -> [BudgetSnapshot]
    func fetchAllForExport() async throws -> [BudgetSnapshot]
    func upsert(category: TransactionCategory, limit: Decimal, currency: CurrencyCode, monthStart: Date, notifyAtPercent: Int, rollover: Bool) async throws
    func delete(id: UUID) async throws
    func deleteAll() async throws
}

public protocol RecurringRepository: Sendable {
    func fetchAll() async throws -> [RecurringPatternSnapshot]
    func upsert(_ snapshot: RecurringPatternSnapshot) async throws
    func confirm(id: UUID) async throws
    func deactivate(id: UUID) async throws
    func deleteAll() async throws
}

public protocol CursorStore: Sendable {
    func cursor(forItemId: String) async -> String?
    func save(cursor: String, forItemId: String) async
    func clear(itemId: String) async
}

public protocol BankSyncProvider: Sendable {
    func createLinkToken() async throws -> String
    /// Update-mode link token: scoped to an existing item for re-authentication.
    /// Issued by the backend using the stored access_token for that item.
    func createUpdateLinkToken(forItemId: String) async throws -> String
    func exchangePublicToken(_ publicToken: String, institutionId: String) async throws -> LinkedItem
    func syncTransactions(itemId: String, cursor: String?, count: Int) async throws -> SyncDelta
    func removeItem(itemId: String) async throws
}

public protocol CategorizationEngine: Sendable {
    func categorize(_ transactions: [TransactionSnapshot]) async throws -> [CategorizationResult]
}

public struct CategorizationResult: Sendable, Hashable {
    public let transactionId: UUID
    public let category: TransactionCategory
    public let subcategory: String?
    public let canonicalName: String
    public let confidence: Float
    public let isRecurring: Bool
    public let source: CategorySource

    public init(
        transactionId: UUID,
        category: TransactionCategory,
        subcategory: String?,
        canonicalName: String,
        confidence: Float,
        isRecurring: Bool,
        source: CategorySource
    ) {
        self.transactionId = transactionId
        self.category = category
        self.subcategory = subcategory
        self.canonicalName = canonicalName
        self.confidence = confidence
        self.isRecurring = isRecurring
        self.source = source
    }
}
