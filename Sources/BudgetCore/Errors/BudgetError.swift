import Foundation

public enum BudgetError: Error, LocalizedError, Sendable {
    case linkCancelled
    case linkFailed(String)
    case tokenExchangeFailed(String)
    case syncFailed(String)
    case itemRequiresReauth(itemId: String)
    case keychainFailure(OSStatus)
    case biometricUnavailable
    case biometricDenied
    case storageUnavailable
    case categorizationFailed(String)
    case networkUnavailable
    case invalidResponse(String)
    case unauthorized

    public var errorDescription: String? {
        switch self {
        case .linkCancelled:              "Bank linking cancelled."
        case .linkFailed(let m):          "Bank linking failed: \(m)"
        case .tokenExchangeFailed(let m): "Unable to complete account setup: \(m)"
        case .syncFailed(let m):          "Unable to sync transactions: \(m)"
        case .itemRequiresReauth:         "Your bank requires re-authentication."
        case .keychainFailure(let s):     "Secure storage error (\(s))."
        case .biometricUnavailable:       "Face ID / Touch ID is not available."
        case .biometricDenied:            "Authentication was denied."
        case .storageUnavailable:         "Local storage is unavailable."
        case .categorizationFailed(let m):"Categorization failed: \(m)"
        case .networkUnavailable:         "Network unavailable."
        case .invalidResponse(let m):     "Unexpected response: \(m)"
        case .unauthorized:               "Session expired — please sign in again."
        }
    }
}
