import SwiftUI
import BudgetCore

public struct SettingsView: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @EnvironmentObject private var coordinator: AppCoordinator
    @State private var linkedItemKeys: [String] = []
    @State private var error: String?
    @State private var exportFile: ExportFile?
    @State private var isExporting = false
    @State private var showDeleteConfirm = false
    @State private var isDeleting = false
    @State private var deleteSummary: ResetDataUseCase.Summary?

    public init() {}

    public var body: some View {
        List {
            Section("Privacy") {
                Label("On-device analytics only", systemImage: "lock.shield.fill")
                Label("No third-party SDK", systemImage: "hand.raised.fill")
                Label("Biometric unlock required", systemImage: "faceid")
            }

            Section("Linked Items") {
                if linkedItemKeys.isEmpty {
                    Text("No linked banks").foregroundStyle(.secondary)
                } else {
                    ForEach(linkedItemKeys, id: \.self) { key in
                        Label(key, systemImage: "key.fill")
                            .font(Theme.Typography.mono)
                            .lineLimit(1)
                    }
                }
            }

            Section("Tools") {
                NavigationLink(value: AppRoute.recurring) {
                    Label("Recurring Detection", systemImage: "sparkles")
                }
                Button {
                    Task { await runExport() }
                } label: {
                    HStack {
                        Label("Export Data (JSON)", systemImage: "square.and.arrow.up")
                        Spacer()
                        if isExporting { ProgressView() }
                    }
                }
                .disabled(isExporting)
            }

            Section("About") {
                LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                Link(destination: URL(string: "https://plaid.com/legal/")!) {
                    Label("Plaid Privacy Policy", systemImage: "doc.text")
                }
                Link(destination: URL(string: "https://budgetgoat.app/privacy")!) {
                    Label("Budget Goat Privacy Policy", systemImage: "doc.text")
                }
                Link(destination: URL(string: "https://budgetgoat.app/terms")!) {
                    Label("Terms of Service", systemImage: "doc.text")
                }
                Link(destination: URL(string: "mailto:saaketh.manepalli@gmail.com")!) {
                    Label("Contact Support", systemImage: "envelope")
                }
            }

            Section("Danger Zone") {
                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    HStack {
                        Label("Delete Account", systemImage: "trash")
                        Spacer()
                        if isDeleting { ProgressView() }
                    }
                }
                .disabled(isDeleting)
            }

            if let summary = deleteSummary {
                Section("Delete Result") {
                    Text("\(summary.itemsRevoked) bank link(s) revoked.")
                        .foregroundStyle(.secondary)
                    if !summary.itemsFailedToRevoke.isEmpty {
                        Text("\(summary.itemsFailedToRevoke.count) item(s) could not be revoked remotely. Local data was still deleted.")
                            .font(Theme.Typography.caption)
                            .foregroundStyle(Theme.Palette.spend)
                    }
                }
            }

            if let error {
                Text(error).foregroundStyle(Theme.Palette.spend)
            }
        }
        .navigationTitle("Settings")
        .sheet(item: $exportFile) { file in
            ShareSheet(file: file)
        }
        .confirmationDialog(
            "Delete everything?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete all data", role: .destructive) {
                Task { await runDelete() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will revoke access with every linked bank, remove all stored access tokens, and erase all transactions, budgets, and recurring patterns from this device. This cannot be undone.")
        }
        .task { await loadLinkedItems() }
    }

    private func loadLinkedItems() async {
        do {
            linkedItemKeys = try await dependencies.tokenStore.allItemKeys()
        } catch let err as BudgetError {
            error = err.errorDescription
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func runExport() async {
        isExporting = true
        defer { isExporting = false }
        do {
            let data = try await dependencies.exportUseCase.execute()
            let filename = dependencies.exportUseCase.suggestedFilename()
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
            try data.write(to: url, options: [.atomic, .completeFileProtection])
            exportFile = ExportFile(url: url)
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func runDelete() async {
        isDeleting = true
        defer { isDeleting = false }
        do {
            let summary = try await dependencies.resetUseCase.execute()
            deleteSummary = summary
            linkedItemKeys = []
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct ExportFile: Identifiable {
    let id = UUID()
    let url: URL
}

#if canImport(UIKit)
import UIKit

struct ShareSheet: UIViewControllerRepresentable {
    let file: ExportFile

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [file.url], applicationActivities: nil)
    }

    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
#else
struct ShareSheet: View {
    let file: ExportFile
    var body: some View { Text("Share not available on this platform.") }
}
#endif
