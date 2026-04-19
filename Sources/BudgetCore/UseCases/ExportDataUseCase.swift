import Foundation

public struct ExportPayload: Codable, Sendable {
    public let exportedAt: Date
    public let appVersion: String
    public let schemaVersion: Int
    public let accounts: [AccountSnapshot]
    public let transactions: [TransactionSnapshot]
    public let budgets: [BudgetSnapshot]
    public let recurringPatterns: [RecurringPatternSnapshot]

    public init(
        exportedAt: Date = Date(),
        appVersion: String,
        schemaVersion: Int = 1,
        accounts: [AccountSnapshot],
        transactions: [TransactionSnapshot],
        budgets: [BudgetSnapshot],
        recurringPatterns: [RecurringPatternSnapshot]
    ) {
        self.exportedAt = exportedAt
        self.appVersion = appVersion
        self.schemaVersion = schemaVersion
        self.accounts = accounts
        self.transactions = transactions
        self.budgets = budgets
        self.recurringPatterns = recurringPatterns
    }
}

public struct ExportDataUseCase: Sendable {
    private let accountRepo: AccountRepository
    private let transactionRepo: TransactionRepository
    private let budgetRepo: BudgetRepository
    private let recurringRepo: RecurringRepository
    private let appVersion: String

    public init(
        accountRepo: AccountRepository,
        transactionRepo: TransactionRepository,
        budgetRepo: BudgetRepository,
        recurringRepo: RecurringRepository,
        appVersion: String
    ) {
        self.accountRepo = accountRepo
        self.transactionRepo = transactionRepo
        self.budgetRepo = budgetRepo
        self.recurringRepo = recurringRepo
        self.appVersion = appVersion
    }

    public func execute() async throws -> Data {
        async let accounts = accountRepo.fetchAll()
        async let transactions = transactionRepo.fetchAllForExport()
        async let budgets = budgetRepo.fetchAllForExport()
        async let recurring = recurringRepo.fetchAll()

        let payload = ExportPayload(
            appVersion: appVersion,
            accounts: try await accounts,
            transactions: try await transactions,
            budgets: try await budgets,
            recurringPatterns: try await recurring
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(payload)
    }

    public func suggestedFilename() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return "budget-goat-export-\(formatter.string(from: Date())).json"
    }
}
