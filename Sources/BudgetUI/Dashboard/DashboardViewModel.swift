import Foundation
import SwiftUI
import BudgetCore

@MainActor
public final class DashboardViewModel: ObservableObject {
    @Published public private(set) var totalBalance: Decimal = .zero
    @Published public private(set) var monthSpent: Decimal = .zero
    @Published public private(set) var monthIncome: Decimal = .zero
    @Published public private(set) var recentTransactions: [TransactionSnapshot] = []
    @Published public private(set) var topCategories: [CategorySpend] = []
    @Published public private(set) var budgetsNearLimit: [BudgetSnapshot] = []
    @Published public private(set) var isLoading = false
    @Published public var lastError: String?

    public struct CategorySpend: Identifiable, Hashable, Sendable {
        public let id = UUID()
        public let category: TransactionCategory
        public let amount: Decimal
    }

    private let transactionRepo: TransactionRepository
    private let accountRepo: AccountRepository
    private let budgetRepo: BudgetRepository
    private let baseCurrency: CurrencyCode

    public init(
        transactionRepo: TransactionRepository,
        accountRepo: AccountRepository,
        budgetRepo: BudgetRepository,
        baseCurrency: CurrencyCode = .usd
    ) {
        self.transactionRepo = transactionRepo
        self.accountRepo = accountRepo
        self.budgetRepo = budgetRepo
        self.baseCurrency = baseCurrency
    }

    public func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            async let accounts = accountRepo.fetchAll()
            let monthStart = MonthBoundary.start(of: Date())
            async let budgets = budgetRepo.fetchAll(forMonth: monthStart)
            let recent = try await transactionRepo.fetchPage(
                query: TransactionQuery(sortOrder: .dateDescending),
                offset: 0,
                limit: 10
            )

            self.totalBalance = try await accounts.reduce(Decimal.zero) { acc, account in
                acc + account.currentBalance
            }
            self.recentTransactions = recent

            var spentByCategory: [TransactionCategory: Decimal] = [:]
            for category in TransactionCategory.allCases where category.isExpense {
                let spent = try await transactionRepo.totalSpent(
                    category: category, monthStart: monthStart, in: baseCurrency
                )
                if spent > 0 { spentByCategory[category] = spent }
            }
            self.monthSpent = spentByCategory.values.reduce(0, +)
            self.topCategories = spentByCategory
                .map { CategorySpend(category: $0.key, amount: $0.value) }
                .sorted { $0.amount > $1.amount }

            self.monthIncome = try await transactionRepo.totalSpent(
                category: .income, monthStart: monthStart, in: baseCurrency
            )
            self.budgetsNearLimit = try await budgets.filter { $0.shouldNotify }
        } catch {
            self.lastError = (error as? BudgetError)?.errorDescription ?? error.localizedDescription
        }
    }
}
