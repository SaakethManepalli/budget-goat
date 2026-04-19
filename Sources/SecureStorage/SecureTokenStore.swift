import Foundation
import Security
import LocalAuthentication
import BudgetCore

public protocol SecureTokenStoring: TokenStoreResetting, Sendable {
    func store(itemId: String, forKey: String) async throws
    func retrieveItemId(forKey: String) async throws -> String
    func deleteItemId(forKey: String) async throws
    func allItemKeys() async throws -> [String]
}

public final class SecureTokenStore: SecureTokenStoring, @unchecked Sendable {

    public enum Configuration: Sendable {
        case production
        case test

        var service: String {
            switch self {
            case .production: "com.budgetgoat.plaid-items"
            case .test:       "com.budgetgoat.plaid-items.test"
            }
        }

        var requiresBiometry: Bool {
            switch self {
            case .production: true
            case .test:       false
            }
        }
    }

    private let configuration: Configuration
    private let biometricPrompt: String

    public init(
        configuration: Configuration = .production,
        biometricPrompt: String = "Authenticate to access your bank accounts"
    ) {
        self.configuration = configuration
        self.biometricPrompt = biometricPrompt
    }

    public func store(itemId: String, forKey key: String) async throws {
        let data = Data(itemId.utf8)
        let accessControl = try makeAccessControl()

        var addQuery: [CFString: Any] = [
            kSecClass:             kSecClassGenericPassword,
            kSecAttrService:       configuration.service,
            kSecAttrAccount:       key,
            kSecValueData:         data,
            kSecUseDataProtectionKeychain: true,
        ]
        if let accessControl {
            addQuery[kSecAttrAccessControl] = accessControl
        } else {
            addQuery[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        }

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        switch status {
        case errSecSuccess:
            return
        case errSecDuplicateItem:
            try await update(itemId: itemId, forKey: key)
        default:
            throw BudgetError.keychainFailure(status)
        }
    }

    public func retrieveItemId(forKey key: String) async throws -> String {
        var query: [CFString: Any] = [
            kSecClass:                   kSecClassGenericPassword,
            kSecAttrService:             configuration.service,
            kSecAttrAccount:             key,
            kSecReturnData:              true,
            kSecMatchLimit:              kSecMatchLimitOne,
            kSecUseDataProtectionKeychain: true,
        ]
        if configuration.requiresBiometry {
            let context = LAContext()
            context.localizedReason = biometricPrompt
            query[kSecUseAuthenticationContext] = context
        }

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            guard let data = result as? Data,
                  let itemId = String(data: data, encoding: .utf8) else {
                throw BudgetError.keychainFailure(errSecDecode)
            }
            return itemId
        case errSecUserCanceled, errSecAuthFailed:
            throw BudgetError.biometricDenied
        case errSecItemNotFound:
            throw BudgetError.keychainFailure(status)
        default:
            throw BudgetError.keychainFailure(status)
        }
    }

    public func deleteItemId(forKey key: String) async throws {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: configuration.service,
            kSecAttrAccount: key,
            kSecUseDataProtectionKeychain: true,
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw BudgetError.keychainFailure(status)
        }
    }

    public func allItemKeys() async throws -> [String] {
        let query: [CFString: Any] = [
            kSecClass:                    kSecClassGenericPassword,
            kSecAttrService:              configuration.service,
            kSecReturnAttributes:         true,
            kSecMatchLimit:               kSecMatchLimitAll,
            kSecUseDataProtectionKeychain: true,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return [] }
        guard status == errSecSuccess,
              let items = result as? [[CFString: Any]] else {
            throw BudgetError.keychainFailure(status)
        }
        return items.compactMap { $0[kSecAttrAccount] as? String }
    }

    private func update(itemId: String, forKey key: String) async throws {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: configuration.service,
            kSecAttrAccount: key,
            kSecUseDataProtectionKeychain: true,
        ]
        let attributes: [CFString: Any] = [
            kSecValueData: Data(itemId.utf8),
        ]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        guard status == errSecSuccess else {
            throw BudgetError.keychainFailure(status)
        }
    }

    private func makeAccessControl() throws -> SecAccessControl? {
        guard configuration.requiresBiometry else { return nil }
        var error: Unmanaged<CFError>?
        let ac = SecAccessControlCreateWithFlags(
            kCFAllocatorDefault,
            kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            [.biometryCurrentSet],
            &error
        )
        if let cfError = error?.takeRetainedValue() {
            let code = CFErrorGetCode(cfError)
            throw BudgetError.keychainFailure(OSStatus(truncatingIfNeeded: code))
        }
        return ac
    }
}
