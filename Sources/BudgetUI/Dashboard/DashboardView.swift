import SwiftUI
import Charts
import BudgetCore

public struct DashboardView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @EnvironmentObject private var coordinator: AppCoordinator
    @StateObject private var viewModel = Holder()

    private final class Holder: ObservableObject {
        var vm: DashboardViewModel?
    }

    public init() {}

    public var body: some View {
        NavigationStack(path: $coordinator.path) {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    header
                    summaryCards
                    if !resolvedVM.topCategories.isEmpty {
                        categoryChart
                    }
                    if !resolvedVM.budgetsNearLimit.isEmpty {
                        budgetAlerts
                    }
                    recentTransactionsSection
                }
                .padding()
            }
            .refreshable { await refresh() }
            .navigationTitle("Budget Goat")
            .navigationDestination(for: AppRoute.self) { route in
                route.destination
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        coordinator.showLink()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
        }
        .task { await refresh() }
    }

    private var resolvedVM: DashboardViewModel {
        if let existing = viewModel.vm { return existing }
        let vm = DashboardViewModel(
            transactionRepo: dependencies.transactionRepo,
            accountRepo: dependencies.accountRepo,
            budgetRepo: dependencies.budgetRepo
        )
        viewModel.vm = vm
        return vm
    }

    private func refresh() async {
        await resolvedVM.load()
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text("Total Balance")
                .font(Theme.Typography.caption)
                .foregroundStyle(.secondary)
            Text(Money(amount: resolvedVM.totalBalance, currency: .usd).formatted())
                .font(Theme.Typography.display)
        }
    }

    private var summaryCards: some View {
        HStack(spacing: Theme.Spacing.md) {
            SummaryCard(
                title: "Spent this month",
                value: Money(amount: resolvedVM.monthSpent, currency: .usd).formatted(),
                color: Theme.Palette.spend,
                icon: "arrow.up.right"
            )
            SummaryCard(
                title: "Income this month",
                value: Money(amount: resolvedVM.monthIncome, currency: .usd).formatted(),
                color: Theme.Palette.income,
                icon: "arrow.down.right"
            )
        }
    }

    private var categoryChart: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Top Categories")
                .font(Theme.Typography.heading)
            Chart(resolvedVM.topCategories.prefix(6)) { spend in
                BarMark(
                    x: .value("Amount", (spend.amount as NSDecimalNumber).doubleValue),
                    y: .value("Category", spend.category.displayName)
                )
                .foregroundStyle(spend.category.color)
            }
            .frame(height: 220)
        }
        .padding()
        .background(Theme.Palette.secondary)
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
    }

    private var budgetAlerts: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Label("Budgets near limit", systemImage: "exclamationmark.triangle.fill")
                .font(Theme.Typography.heading)
                .foregroundStyle(Theme.Palette.spend)
            ForEach(resolvedVM.budgetsNearLimit) { budget in
                BudgetProgressRow(budget: budget)
            }
        }
        .padding()
        .background(Theme.Palette.secondary)
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
    }

    private var recentTransactionsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Text("Recent Transactions")
                    .font(Theme.Typography.heading)
                Spacer()
                Button("See all") {
                    coordinator.selectedTab = .transactions
                }
                .font(Theme.Typography.caption)
            }
            ForEach(resolvedVM.recentTransactions) { tx in
                TransactionRow(transaction: tx)
                    .onTapGesture {
                        coordinator.push(.transactionDetail(tx.id))
                    }
            }
        }
    }
}

struct SummaryCard: View {
    let title: String
    let value: String
    let color: Color
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Label(title, systemImage: icon)
                .font(Theme.Typography.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(Theme.Typography.heading)
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Theme.Palette.secondary)
        .clipShape(RoundedRectangle(cornerRadius: Theme.CornerRadius.medium))
    }
}

extension AppRoute {
    @ViewBuilder
    var destination: some View {
        switch self {
        case .dashboard:                DashboardView()
        case .transactionList:          TransactionListView()
        case .transactionDetail(let id): TransactionDetailView(transactionId: id)
        case .accountList:              AccountsView()
        case .accountDetail(let id):    AccountDetailView(accountId: id)
        case .budgets:                  BudgetsView()
        case .addBudget:                AddBudgetView()
        case .onboarding:               OnboardingView()
        case .recurring:                RecurringView()
        case .settings:                 SettingsView()
        }
    }
}
