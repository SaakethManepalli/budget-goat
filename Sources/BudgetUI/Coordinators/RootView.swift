import SwiftUI
import BudgetCore

public struct RootView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @StateObject private var coordinator = AppCoordinator()
    @State private var hasUnlocked = false
    @State private var reauthItemId: String?

    public init() {}

    public var body: some View {
        Group {
            if hasUnlocked {
                ZStack(alignment: .top) {
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

                    // R3: reauth banner — shown above the tab content when
                    // any Plaid item needs re-authentication.
                    if let itemId = dependencies.reauthCoordinator.pendingItemId {
                        ReauthBanner(
                            itemId: itemId,
                            institutionName: dependencies.reauthCoordinator.pendingInstitutionName
                        ) {
                            reauthItemId = itemId
                        }
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.top, Theme.Spacing.sm)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .environmentObject(coordinator)
                .sheet(isPresented: $coordinator.isShowingLink) {
                    LinkAccountFlow()
                        .environmentObject(dependencies)
                }
                .sheet(item: Binding(
                    get: { reauthItemId.map { ReauthItem(id: $0) } },
                    set: { reauthItemId = $0?.id }
                )) { item in
                    LinkAccountFlow(updateItemId: item.id)
                        .environmentObject(dependencies)
                }
            } else {
                LockScreenView(onUnlock: { hasUnlocked = true })
            }
        }
        .task { await attemptUnlock() }
    }

    private struct ReauthItem: Identifiable { let id: String }

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
