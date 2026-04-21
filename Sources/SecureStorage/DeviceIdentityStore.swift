import Foundation
import Security
import BudgetCore

public actor DeviceIdentityStore {

    private let service = "com.budgetgoat.device-identity"
    private let accountKey = "device-uuid"

    public init() {}

    public func deviceID() throws -> String {
        if let existing = try? read() { return existing }
        let fresh = UUID().uuidString
        try write(fresh)
        return fresh
    }

    private func read() throws -> String {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: accountKey,
            kSecReturnData:  true,
            kSecMatchLimit:  kSecMatchLimitOne,
            kSecUseDataProtectionKeychain: true,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let id = String(data: data, encoding: .utf8) else {
            throw BudgetError.keychainFailure(status)
        }
        return id
    }

    private func write(_ id: String) throws {
        let data = Data(id.utf8)
        let addQuery: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: accountKey,
            kSecValueData:   data,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecUseDataProtectionKeychain: true,
        ]
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw BudgetError.keychainFailure(status)
        }
    }
}
