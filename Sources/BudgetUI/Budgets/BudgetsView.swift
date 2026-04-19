import SwiftUI
import BudgetCore

public struct BudgetsView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @EnvironmentObject private var coordinator: AppCoordinator
    @State private var budgets: [BudgetSnapshot] = []
    @State private var monthStart = MonthBoundary.start(of: Date())
    @State private var error: String?

    public init() {}

    public var body: some View {
        NavigationStack(path: $coordinator.path) {
            List {
                monthPicker
                if budgets.isEmpty {
                    ContentUnavailableView {
                        Label("No budgets yet", systemImage: "target")
                    } description: {
                        Text("Create a monthly limit per category to track spending.")
                    } actions: {
                        Button("Add Budget") { coordinator.push(.addBudget) }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    ForEach(budgets) { budget in
                        BudgetProgressRow(budget: budget)
                            .listRowSeparator(.hidden)
                            .swipeActions {
                                Button(role: .destructive) {
                                    Task { await delete(budget.id) }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }
                if let error {
                    Text(error).foregroundStyle(Theme.Palette.spend)
                }
            }
            .listStyle(.plain)
            .navigationTitle("Budgets")
            .navigationDestination(for: AppRoute.self) { $0.destination }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        coordinator.push(.addBudget)
                    } label: { Image(systemName: "plus") }
                }
            }
            .refreshable { await reload() }
        }
        .task { await reload() }
    }

    private var monthPicker: some View {
        HStack {
            Button {
                monthStart = Calendar(identifier: .iso8601).date(byAdding: .month, value: -1, to: monthStart) ?? monthStart
                Task { await reload() }
            } label: { Image(systemName: "chevron.left") }
            Spacer()
            Text(monthStart, format: .dateTime.year().month(.wide))
                .font(Theme.Typography.heading)
            Spacer()
            Button {
                monthStart = Calendar(identifier: .iso8601).date(byAdding: .month, value: 1, to: monthStart) ?? monthStart
                Task { await reload() }
            } label: { Image(systemName: "chevron.right") }
        }
        .listRowSeparator(.hidden)
    }

    private func reload() async {
        do {
            budgets = try await dependencies.budgetRepo.fetchAll(forMonth: monthStart)
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func delete(_ id: UUID) async {
        do {
            try await dependencies.budgetRepo.delete(id: id)
            await reload()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
