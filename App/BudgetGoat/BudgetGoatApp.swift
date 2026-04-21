import SwiftUI
import SwiftData
import BudgetCore
import BudgetData
import BudgetUI
import PlaidKit
import SecureStorage

private let deviceIdentity = DeviceIdentityStore()
private let sessionTokens = SessionTokenStore()

@main
struct BudgetGoatApp: App {
    @State private var dependencies: AppDependencies?
    @State private var bootstrapError: String?
    @Environment(\.scenePhase) private var scenePhase

    init() {
        MetricsCollector.shared.start()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let dependencies {
                    RootView()
                        .environmentObject(dependencies)
                        .modelContainer(dependencies.modelContainer)
                        .onOpenURL { url in
                            _ = dependencies.linkPresenter.resumeAfterRedirect(url)
                        }
                } else if let error = bootstrapError {
                    BootstrapErrorView(message: error)
                } else {
                    ProgressView("Loading…")
                        .task { await bootstrap() }
                }
            }
            // R1: privacy overlay — blurs the window the moment the scene
            // leaves .active, which is BEFORE iOS captures the app switcher
            // snapshot. Without this, bank balances appear in the task grid.
            .privacyOverlay(when: scenePhase)
        }
    }

    // MARK: - Session token (Keychain, not UserDefaults)

    private static func sessionToken(backendURL: URL) async throws -> String {
        // R2: JWT lives in Keychain under
        // kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly. Survives restart,
        // bound to device, excluded from iCloud backup, unreadable while locked.
        if let entry = try? await sessionTokens.load(), entry.isFresh {
            return entry.token
        }
        return try await fetchFreshSessionToken(backendURL: backendURL)
    }

    private static func fetchFreshSessionToken(backendURL: URL) async throws -> String {
        let deviceID = try await deviceIdentity.deviceID()

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

        let entry = SessionTokenStore.Entry(
            token: token,
            expiresAt: Date().addingTimeInterval(expiresIn)
        )
        try? await sessionTokens.save(entry)
        return token
    }

    private static func invalidateCachedSessionToken() async {
        await sessionTokens.clear()
    }

    // MARK: - Bootstrap

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
                await Self.invalidateCachedSessionToken()
            },
            pinnedCertificateSHA256: []   // CA pinning: follow-up (Y2)
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
