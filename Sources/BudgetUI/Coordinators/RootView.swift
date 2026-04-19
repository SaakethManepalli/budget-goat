import SwiftUI
import BudgetCore

public struct RootView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @StateObject private var coordinator = AppCoordinator()
    @State private var hasUnlocked = false

    public init() {}

    public var body: some View {
        Group {
            if hasUnlocked {
                TabView(selection: $coordinator.selectedTab) {
                    DashboardView()
                        .tabItem { Label("Dashboard", systemImage: "chart.pie.fill") }
                        .tag(AppCoordinator.Tab.dashboard)

                    TransactionListView()
                        .tabItem { Label("Transactions", systemImage: "list.bullet") }
                        .tag(AppCoordinator.Tab.transactions)

                    BudgetsView()
                        .tabItem { Label("Budgets", systemImage: "target") }
                        .tag(AppCoordinator.Tab.budgets)

                    AccountsView()
                        .tabItem { Label("Accounts", systemImage: "building.columns.fill") }
                        .tag(AppCoordinator.Tab.accounts)
                }
                .environmentObject(coordinator)
                .sheet(isPresented: $coordinator.isShowingLink) {
                    LinkAccountFlow()
                        .environmentObject(dependencies)
                }
            } else {
                LockScreenView(onUnlock: { hasUnlocked = true })
            }
        }
        .task {
            await attemptUnlock()
        }
    }

    private func attemptUnlock() async {
        guard !hasUnlocked else { return }
        do {
            try await dependencies.biometricAuth.authenticate(reason: "Unlock Budget Goat")
            hasUnlocked = true
        } catch {
            hasUnlocked = false
        }
    }
}

struct LockScreenView: View {
    let onUnlock: () -> Void
    @EnvironmentObject private var dependencies: AppDependencies
    @State private var error: String?

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 96))
                .foregroundStyle(Theme.Palette.primary)
            Text("Budget Goat")
                .font(Theme.Typography.display)
            Text("Your finances, on-device. Authenticate to continue.")
                .font(Theme.Typography.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)

            Button {
                Task { await attempt() }
            } label: {
                Label("Unlock with Face ID", systemImage: "faceid")
                    .font(Theme.Typography.heading)
                    .padding(.horizontal)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            if let error {
                Text(error)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Palette.spend)
            }
        }
        .padding()
    }

    private func attempt() async {
        do {
            try await dependencies.biometricAuth.authenticate(reason: "Unlock Budget Goat")
            onUnlock()
        } catch let err as BudgetError {
            error = err.errorDescription
        } catch {
            self.error = error.localizedDescription
        }
    }
}
