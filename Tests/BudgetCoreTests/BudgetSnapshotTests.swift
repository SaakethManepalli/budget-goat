import XCTest
@testable import BudgetCore

final class BudgetSnapshotTests: XCTestCase {
    func test_progress_isClampedAtCeiling() {
        let snapshot = BudgetSnapshot(
            id: UUID(),
            category: .groceries,
            monthlyLimit: 100,
            currencyCode: .usd,
            monthStart: Date(),
            notifyAtPercent: 80,
            rollover: false,
            spent: 500
        )
        XCTAssertTrue(snapshot.isOverBudget)
        XCTAssertLessThanOrEqual(snapshot.progress, 1.25)
    }

    func test_remaining_canBeNegative() {
        let snapshot = BudgetSnapshot(
            id: UUID(), category: .groceries, monthlyLimit: 100, currencyCode: .usd,
            monthStart: Date(), notifyAtPercent: 80, rollover: false, spent: 150
        )
        XCTAssertEqual(snapshot.remaining, -50)
    }

    func test_shouldNotify_respectsThreshold() {
        let snapshot = BudgetSnapshot(
            id: UUID(), category: .groceries, monthlyLimit: 100, currencyCode: .usd,
            monthStart: Date(), notifyAtPercent: 80, rollover: false, spent: 90
        )
        XCTAssertTrue(snapshot.shouldNotify)
    }

    func test_shouldNotify_isDisabledAtZero() {
        let snapshot = BudgetSnapshot(
            id: UUID(), category: .groceries, monthlyLimit: 100, currencyCode: .usd,
            monthStart: Date(), notifyAtPercent: 0, rollover: false, spent: 99
        )
        XCTAssertFalse(snapshot.shouldNotify)
    }
}
