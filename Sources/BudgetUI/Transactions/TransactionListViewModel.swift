import Foundation
import BudgetCore

@MainActor
public final class TransactionListViewModel: ObservableObject {
    @Published public var transactions: [TransactionSnapshot] = []
    @Published public var query = TransactionQuery()
    @Published public var searchText: String = ""
    @Published public var isLoadingNextPage = false
    @Published public var hasMore = true
    @Published public var lastError: String?

    private let repository: TransactionRepository
    private let pageSize = 50
    private var offset = 0

    public init(repository: TransactionRepository) {
        self.repository = repository
    }

    public func reload() async {
        offset = 0
        transactions = []
        hasMore = true
        await loadNextPage()
    }

    public func loadNextPage() async {
        guard hasMore, !isLoadingNextPage else { return }
        isLoadingNextPage = true
        defer { isLoadingNextPage = false }
        var effective = query
        let trimmed = searchText.trimmingCharacters(in: .whitespaces)
        effective.searchText = trimmed.isEmpty ? nil : trimmed
        do {
            let page = try await repository.fetchPage(query: effective, offset: offset, limit: pageSize)
            transactions.append(contentsOf: page)
            offset += page.count
            hasMore = page.count == pageSize
        } catch {
            lastError = error.localizedDescription
        }
    }

    public func setCategoryFilter(_ category: TransactionCategory?) async {
        query.category = category
        await reload()
    }

    public func updateCategory(transactionId: UUID, category: TransactionCategory) async {
        do {
            try await repository.updateUserCategory(id: transactionId, category: category)
            if let index = transactions.firstIndex(where: { $0.id == transactionId }) {
                if let updated = try await repository.fetch(id: transactionId) {
                    transactions[index] = updated
                }
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    public func setFlagged(transactionId: UUID, flagged: Bool) async {
        do {
            try await repository.setFlagged(id: transactionId, flagged: flagged)
            if let index = transactions.firstIndex(where: { $0.id == transactionId }),
               let updated = try await repository.fetch(id: transactionId) {
                transactions[index] = updated
            }
        } catch {
            lastError = error.localizedDescription
        }
    }
}
