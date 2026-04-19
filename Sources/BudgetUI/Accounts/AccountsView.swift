import SwiftUI
import BudgetCore

public struct AccountsView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @EnvironmentObject private var coordinator: AppCoordinator
    @State private var accounts: [AccountSnapshot] = []
    @State private var isSyncing = false
    @State private var error: String?

    public init() {}

    public var body: some View {
        NavigationStack(path: $coordinator.path) {
            List {
                if accounts.isEmpty {
                    ContentUnavailableView {
                        Label("No linked accounts", systemImage: "building.columns")
                    } description: {
                        Text("Link a bank through Plaid to get started.")
                    } actions: {
                        Button("Link Bank") { coordinator.showLink() }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    Section {
                        ForEach(accounts) { account in
                            NavigationLink(value: AppRoute.accountDetail(account.id)) {
                                AccountRow(account: account)
                            }
                        }
                    }
                }
                if let error {
                    Text(error).foregroundStyle(Theme.Palette.spend)
                }
            }
            #if os(iOS)
            .listStyle(.insetGrouped)
            #endif
            .navigationTitle("Accounts")
            .navigationDestination(for: AppRoute.self) { $0.destination }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        coordinator.push(.settings)
                    } label: { Image(systemName: "gear") }
                }
                ToolbarItem(placement: .primaryAction) {
                    HStack {
                        Button {
                            Task { await syncAll() }
                        } label: {
                            if isSyncing {
                                ProgressView()
                            } else {
                                Image(systemName: "arrow.clockwise")
                            }
                        }
                        Button {
                            coordinator.showLink()
                        } label: { Image(systemName: "plus") }
                    }
                }
            }
            .refreshable { await reload() }
        }
        .task { await reload() }
    }

    private func reload() async {
        do {
            accounts = try await dependencies.accountRepo.fetchAll()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func syncAll() async {
        isSyncing = true
        defer { isSyncing = false }
        do {
            _ = try await dependencies.syncUseCase.executeAll()
            await reload()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct AccountRow: View {
    let account: AccountSnapshot

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(account.displayName)
                    .font(Theme.Typography.body)
                Text(account.institutionName)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(Money(amount: account.currentBalance, currency: account.currencyCode).formatted())
                    .font(Theme.Typography.mono)
                Text(account.accountType.rawValue.capitalized)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
