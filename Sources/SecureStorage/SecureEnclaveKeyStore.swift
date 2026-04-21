import Foundation
import Security
import CryptoKit
import BudgetCore

public protocol DeviceSigning: Sendable {
    func provisionKeyIfNeeded() throws -> Data
    func publicKeyDER() throws -> Data
    func sign(payload: Data) throws -> Data
}

public final class SecureEnclaveKeyStore: DeviceSigning, @unchecked Sendable {

    public enum Configuration: Sendable {
        case production
        case test

        var tag: String {
            switch self {
            case .production: "com.budgetgoat.device-signing-key"
            case .test:       "com.budgetgoat.device-signing-key.test"
            }
        }
    }

    private let configuration: Configuration

    public init(configuration: Configuration = .production) {
        self.configuration = configuration
    }

    public func provisionKeyIfNeeded() throws -> Data {
        if let existing = try? publicKeyDER() {
            return existing
        }
        try generate()
        return try publicKeyDER()
    }

    public func publicKeyDER() throws -> Data {
        let privateKey = try loadPrivateKey()
        guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
            throw BudgetError.keychainFailure(errSecInvalidKeyRef)
        }
        var error: Unmanaged<CFError>?
        guard let data = SecKeyCopyExternalRepresentation(publicKey, &error) as Data? else {
            let code = error.map { Int(CFErrorGetCode($0.takeRetainedValue())) } ?? -1
            throw BudgetError.keychainFailure(OSStatus(truncatingIfNeeded: code))
        }
        return data
    }

    public func sign(payload: Data) throws -> Data {
        let privateKey = try loadPrivateKey()
        var error: Unmanaged<CFError>?
        guard let signature = SecKeyCreateSignature(
            privateKey,
            .ecdsaSignatureMessageX962SHA256,
            payload as CFData,
            &error
        ) as Data? else {
            let code = error.map { Int(CFErrorGetCode($0.takeRetainedValue())) } ?? -1
            throw BudgetError.keychainFailure(OSStatus(truncatingIfNeeded: code))
        }
        return signature
    }

    private func generate() throws {
        let tag = Data(configuration.tag.utf8)
        var error: Unmanaged<CFError>?

        let accessControl: SecAccessControl?
        if isSecureEnclaveAvailable() {
            accessControl = SecAccessControlCreateWithFlags(
                kCFAllocatorDefault,
                kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
                [.privateKeyUsage],
                &error
            )
            if let cfError = error?.takeRetainedValue() {
                throw BudgetError.keychainFailure(OSStatus(truncatingIfNeeded: CFErrorGetCode(cfError)))
            }
        } else {
            accessControl = nil
        }

        var attributes: [String: Any] = [
            kSecAttrKeyType as String:       kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String: 256,
        ]

        var privateAttrs: [String: Any] = [
            kSecAttrIsPermanent as String:    true,
            kSecAttrApplicationTag as String: tag,
        ]
        if let accessControl {
            privateAttrs[kSecAttrAccessControl as String] = accessControl
        }
        if isSecureEnclaveAvailable() {
            attributes[kSecAttrTokenID as String] = kSecAttrTokenIDSecureEnclave
        }
        attributes[kSecPrivateKeyAttrs as String] = privateAttrs

        guard SecKeyCreateRandomKey(attributes as CFDictionary, &error) != nil else {
            let code = error.map { Int(CFErrorGetCode($0.takeRetainedValue())) } ?? -1
            throw BudgetError.keychainFailure(OSStatus(truncatingIfNeeded: code))
        }
    }

    private func loadPrivateKey() throws -> SecKey {
        let tag = Data(configuration.tag.utf8)
        let query: [String: Any] = [
            kSecClass as String:              kSecClassKey,
            kSecAttrApplicationTag as String: tag,
            kSecAttrKeyType as String:        kSecAttrKeyTypeECSECPrimeRandom,
            kSecReturnRef as String:          true,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let keyRef = item else {
            throw BudgetError.keychainFailure(status)
        }
        guard CFGetTypeID(keyRef) == SecKeyGetTypeID() else {
            throw BudgetError.keychainFailure(errSecInvalidKeyRef)
        }
        return keyRef as! SecKey
    }

    private func isSecureEnclaveAvailable() -> Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        return true
        #endif
    }
}
