import Foundation
import Security
import BudgetCore

/// Stores the backend session JWT in the iOS Keychain (not UserDefaults).
/// Keychain entries are encrypted by the secure enclave and excluded from
/// iCloud/iTunes backup when `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`
/// is used. Token + expiry are stored as one JSON blob so they rotate atomically.
public actor SessionTokenStore {

    public struct Entry: Codable, Sendable {
        public let token: String
        public let expiresAt: Date
        public init(token: String, expiresAt: Date) {
            self.token = token
            self.expiresAt = expiresAt
        }
        public var isFresh: Bool { expiresAt.timeIntervalSinceNow > 3600 }
    }

    private let service = "com.ainstein.budgetgoat.session"
    private let account = "device-session"

    public init() {}

    public func load() throws -> Entry? {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData:  true,
            kSecMatchLimit:  kSecMatchLimitOne,
            kSecUseDataProtectionKeychain: true,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            guard let data = result as? Data else { return nil }
            return try? JSONDecoder().decode(Entry.self, from: data)
        case errSecItemNotFound:
            return nil
        default:
            throw BudgetError.keychainFailure(status)
        }
    }

    public func save(_ entry: Entry) throws {
        let data = try JSONEncoder().encode(entry)
        let base: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecUseDataProtectionKeychain: true,
        ]

        // Try update first (avoids duplicate-item error), fall back to add.
        let updateStatus = SecItemUpdate(base as CFDictionary,
                                          [kSecValueData: data] as CFDictionary)
        if updateStatus == errSecSuccess { return }

        var addQuery = base
        addQuery[kSecValueData] = data
        addQuery[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw BudgetError.keychainFailure(addStatus)
        }
    }

    public func clear() {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecUseDataProtectionKeychain: true,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
