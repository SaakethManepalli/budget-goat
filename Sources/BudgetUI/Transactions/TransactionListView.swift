import SwiftUI
import BudgetCore

public struct TransactionListView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @EnvironmentObject private var coordinator: AppCoordinator
    @StateObject private var holder = Holder()

    private final class Holder: ObservableObject {
        var viewModel: TransactionListViewModel?
    }

    public init() {}

    public var body: some View {
        NavigationStack(path: $coordinator.path) {
            List {
                filterBar
                ForEach(resolved.transactions) { tx in
                    NavigationLink(value: AppRoute.transactionDetail(tx.id)) {
                        TransactionRow(transaction: tx)
                    }
                    .onAppear {
                        if tx == resolved.transactions.last {
                            Task { await resolved.loadNextPage() }
                        }
                    }
                    .swipeActions {
                        Button {
                            Task { await resolved.setFlagged(transactionId: tx.id, flagged: !tx.isFlagged) }
                        } label: {
                            Label(tx.isFlagged ? "Unflag" : "Flag", systemImage: "flag")
                        }
                        .tint(.orange)
                    }
                }
                if resolved.isLoadingNextPage {
                    ProgressView().frame(maxWidth: .infinity)
                }
            }
            .listStyle(.plain)
            .searchable(text: Binding(
                get: { resolved.searchText },
                set: { resolved.searchText = $0 }
            ))
            .onChange(of: resolved.searchText) { _, _ in
                Task { await resolved.reload() }
            }
            .refreshable { await resolved.reload() }
            .navigationTitle("Transactions")
            .navigationDestination(for: AppRoute.self) { $0.destination }
        }
        .task { await resolved.reload() }
    }

    private var resolved: TransactionListViewModel {
        if let existing = holder.viewModel { return existing }
        let vm = TransactionListViewModel(repository: dependencies.transactionRepo)
        holder.viewModel = vm
        return vm
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.sm) {
                FilterChip(
                    title: "All",
                    isActive: resolved.query.category == nil
                ) {
                    Task { await resolved.setCategoryFilter(nil) }
                }
                ForEach(TransactionCategory.allCases, id: \.self) { cat in
                    FilterChip(
                        title: cat.displayName,
                        isActive: resolved.query.category == cat,
                        color: cat.color
                    ) {
                        Task { await resolved.setCategoryFilter(cat) }
                    }
                }
            }
            .padding(.vertical, Theme.Spacing.xs)
        }
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
    }
}

struct FilterChip: View {
    let title: String
    let isActive: Bool
    var color: Color = Theme.Palette.primary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Theme.Typography.caption)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.sm)
                .background(isActive ? color.opacity(0.2) : Theme.Palette.secondary)
                .foregroundStyle(isActive ? color : .primary)
                .clipShape(Capsule())
        }
    }
}
