import XCTest
@testable import TransactionEngine
import BudgetCore

final class RecurringDetectorTests: XCTestCase {
    func test_detectsMonthlySubscription() {
        let detector = RecurringDetector()
        let calendar = Calendar(identifier: .iso8601)
        var date = calendar.date(from: DateComponents(year: 2026, month: 1, day: 15))!
        var transactions: [TransactionSnapshot] = []
        for _ in 0..<6 {
            transactions.append(makeSnapshot(date: date, canonical: "Netflix", amount: 15.99))
            date = calendar.date(byAdding: .day, value: 30, to: date)!
        }
        let patterns = detector.detect(transactions)
        XCTAssertEqual(patterns.count, 1)
        XCTAssertEqual(patterns.first?.frequency, .monthly)
        XCTAssertEqual(patterns.first?.canonicalMerchantName, "Netflix")
    }

    func test_ignoresIrregularSpending() {
        let detector = RecurringDetector()
        let cal = Calendar(identifier: .iso8601)
        var date = Date()
        var transactions: [TransactionSnapshot] = []
        let irregularDays = [1, 17, 19, 82, 83, 97]
        for days in irregularDays {
            date = cal.date(byAdding: .day, value: days, to: Date())!
            transactions.append(makeSnapshot(date: date, canonical: "Random Cafe", amount: Decimal(Int.random(in: 5...50))))
        }
        let patterns = detector.detect(transactions)
        XCTAssertTrue(patterns.isEmpty)
    }

    func test_requiresMinimumSampleCount() {
        let detector = RecurringDetector(minimumSampleCount: 3)
        let cal = Calendar(identifier: .iso8601)
        let dates = (0..<2).map { cal.date(byAdding: .day, value: $0 * 30, to: Date())! }
        let txs = dates.map { makeSnapshot(date: $0, canonical: "Netflix", amount: 15.99) }
        XCTAssertTrue(detector.detect(txs).isEmpty)
    }

    private func makeSnapshot(date: Date, canonical: String, amount: Decimal) -> TransactionSnapshot {
        TransactionSnapshot(
            id: UUID(), plaidTransactionId: UUID().uuidString, accountId: UUID(),
            accountDisplayName: "Checking", amount: amount, currencyCode: .usd,
            amountInBaseCurrency: nil, authorizedDate: date, postedDate: nil,
            rawName: canonical, merchantName: canonical, canonicalName: canonical, logoURL: nil,
            category: .subscriptions, subcategory: nil, categorySource: .plaid,
            categoryConfidence: 0.9, isPending: false, isRecurring: false,
            recurringPatternId: nil, userNote: nil, isFlagged: false, isHidden: false
        )
    }
}
