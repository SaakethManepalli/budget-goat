import Foundation
import BudgetCore

public actor UserDefaultsCursorStore: CursorStore {
    private let defaults: UserDefaults
    private let prefix = "budgetgoat.plaid.cursor."

    public init(suiteName: String? = nil) {
        self.defaults = suiteName.flatMap { UserDefaults(suiteName: $0) } ?? .standard
    }

    public func cursor(forItemId itemId: String) async -> String? {
        defaults.string(forKey: prefix + itemId)
    }

    public func save(cursor: String, forItemId itemId: String) async {
        defaults.set(cursor, forKey: prefix + itemId)
    }

    public func clear(itemId: String) async {
        defaults.removeObject(forKey: prefix + itemId)
    }
}
