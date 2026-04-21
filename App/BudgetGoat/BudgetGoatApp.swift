import SwiftUI
import SwiftData
import BudgetCore
import BudgetData
import BudgetUI
import PlaidKit
import SecureStorage

private let deviceIdentity = DeviceIdentityStore()

@main
struct BudgetGoatApp: App {
    @State private var dependencies: AppDependencies?
    @State private var bootstrapError: String?

    var body: some Scene {
        WindowGroup {
            Group {
                if let dependencies {
                    RootView()
                        .environmentObject(dependencies)
                        .modelContainer(dependencies.modelContainer)
                        .onOpenURL { url in
                            // Plaid OAuth redirect re-entry: hand the URL to the
                            // running Link handler so it can resume the flow.
                            _ = dependencies.linkPresenter.resumeAfterRedirect(url)
                        }
                } else if let error = bootstrapError {
                    BootstrapErrorView(message: error)
                } else {
                    ProgressView("Loading…")
                        .task { await bootstrap() }
                }
            }
        }
    }

    private static let tokenKey  = "budgetgoat.session.token"
    private static let expiryKey = "budgetgoat.session.expiry"

    private static func sessionToken(backendURL: URL) async throws -> String {
        // Return cached token if still valid (>1 hour remaining)
        if let cached = UserDefaults.standard.string(forKey: tokenKey),
           !cached.isEmpty,
           let expiry = UserDefaults.standard.object(forKey: expiryKey) as? Date,
           expiry.timeIntervalSinceNow > 3600 {
            return cached
        }
        return try await fetchFreshSessionToken(backendURL: backendURL)
    }

    private static func fetchFreshSessionToken(backendURL: URL) async throws -> String {
        // Fetch or create the device UUID (stored in Keychain, survives reinstall on same device)
        let deviceID = try await deviceIdentity.deviceID()

        // Exchange for a 30-day JWT
        var request = URLRequest(url: backendURL.appendingPathComponent("/auth/device"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["device_id": deviceID])
        request.timeoutInterval = 15

        let (data, _) = try await URLSession.shared.data(for: request)
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let token = json["session_token"] as? String,
              let expiresIn = json["expires_in"] as? TimeInterval else {
            throw BudgetError.invalidResponse("device auth failed")
        }

        UserDefaults.standard.set(token, forKey: tokenKey)
        UserDefaults.standard.set(Date().addingTimeInterval(expiresIn), forKey: expiryKey)
        return token
    }

    private static func invalidateCachedSessionToken() {
        UserDefaults.standard.removeObject(forKey: tokenKey)
        UserDefaults.standard.removeObject(forKey: expiryKey)
    }

    private func bootstrap() async {
        let backendURLString = ProcessInfo.processInfo.environment["BUDGETGOAT_BACKEND_URL"]
            ?? "https://budget-goat-api.fly.dev"
        guard let backendURL = URL(string: backendURLString) else {
            bootstrapError = "Invalid backend URL: \(backendURLString)"
            return
        }

        let proxyConfig = BackendProxyConfiguration(
            baseURL: backendURL,
            sessionTokenProvider: {
                try await Self.sessionToken(backendURL: backendURL)
            },
            sessionTokenInvalidator: {
                Self.invalidateCachedSessionToken()
            },
            pinnedCertificateSHA256: []   // Fly.io Anycast serves different leaf certs per edge node; standard TLS validation is enforced instead
        )

        let configuration = AppDependencies.Configuration(
            baseCurrency: .usd,
            keychainConfiguration: .production,
            proxyConfiguration: proxyConfig
        )

        do {
            dependencies = try await MainActor.run {
                try AppDependencies(configuration: configuration)
            }
        } catch {
            bootstrapError = "Failed to start Budget Goat: \(error.localizedDescription)\n\nPlease reinstall the app or contact support."
        }
    }
}

struct BootstrapErrorView: View {
    let message: String

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.orange)
            Text("Budget Goat couldn't start")
                .font(.title2.bold())
            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Link("Contact Support",
                 destination: URL(string: "mailto:saaketh.manepalli@gmail.com")!)
                .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}
