import SwiftUI
import BudgetCore

public struct TransactionDetailView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @Environment(\.dismiss) private var dismiss

    public let transactionId: UUID
    @State private var snapshot: TransactionSnapshot?
    @State private var note: String = ""
    @State private var selectedCategory: TransactionCategory?
    @State private var isEditingNote = false
    @State private var error: String?

    public init(transactionId: UUID) {
        self.transactionId = transactionId
    }

    public var body: some View {
        Group {
            if let snapshot {
                List {
                    Section {
                        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                            Text(snapshot.displayName)
                                .font(Theme.Typography.heading)
                            Text(Money(amount: snapshot.amount, currency: snapshot.currencyCode).formatted())
                                .font(Theme.Typography.display)
                                .foregroundStyle(snapshot.isCredit ? Theme.Palette.income : Theme.Palette.spend)
                            Text(snapshot.authorizedDate, style: .date)
                                .font(Theme.Typography.body)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Section("Details") {
                        LabeledContent("Account", value: snapshot.accountDisplayName)
                        LabeledContent("Raw description", value: snapshot.rawName)
                        if let merchant = snapshot.merchantName {
                            LabeledContent("Merchant", value: merchant)
                        }
                        if snapshot.isPending {
                            Label("Pending", systemImage: "clock")
                                .foregroundStyle(.orange)
                        }
                    }

                    Section("Category") {
                        Picker("Category", selection: Binding(
                            get: { selectedCategory ?? snapshot.category ?? .other },
                            set: { selectedCategory = $0 }
                        )) {
                            ForEach(TransactionCategory.allCases, id: \.self) { cat in
                                Label(cat.displayName, systemImage: cat.systemIconName).tag(cat)
                            }
                        }
                        if let confidence = snapshot.categoryConfidence {
                            LabeledContent("Confidence", value: String(format: "%.0f%%", confidence * 100))
                        }
                        LabeledContent("Source", value: snapshot.categorySource.rawValue.capitalized)
                    }

                    Section("Notes") {
                        TextField("Add a note", text: $note, axis: .vertical)
                            .lineLimit(3...6)
                    }

                    if let error {
                        Section {
                            Text(error).foregroundStyle(Theme.Palette.spend)
                        }
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Save") {
                            Task { await save() }
                        }
                    }
                }
            } else {
                ProgressView()
            }
        }
        .task { await load() }
        .navigationTitle("Transaction")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private func load() async {
        do {
            let snap = try await dependencies.transactionRepo.fetch(id: transactionId)
            snapshot = snap
            note = snap?.userNote ?? ""
            selectedCategory = snap?.category
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func save() async {
        do {
            if let category = selectedCategory, category != snapshot?.category {
                try await dependencies.transactionRepo.updateUserCategory(id: transactionId, category: category)
            }
            try await dependencies.transactionRepo.updateNote(id: transactionId, note: note.isEmpty ? nil : note)
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
