import Foundation

public struct CategorizeTransactionsUseCase: Sendable {
    private let engine: CategorizationEngine
    private let transactionRepo: TransactionRepository

    public init(engine: CategorizationEngine, transactionRepo: TransactionRepository) {
        self.engine = engine
        self.transactionRepo = transactionRepo
    }

    public func execute(transactions: [TransactionSnapshot]) async throws -> [CategorizationResult] {
        let results = try await engine.categorize(transactions)
        for result in results where result.source == .manual {
            try await transactionRepo.updateUserCategory(
                id: result.transactionId, category: result.category
            )
        }
        return results
    }
}
