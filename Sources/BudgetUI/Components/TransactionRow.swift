import SwiftUI
import BudgetCore

public struct TransactionRow: View {
    public let transaction: TransactionSnapshot

    public init(transaction: TransactionSnapshot) {
        self.transaction = transaction
    }

    public var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            iconBadge
            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.displayName)
                    .font(Theme.Typography.body)
                    .lineLimit(1)
                HStack(spacing: Theme.Spacing.xs) {
                    Text(transaction.category?.displayName ?? "Uncategorized")
                        .foregroundStyle(.secondary)
                    if transaction.isPending {
                        Text("• Pending")
                            .foregroundStyle(.orange)
                    }
                    if transaction.isRecurring {
                        Image(systemName: "repeat")
                            .foregroundStyle(.blue)
                    }
                }
                .font(Theme.Typography.caption)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(Money(amount: transaction.amount, currency: transaction.currencyCode).formatted())
                    .font(Theme.Typography.mono)
                    .foregroundStyle(transaction.isCredit ? Theme.Palette.income : Theme.Palette.spend)
                Text(transaction.authorizedDate, style: .date)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, Theme.Spacing.xs)
        .contentShape(Rectangle())
    }

    private var iconBadge: some View {
        ZStack {
            Circle()
                .fill((transaction.category?.color ?? .secondary).opacity(0.15))
                .frame(width: 40, height: 40)
            Image(systemName: transaction.category?.systemIconName ?? "questionmark.circle.fill")
                .foregroundStyle(transaction.category?.color ?? .secondary)
        }
    }
}
