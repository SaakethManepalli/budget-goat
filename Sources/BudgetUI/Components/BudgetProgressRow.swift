import SwiftUI
import BudgetCore

public struct BudgetProgressRow: View {
    public let budget: BudgetSnapshot

    public init(budget: BudgetSnapshot) {
        self.budget = budget
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            HStack {
                Label(budget.category.displayName, systemImage: budget.category.systemIconName)
                    .font(Theme.Typography.body)
                    .foregroundStyle(budget.category.color)
                Spacer()
                Text(
                    "\(Money(amount: budget.spent, currency: budget.currencyCode).formatted()) / \(Money(amount: budget.monthlyLimit, currency: budget.currencyCode).formatted())"
                )
                .font(Theme.Typography.mono)
                .foregroundStyle(budget.isOverBudget ? Theme.Palette.spend : .primary)
            }
            ProgressView(value: min(budget.progress, 1))
                .tint(budget.isOverBudget ? Theme.Palette.spend : budget.category.color)
        }
    }
}
