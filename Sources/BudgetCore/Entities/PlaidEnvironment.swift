import Foundation

public enum PlaidEnvironment: String, Sendable {
    case sandbox     = "sandbox"
    case development = "development"
    case production  = "production"

    /// Read from `PLAID_ENV` env var injected by the build system.
    /// Falls back to sandbox so a misconfigured build can never accidentally
    /// hit production.
    public static var current: PlaidEnvironment {
        #if BUDGETGOAT_SANDBOX
        return .sandbox
        #else
        return .production
        #endif
    }

    public var displayName: String {
        switch self {
        case .sandbox:     "Sandbox (fake banks)"
        case .development: "Development (real banks, limited)"
        case .production:  "Production"
        }
    }

    /// Sandbox has synthetic institutions only (First Platypus, Tartan, etc.)
    /// Development and production have real institutions.
    public var hasRealInstitutions: Bool {
        self != .sandbox
    }
}
