import Foundation

public struct SyncTransactionsUseCase: Sendable {
    private let syncProvider: BankSyncProvider
    private let transactionRepo: TransactionRepository
    private let accountRepo: AccountRepository
    private let cursorStore: CursorStore

    public init(
        syncProvider: BankSyncProvider,
        transactionRepo: TransactionRepository,
        accountRepo: AccountRepository,
        cursorStore: CursorStore
    ) {
        self.syncProvider = syncProvider
        self.transactionRepo = transactionRepo
        self.accountRepo = accountRepo
        self.cursorStore = cursorStore
    }

    public func execute(itemId: String) async throws -> SyncSummary {
        let started = Date()
        var added = 0, modified = 0, removed = 0
        var cursor = await cursorStore.cursor(forItemId: itemId)
        var loopGuard = 0

        while true {
            loopGuard += 1
            if loopGuard > 50 { break }

            let delta = try await syncProvider.syncTransactions(
                itemId: itemId, cursor: cursor, count: 500
            )
            try await transactionRepo.apply(delta: delta, forItemId: itemId)
            await cursorStore.save(cursor: delta.nextCursor, forItemId: itemId)

            added    += delta.added.count
            modified += delta.modified.count
            removed  += delta.removed.count
            cursor = delta.nextCursor

            if !delta.hasMore { break }
        }

        return SyncSummary(
            added: added, modified: modified, removed: removed,
            durationSeconds: Date().timeIntervalSince(started)
        )
    }

    public func executeAll() async throws -> [String: SyncSummary] {
        let accounts = try await accountRepo.fetchAll()
        let itemIds = Set(accounts.map(\.plaidItemId))
        var results: [String: SyncSummary] = [:]

        try await withThrowingTaskGroup(of: (String, SyncSummary).self) { group in
            for id in itemIds {
                group.addTask {
                    let summary = try await execute(itemId: id)
                    return (id, summary)
                }
            }
            for try await (id, summary) in group {
                results[id] = summary
            }
        }
        return results
    }
}
