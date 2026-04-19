import XCTest
@testable import BudgetCore

final class MonthBoundaryTests: XCTestCase {
    func test_start_returnsFirstOfMonth() {
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let date = cal.date(from: DateComponents(year: 2026, month: 4, day: 18, hour: 15))!
        let start = MonthBoundary.start(of: date)
        let components = cal.dateComponents([.year, .month, .day, .hour], from: start)
        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 4)
        XCTAssertEqual(components.day, 1)
        XCTAssertEqual(components.hour, 0)
    }

    func test_end_isNextMonthStart() {
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let date = cal.date(from: DateComponents(year: 2026, month: 4, day: 1))!
        let end = MonthBoundary.end(of: date)
        let components = cal.dateComponents([.year, .month, .day], from: end)
        XCTAssertEqual(components.year, 2026)
        XCTAssertEqual(components.month, 5)
        XCTAssertEqual(components.day, 1)
    }

    func test_range_containsDate() {
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let date = cal.date(from: DateComponents(year: 2026, month: 4, day: 18))!
        let range = MonthBoundary.range(containing: date)
        XCTAssertTrue(range.contains(date))
    }
}
