import SwiftUI
import BudgetCore

public struct RecurringView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @State private var patterns: [RecurringPatternSnapshot] = []
    @State private var isDetecting = false
    @State private var error: String?

    public init() {}

    public var body: some View {
        List {
            if patterns.isEmpty {
                ContentUnavailableView("No recurring expenses yet", systemImage: "repeat.circle")
            } else {
                ForEach(patterns) { pattern in
                    RecurringRow(pattern: pattern)
                        .swipeActions {
                            Button(role: .destructive) {
                                Task { await deactivate(pattern.id) }
                            } label: {
                                Label("Ignore", systemImage: "eye.slash")
                            }
                        }
                }
            }
            if let error {
                Text(error).foregroundStyle(Theme.Palette.spend)
            }
        }
        .navigationTitle("Recurring")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await detect() }
                } label: {
                    if isDetecting { ProgressView() } else { Image(systemName: "sparkles") }
                }
            }
        }
        .task { await reload() }
    }

    private func reload() async {
        do {
            patterns = try await dependencies.recurringRepo.fetchAll()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func detect() async {
        isDetecting = true
        defer { isDetecting = false }
        do {
            let since = Calendar(identifier: .iso8601).date(byAdding: .month, value: -6, to: Date())
            let query = TransactionQuery(
                dateRange: since.map { $0...Date() },
                sortOrder: .dateAscending
            )
            let txs = try await dependencies.transactionRepo.fetchPage(query: query, offset: 0, limit: 2_000)
            let detected = dependencies.recurringDetector.detect(txs)
            for pattern in detected {
                try await dependencies.recurringRepo.upsert(pattern)
            }
            await reload()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func deactivate(_ id: UUID) async {
        do {
            try await dependencies.recurringRepo.deactivate(id: id)
            await reload()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct RecurringRow: View {
    let pattern: RecurringPatternSnapshot

    var body: some View {
        HStack {
            Image(systemName: "repeat.circle.fill")
                .foregroundStyle(Theme.Palette.primary)
                .font(.title2)
            VStack(alignment: .leading) {
                Text(pattern.canonicalMerchantName)
                    .font(Theme.Typography.body)
                Text("\(pattern.frequency.rawValue.capitalized) • \(pattern.sampleCount) seen")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing) {
                Text(Money(amount: pattern.meanAmount, currency: pattern.currencyCode).formatted())
                    .font(Theme.Typography.mono)
                if let next = pattern.nextExpectedDate {
                    Text("Next: \(next, style: .date)")
                        .font(Theme.Typography.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
