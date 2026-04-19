import SwiftUI
import BudgetCore

public struct AddBudgetView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @Environment(\.dismiss) private var dismiss

    @State private var category: TransactionCategory = .groceries
    @State private var limitString: String = ""
    @State private var notifyAtPercent: Double = 80
    @State private var rollover: Bool = false
    @State private var monthStart = MonthBoundary.start(of: Date())
    @State private var error: String?

    public init() {}

    public var body: some View {
        Form {
            Section("Category") {
                Picker("Category", selection: $category) {
                    ForEach(TransactionCategory.allCases.filter(\.isExpense), id: \.self) { cat in
                        Label(cat.displayName, systemImage: cat.systemIconName).tag(cat)
                    }
                }
            }
            Section("Monthly Limit") {
                TextField("0.00", text: $limitString)
                    #if os(iOS)
                    .keyboardType(.decimalPad)
                    #endif
            }
            Section("Alerts") {
                VStack(alignment: .leading) {
                    Text("Notify at \(Int(notifyAtPercent))%")
                    Slider(value: $notifyAtPercent, in: 0...100, step: 5)
                }
                Toggle("Roll over unspent amount", isOn: $rollover)
            }
            Section("Month") {
                DatePicker("Month", selection: $monthStart, displayedComponents: [.date])
            }
            if let error {
                Section {
                    Text(error).foregroundStyle(Theme.Palette.spend)
                }
            }
        }
        .navigationTitle("New Budget")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Save") { Task { await save() } }
                    .disabled(Decimal(string: limitString) == nil)
            }
        }
    }

    private func save() async {
        guard let limit = Decimal(string: limitString), limit > 0 else {
            error = "Enter a valid amount"
            return
        }
        do {
            try await dependencies.budgetRepo.upsert(
                category: category,
                limit: limit,
                currency: .usd,
                monthStart: monthStart,
                notifyAtPercent: Int(notifyAtPercent),
                rollover: rollover
            )
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
