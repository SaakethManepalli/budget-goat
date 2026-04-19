import Foundation
import LocalAuthentication
import BudgetCore

public protocol BiometricAuthenticating: Sendable {
    func authenticate(reason: String) async throws
    func canEvaluate() -> Bool
}

public final class BiometricAuthenticator: BiometricAuthenticating, @unchecked Sendable {

    public init() {}

    public func canEvaluate() -> Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    public func authenticate(reason: String) async throws {
        let context = LAContext()
        context.localizedFallbackTitle = ""
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            throw BudgetError.biometricUnavailable
        }

        return try await withCheckedThrowingContinuation { continuation in
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, err in
                if success {
                    continuation.resume()
                } else if let laError = err as? LAError, laError.code == .userCancel || laError.code == .userFallback {
                    continuation.resume(throwing: BudgetError.biometricDenied)
                } else {
                    continuation.resume(throwing: BudgetError.biometricDenied)
                }
            }
        }
    }
}
