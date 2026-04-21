import SwiftUI

/// Maps AppRoute cases to their destination view. Kept separate from
/// AppCoordinator/AppRoute so destination mapping can evolve without
/// touching navigation state.
public extension AppRoute {
    @ViewBuilder
    var destination: some View {
        switch self {
        case .dashboard:                 DashboardView()
        case .transactionList:           TransactionListView()
        case .transactionDetail(let id): TransactionDetailView(transactionId: id)
        case .accountList:               AccountsView()
        case .accountDetail(let id):     AccountDetailView(accountId: id)
        case .budgets:                   BudgetsView()
        case .addBudget:                 AddBudgetView()
        case .onboarding:                OnboardingView()
        case .recurring:                 RecurringView()
        case .settings:                  SettingsView()
        }
    }
}
