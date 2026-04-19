import Foundation
import BudgetCore

public struct CachedClassification: Sendable, Codable, Hashable {
    public let canonicalName: String
    public let category: TransactionCategory
    public let subcategory: String?
    public let confidence: Float
    public let updatedAt: Date

    public init(canonicalName: String, category: TransactionCategory, subcategory: String?, confidence: Float, updatedAt: Date = .init()) {
        self.canonicalName = canonicalName
        self.category = category
        self.subcategory = subcategory
        self.confidence = confidence
        self.updatedAt = updatedAt
    }
}

public actor MerchantCategoryCache {

    private var storage: [String: CachedClassification] = [:]
    private let defaults: UserDefaults
    private let defaultsKey = "budgetgoat.engine.merchantCache"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: defaultsKey),
           let decoded = try? JSONDecoder().decode([String: CachedClassification].self, from: data) {
            self.storage = decoded
        }
    }

    public func lookup(merchant: String) -> CachedClassification? {
        storage[normalize(merchant)]
    }

    public func store(merchant: String, classification: CachedClassification) {
        storage[normalize(merchant)] = classification
        persist()
    }

    public func invalidate(merchant: String) {
        storage.removeValue(forKey: normalize(merchant))
        persist()
    }

    public func clear() {
        storage.removeAll()
        persist()
    }

    private func normalize(_ merchant: String) -> String {
        merchant.lowercased().trimmingCharacters(in: .whitespaces)
    }

    private func persist() {
        let data = try? JSONEncoder().encode(storage)
        defaults.set(data, forKey: defaultsKey)
    }
}
