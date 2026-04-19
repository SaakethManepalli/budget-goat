import SwiftUI
import BudgetCore

public struct AccountDetailView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @Environment(\.dismiss) private var dismiss

    public let accountId: UUID
    @State private var account: AccountSnapshot?
    @State private var editedName: String = ""
    @State private var showDeleteConfirm = false
    @State private var error: String?

    public init(accountId: UUID) {
        self.accountId = accountId
    }

    public var body: some View {
        Group {
            if let account {
                Form {
                    Section("Balance") {
                        LabeledContent("Current", value: Money(amount: account.currentBalance, currency: account.currencyCode).formatted())
                        if let avail = account.availableBalance {
                            LabeledContent("Available", value: Money(amount: avail, currency: account.currencyCode).formatted())
                        }
                        if let limit = account.creditLimit {
                            LabeledContent("Credit limit", value: Money(amount: limit, currency: account.currencyCode).formatted())
                        }
                    }
                    Section("Details") {
                        TextField("Display name", text: $editedName)
                        LabeledContent("Institution", value: account.institutionName)
                        LabeledContent("Type", value: account.accountType.rawValue.capitalized)
                        if let mask = account.mask {
                            LabeledContent("Mask", value: "··\(mask)")
                        }
                        LabeledContent("Last synced", value: account.lastSyncedAt, format: .dateTime)
                    }
                    Section {
                        Button("Save Display Name") {
                            Task { await saveName() }
                        }
                        .disabled(editedName == account.displayName || editedName.isEmpty)
                    }
                    Section {
                        Button("Unlink Bank", role: .destructive) {
                            showDeleteConfirm = true
                        }
                    }
                    if let error {
                        Text(error).foregroundStyle(Theme.Palette.spend)
                    }
                }
                .confirmationDialog("Unlink this bank?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                    Button("Unlink", role: .destructive) {
                        Task { await unlink() }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("This removes the account locally and revokes access with your bank. Your transactions will be deleted.")
                }
            } else {
                ProgressView()
            }
        }
        .task { await load() }
        .navigationTitle(account?.displayName ?? "Account")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private func load() async {
        do {
            account = try await dependencies.accountRepo.fetch(id: accountId)
            editedName = account?.displayName ?? ""
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func saveName() async {
        do {
            try await dependencies.accountRepo.updateDisplayName(id: accountId, displayName: editedName)
            await load()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func unlink() async {
        guard let account else { return }
        do {
            try await dependencies.linkUseCase.removeItem(itemId: account.plaidItemId)
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
