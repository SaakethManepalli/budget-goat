import Foundation

public struct ResetDataUseCase: Sendable {
    private let accountRepo: AccountRepository
    private let transactionRepo: TransactionRepository
    private let budgetRepo: BudgetRepository
    private let recurringRepo: RecurringRepository
    private let tokenStore: TokenStoreResetting
    private let cursorStore: CursorStore
    private let syncProvider: BankSyncProvider

    public init(
        accountRepo: AccountRepository,
        transactionRepo: TransactionRepository,
        budgetRepo: BudgetRepository,
        recurringRepo: RecurringRepository,
        tokenStore: TokenStoreResetting,
        cursorStore: CursorStore,
        syncProvider: BankSyncProvider
    ) {
        self.accountRepo = accountRepo
        self.transactionRepo = transactionRepo
        self.budgetRepo = budgetRepo
        self.recurringRepo = recurringRepo
        self.tokenStore = tokenStore
        self.cursorStore = cursorStore
        self.syncProvider = syncProvider
    }

    public struct Summary: Sendable {
        public let itemsRevoked: Int
        public let itemsFailedToRevoke: [String]
    }

    public func execute() async throws -> Summary {
        let accounts = (try? await accountRepo.fetchAll()) ?? []
        let itemIds = Set(accounts.map(\.plaidItemId))

        var failedRevocations: [String] = []
        for itemId in itemIds {
            do {
                try await syncProvider.removeItem(itemId: itemId)
            } catch {
                failedRevocations.append(itemId)
            }
            await cursorStore.clear(itemId: itemId)
        }

        let keychainKeys = (try? await tokenStore.allItemKeys()) ?? []
        for key in keychainKeys {
            try? await tokenStore.deleteItemId(forKey: key)
        }

        try await transactionRepo.deleteAll()
        try await accountRepo.deleteAll()
        try await budgetRepo.deleteAll()
        try await recurringRepo.deleteAll()

        return Summary(
            itemsRevoked: itemIds.count - failedRevocations.count,
            itemsFailedToRevoke: failedRevocations
        )
    }
}

public protocol TokenStoreResetting: Sendable {
    func allItemKeys() async throws -> [String]
    func deleteItemId(forKey: String) async throws
}
