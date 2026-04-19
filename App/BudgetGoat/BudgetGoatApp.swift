import SwiftUI
import SwiftData
import BudgetCore
import BudgetData
import BudgetUI
import PlaidKit
import SecureStorage

@main
struct BudgetGoatApp: App {
    @StateObject private var dependencies: AppDependencies

    init() {
        let baseURL = URL(string: ProcessInfo.processInfo.environment["BUDGETGOAT_BACKEND_URL"]
            ?? "https://api.budgetgoat.example") ?? URL(string: "https://localhost")!

        let proxyConfig = BackendProxyConfiguration(
            baseURL: baseURL,
            sessionTokenProvider: {
                UserDefaults.standard.string(forKey: "budgetgoat.session.token") ?? ""
            }
        )

        let configuration = AppDependencies.Configuration(
            baseCurrency: .usd,
            keychainConfiguration: .production,
            proxyConfiguration: proxyConfig
        )

        let bootstrapped: AppDependencies
        do {
            bootstrapped = try AppDependencies(configuration: configuration)
        } catch {
            fatalError("Failed to bootstrap AppDependencies: \(error)")
        }
        _dependencies = StateObject(wrappedValue: bootstrapped)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(dependencies)
                .modelContainer(dependencies.modelContainer)
        }
    }
}
