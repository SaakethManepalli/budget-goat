import SwiftUI
import Charts
import BudgetCore

public struct DashboardView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @EnvironmentObject private var coordinator: AppCoordinator
    @StateObject private var holder = Holder()
    @State private var loadingPhase: PhaseLoadingView.Phase = .idle

    private final class Holder: ObservableObject {
        var vm: DashboardViewModel?
    }

    public init() {}

    public var body: some View {
        NavigationStack(path: $coordinator.path) {
            ZStack {
                Theme.Palette.foundation.ignoresSafeArea()

                if resolvedVM.isLoading && resolvedVM.totalBalance == .zero {
                    PhaseLoadingView(phase: loadingPhase)
                        .task { await drivePhaseAnimation() }
                        .transition(.opacity)
                } else {
                    content
                }
            }
            .navigationTitle("")
            .toolbar { toolbarItems }
            .navigationDestination(for: AppRoute.self) { $0.destination }
            #if os(iOS)
            .toolbarBackground(Theme.Palette.foundation, for: .navigationBar)
            #endif
            .preferredColorScheme(.dark)
            .sensoryFeedback(HapticWeight.feedback(for: resolvedVM.monthSpent), trigger: resolvedVM.monthSpent)
        }
        .task { await refresh() }
        .refreshable { await refresh() }
    }

    // MARK: - Content

    private var content: some View {
        ScrollView {
            LazyVStack(spacing: Theme.Spacing.md) {
                heroCard
                    .scrollTransition(axis: .vertical) { effect, phase in
                        effect
                            .opacity(phase.isIdentity ? 1 : 0.6)
                            .scaleEffect(phase.isIdentity ? 1 : 0.92)
                            .blur(radius: phase.isIdentity ? 0 : 6)
                    }

                spendTrajectoryCard
                    .standardScrollTransition()

                categoryRail
                    .standardScrollTransition()

                if !resolvedVM.budgetsNearLimit.isEmpty {
                    budgetAlertsCard
                        .standardScrollTransition()
                }

                recentTransactionsCard
                    .standardScrollTransition()
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Hero (Total Balance)

    private var heroCard: some View {
        GlassCard(.elevated) {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                Text("Total Balance")
                    .font(Theme.Typography.micro)
                    .foregroundStyle(Theme.Palette.secondaryText)
                    .tracking(2)

                MonoAmount(resolvedVM.totalBalance, size: .hero)

                Hairline()

                HStack(spacing: Theme.Spacing.lg) {
                    heroDelta(
                        label: "Spent",
                        amount: resolvedVM.monthSpent,
                        color: Theme.Palette.debit
                    )
                    Divider()
                        .frame(height: 32)
                        .background(Theme.Palette.glassBorder)
                    heroDelta(
                        label: "Income",
                        amount: resolvedVM.monthIncome,
                        color: Theme.Palette.credit
                    )
                }
            }
        }
    }

    private func heroDelta(label: String, amount: Decimal, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(Theme.Typography.micro)
                .foregroundStyle(Theme.Palette.tertiaryText)
                .tracking(1.5)
            HStack(spacing: 6) {
                Circle().fill(color).frame(width: 6, height: 6)
                MonoAmount(amount, size: .medium)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Spend Trajectory Chart

    private var spendTrajectoryCard: some View {
        GlassCard() {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("This Month")
                            .font(Theme.Typography.micro)
                            .foregroundStyle(Theme.Palette.tertiaryText)
                            .tracking(1.5)
                        Text("Spend Trajectory")
                            .font(Theme.Typography.heading)
                            .foregroundStyle(Theme.Palette.primaryText)
                    }
                    Spacer()
                }

                LivingAreaChart(
                    points: trajectoryPoints,
                    accent: Theme.Palette.accent
                )
                .frame(height: 180)
            }
        }
    }

    private var trajectoryPoints: [LivingAreaChart.Point] {
        // Build a running-total curve from the month's transactions.
        // Empty state gets a flat zero line so the card doesn't collapse.
        let today = Date()
        let start = MonthBoundary.start(of: today)
        guard resolvedVM.monthSpent > 0 else {
            return [
                .init(date: start, value: 0),
                .init(date: today, value: 0),
            ]
        }
        // Simple interpolation — replace with real daily running totals later.
        let days = Calendar.current.dateComponents([.day], from: start, to: today).day ?? 1
        let total = (resolvedVM.monthSpent as NSDecimalNumber).doubleValue
        return (0...max(days, 1)).map { d in
            let date = Calendar.current.date(byAdding: .day, value: d, to: start) ?? today
            // Lightly randomized organic curve (deterministic on day index)
            let pseudo = sin(Double(d) * 0.4) * 0.08 + 1.0
            let progress = Double(d) / Double(max(days, 1))
            return .init(date: date, value: total * progress * pseudo)
        }
    }

    // MARK: - Category rail

    private var categoryRail: some View {
        GlassCard() {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                Text("By Category")
                    .font(Theme.Typography.micro)
                    .foregroundStyle(Theme.Palette.tertiaryText)
                    .tracking(1.5)

                if resolvedVM.topCategories.isEmpty {
                    Text("No spending this month yet.")
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Palette.secondaryText)
                } else {
                    ForEach(resolvedVM.topCategories.prefix(5)) { spend in
                        categoryRow(spend)
                    }
                }
            }
        }
    }

    private func categoryRow(_ spend: DashboardViewModel.CategorySpend) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            ZStack {
                Circle()
                    .fill(spend.category.chartTint.opacity(0.18))
                    .frame(width: 36, height: 36)
                Image(systemName: spend.category.systemIconName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(spend.category.chartTint)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(spend.category.displayName)
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Palette.primaryText)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Theme.Palette.glassBorder)
                        Rectangle()
                            .fill(spend.category.chartTint)
                            .frame(width: geo.size.width * progressRatio(spend))
                    }
                }
                .frame(height: 2)
                .clipShape(Capsule())
            }
            Spacer(minLength: 4)
            MonoAmount(spend.amount, size: .small)
        }
        .padding(.vertical, 2)
    }

    private func progressRatio(_ spend: DashboardViewModel.CategorySpend) -> Double {
        guard let top = resolvedVM.topCategories.first else { return 0 }
        let max = (top.amount as NSDecimalNumber).doubleValue
        guard max > 0 else { return 0 }
        return (spend.amount as NSDecimalNumber).doubleValue / max
    }

    // MARK: - Budget alerts

    private var budgetAlertsCard: some View {
        GlassCard() {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                HStack(spacing: Theme.Spacing.sm) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Theme.Palette.debit)
                    Text("Attention")
                        .font(Theme.Typography.micro)
                        .tracking(1.5)
                        .foregroundStyle(Theme.Palette.debit)
                }
                ForEach(resolvedVM.budgetsNearLimit.prefix(3)) { budget in
                    budgetAlertRow(budget)
                }
            }
        }
    }

    private func budgetAlertRow(_ budget: BudgetSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(budget.category.displayName, systemImage: budget.category.systemIconName)
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Palette.primaryText)
                Spacer()
                MonoAmount(budget.spent, size: .small)
                Text(" / ")
                    .font(Theme.Typography.amountSmall)
                    .foregroundStyle(Theme.Palette.tertiaryText)
                MonoAmount(budget.monthlyLimit, size: .small)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.Palette.glassBorder)
                    Capsule()
                        .fill(budget.isOverBudget ? Theme.Palette.debit : budget.category.chartTint)
                        .frame(width: geo.size.width * min(budget.progress, 1))
                }
            }
            .frame(height: 3)
        }
    }

    // MARK: - Recent transactions

    private var recentTransactionsCard: some View {
        GlassCard() {
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                HStack {
                    Text("Recent")
                        .font(Theme.Typography.micro)
                        .foregroundStyle(Theme.Palette.tertiaryText)
                        .tracking(1.5)
                    Spacer()
                    Button("All") { coordinator.selectedTab = .transactions }
                        .font(Theme.Typography.caption)
                        .foregroundStyle(Theme.Palette.accent)
                }
                ForEach(resolvedVM.recentTransactions.prefix(6)) { tx in
                    transactionRow(tx)
                        .onTapGesture { coordinator.push(.transactionDetail(tx.id)) }
                }
            }
        }
    }

    private func transactionRow(_ tx: TransactionSnapshot) -> some View {
        HStack(spacing: Theme.Spacing.md) {
            ZStack {
                Circle()
                    .fill((tx.category?.chartTint ?? Theme.Palette.tertiaryText).opacity(0.15))
                    .frame(width: 32, height: 32)
                Image(systemName: tx.category?.systemIconName ?? "creditcard")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(tx.category?.chartTint ?? Theme.Palette.secondaryText)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(tx.displayName)
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Palette.primaryText)
                    .lineLimit(1)
                Text(tx.authorizedDate, format: .dateTime.month(.abbreviated).day())
                    .font(Theme.Typography.micro)
                    .foregroundStyle(Theme.Palette.tertiaryText)
            }
            Spacer(minLength: 4)
            MonoAmount(tx.amount, currency: tx.currencyCode, size: .small, signed: true)
        }
        .contentShape(Rectangle())
        .sensoryFeedback(HapticWeight.feedback(for: tx.amount), trigger: tx.id)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .principal) {
            Text("Budget Goat")
                .font(Theme.Typography.micro)
                .tracking(3)
                .foregroundStyle(Theme.Palette.secondaryText)
                .textCase(.uppercase)
        }
        ToolbarItem(placement: .primaryAction) {
            Button {
                coordinator.showLink()
            } label: {
                Image(systemName: "plus.circle")
                    .foregroundStyle(Theme.Palette.accent)
            }
            .sensoryFeedback(HapticWeight.navigation, trigger: coordinator.isShowingLink)
        }
    }

    // MARK: - ViewModel

    private var resolvedVM: DashboardViewModel {
        if let existing = holder.vm { return existing }
        let vm = DashboardViewModel(
            transactionRepo: dependencies.transactionRepo,
            accountRepo: dependencies.accountRepo,
            budgetRepo: dependencies.budgetRepo
        )
        holder.vm = vm
        return vm
    }

    private func refresh() async {
        await resolvedVM.load()
    }

    private func drivePhaseAnimation() async {
        for phase: PhaseLoadingView.Phase in [.contacting, .authenticating, .syncing, .settling] {
            loadingPhase = phase
            try? await Task.sleep(for: .milliseconds(700))
        }
    }
}

// MARK: - ScrollTransition convenience

private extension View {
    /// Standard card recede-as-leaving-viewport effect.
    func standardScrollTransition() -> some View {
        self.scrollTransition(axis: .vertical) { effect, phase in
            effect
                .opacity(phase.isIdentity ? 1 : 0.7)
                .scaleEffect(phase.isIdentity ? 1 : 0.96)
        }
    }
}
