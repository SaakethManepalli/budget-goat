import XCTest
@testable import BudgetCore

final class CategoryTests: XCTestCase {
    func test_expenseCategories_excludeIncomeAndTransfer() {
        XCTAssertFalse(TransactionCategory.income.isExpense)
        XCTAssertFalse(TransactionCategory.transfer.isExpense)
        XCTAssertTrue(TransactionCategory.groceries.isExpense)
        XCTAssertTrue(TransactionCategory.dining.isExpense)
    }

    func test_displayNames_arePresent() {
        for category in TransactionCategory.allCases {
            XCTAssertFalse(category.displayName.isEmpty)
            XCTAssertFalse(category.systemIconName.isEmpty)
        }
    }

    func test_currencyCode_uppercases() {
        let code: CurrencyCode = "usd"
        XCTAssertEqual(code.rawValue, "USD")
    }

    func test_money_formatsNonEmpty() {
        let money = Money(amount: 12.34, currency: .usd)
        XCTAssertFalse(money.formatted(locale: Locale(identifier: "en_US")).isEmpty)
    }
}
