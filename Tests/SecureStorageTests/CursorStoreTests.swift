import XCTest
@testable import SecureStorage

final class CursorStoreTests: XCTestCase {
    func test_saveAndFetch() async throws {
        let suiteName = "budgetgoat.test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = UserDefaultsCursorStore(suiteName: suiteName)
        await store.save(cursor: "cursor_abc", forItemId: "item_1")
        let fetched = await store.cursor(forItemId: "item_1")
        XCTAssertEqual(fetched, "cursor_abc")
    }

    func test_clear_removesCursor() async throws {
        let suiteName = "budgetgoat.test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = UserDefaultsCursorStore(suiteName: suiteName)
        await store.save(cursor: "c", forItemId: "item_1")
        await store.clear(itemId: "item_1")
        let fetched = await store.cursor(forItemId: "item_1")
        XCTAssertNil(fetched)
    }

    func test_isolatedByItemId() async throws {
        let suiteName = "budgetgoat.test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = UserDefaultsCursorStore(suiteName: suiteName)
        await store.save(cursor: "A", forItemId: "item_1")
        await store.save(cursor: "B", forItemId: "item_2")
        let c1 = await store.cursor(forItemId: "item_1")
        let c2 = await store.cursor(forItemId: "item_2")
        XCTAssertEqual(c1, "A")
        XCTAssertEqual(c2, "B")
    }
}
