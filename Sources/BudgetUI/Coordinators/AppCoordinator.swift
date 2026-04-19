import Foundation
import SwiftUI
import BudgetCore

public enum AppRoute: Hashable {
    case dashboard
    case transactionList
    case transactionDetail(UUID)
    case accountList
    case accountDetail(UUID)
    case budgets
    case addBudget
    case onboarding
    case recurring
    case settings
}

@MainActor
public final class AppCoordinator: ObservableObject {
    @Published public var path = NavigationPath()
    @Published public var selectedTab: Tab = .dashboard
    @Published public var isShowingLink: Bool = false

    public enum Tab: Hashable {
        case dashboard
        case transactions
        case budgets
        case accounts
    }

    public init() {}

    public func push(_ route: AppRoute) { path.append(route) }
    public func pop() { if !path.isEmpty { path.removeLast() } }
    public func popToRoot() { path = NavigationPath() }
    public func showLink() { isShowingLink = true }
    public func dismissLink() { isShowingLink = false }
}
