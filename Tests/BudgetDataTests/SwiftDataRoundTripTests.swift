import XCTest
import SwiftData
@testable import BudgetData
import BudgetCore

final class SwiftDataRoundTripTests: XCTestCase {
    func test_insertAndFetchAccount() async throws {
        let container = try ModelContainerFactory.makeInMemory()
        let repo = AccountRepositoryImpl(container: container)

        let item = LinkedItem(
            itemId: "item_1",
            institutionId: "ins_1",
            institutionName: "Test Bank",
            accounts: [
                LinkedAccount(
                    plaidAccountId: "acc_1",
                    name: "Checking",
                    mask: "1234",
                    type: .checking,
                    subtype: "checking",
                    currencyCode: .usd
                )
            ]
        )

        try await repo.register(item: item)
        let accounts = try await repo.fetchAll()
        XCTAssertEqual(accounts.count, 1)
        XCTAssertEqual(accounts.first?.displayName, "Checking")
    }

    func test_applySyncDelta_addsTransactions() async throws {
        let container = try ModelContainerFactory.makeInMemory()
        let accountRepo = AccountRepositoryImpl(container: container)
        let txRepo = TransactionRepositoryImpl(container: container)

        let item = LinkedItem(
            itemId: "item_1", institutionId: "ins_1", institutionName: "Bank",
            accounts: [LinkedAccount(plaidAccountId: "acc_1", name: "Checking", mask: nil, type: .checking, subtype: nil, currencyCode: .usd)]
        )
        try await accountRepo.register(item: item)

        let delta = SyncDelta(
            added: [
                IngestedTransaction(
                    plaidTransactionId: "tx_1",
                    plaidAccountId: "acc_1",
                    amount: 47.23,
                    currencyCode: .usd,
                    authorizedDate: Date(),
                    postedDate: nil,
                    rawName: "WHOLEFDS MKT #10",
                    merchantName: "Whole Foods Market",
                    category: .groceries,
                    subcategory: nil,
                    categoryConfidence: 0.97,
                    isPending: false,
                    logoURL: nil,
                    merchantLatitude: nil,
                    merchantLongitude: nil
                )
            ],
            modified: [], removed: [],
            nextCursor: "cursor_1", hasMore: false
        )

        try await txRepo.apply(delta: delta, forItemId: "item_1")

        let page = try await txRepo.fetchPage(
            query: TransactionQuery(sortOrder: .dateDescending),
            offset: 0, limit: 10
        )
        XCTAssertEqual(page.count, 1)
        XCTAssertEqual(page.first?.category, .groceries)
    }

    func test_upsertBudget_updatesExisting() async throws {
        let container = try ModelContainerFactory.makeInMemory()
        let txRepo = TransactionRepositoryImpl(container: container)
        let budgetRepo = BudgetRepositoryImpl(container: container, transactionRepo: txRepo)
        let monthStart = MonthBoundary.start(of: Date())

        try await budgetRepo.upsert(
            category: .groceries, limit: 100, currency: .usd,
            monthStart: monthStart, notifyAtPercent: 80, rollover: false
        )
        try await budgetRepo.upsert(
            category: .groceries, limit: 200, currency: .usd,
            monthStart: monthStart, notifyAtPercent: 90, rollover: true
        )

        let budgets = try await budgetRepo.fetchAll(forMonth: monthStart)
        XCTAssertEqual(budgets.count, 1)
        XCTAssertEqual(budgets.first?.monthlyLimit, 200)
        XCTAssertEqual(budgets.first?.notifyAtPercent, 90)
        XCTAssertTrue(budgets.first?.rollover ?? false)
    }
}
