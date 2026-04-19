import Foundation

public struct LinkAccountUseCase: Sendable {
    private let syncProvider: BankSyncProvider
    private let accountRepo: AccountRepository
    private let syncUseCase: SyncTransactionsUseCase

    public init(
        syncProvider: BankSyncProvider,
        accountRepo: AccountRepository,
        syncUseCase: SyncTransactionsUseCase
    ) {
        self.syncProvider = syncProvider
        self.accountRepo = accountRepo
        self.syncUseCase = syncUseCase
    }

    public func createLinkToken() async throws -> String {
        try await syncProvider.createLinkToken()
    }

    public func completeLink(publicToken: String, institutionId: String) async throws -> SyncSummary {
        let item = try await syncProvider.exchangePublicToken(publicToken, institutionId: institutionId)
        try await accountRepo.register(item: item)
        return try await syncUseCase.execute(itemId: item.itemId)
    }

    public func removeItem(itemId: String) async throws {
        try await syncProvider.removeItem(itemId: itemId)
        try await accountRepo.remove(itemId: itemId)
    }
}
