import SwiftUI
import BudgetCore
import PlaidKit

#if canImport(UIKit)
import UIKit
#endif

public struct LinkAccountFlow: View {
    @EnvironmentObject private var dependencies: AppDependencies
    @Environment(\.dismiss) private var dismiss

    /// When set, launch Plaid Link in update mode scoped to this item (reauth flow).
    public let updateItemId: String?

    @State private var state: LinkState = .idle
    @State private var linkToken: String?
    @State private var error: String?

    public init(updateItemId: String? = nil) {
        self.updateItemId = updateItemId
    }

    enum LinkState: Equatable {
        case idle
        case fetchingToken
        case presenting
        case exchanging
        case success(SyncSummary)
        case failed(String)

        static func == (lhs: LinkState, rhs: LinkState) -> Bool {
            String(describing: lhs) == String(describing: rhs)
        }
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: Theme.Spacing.lg) {
                Spacer()
                icon
                statusText
                if case .success(let summary) = state {
                    VStack {
                        Text("Imported \(summary.added) transactions")
                            .font(Theme.Typography.heading)
                        Button("Done") { dismiss() }
                            .buttonStyle(.borderedProminent)
                    }
                } else if case .failed(let message) = state {
                    VStack(spacing: Theme.Spacing.sm) {
                        Text(message)
                            .foregroundStyle(Theme.Palette.spend)
                        Button("Try Again") { Task { await begin() } }
                            .buttonStyle(.borderedProminent)
                    }
                } else if case .idle = state {
                    Button {
                        Task { await begin() }
                    } label: {
                        Label("Connect a Bank", systemImage: "building.columns")
                            .font(Theme.Typography.heading)
                            .padding()
                    }
                    .buttonStyle(.borderedProminent)
                }
                Spacer()
                privacyDisclosure
            }
            .padding()
            .navigationTitle("Link Bank")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private var icon: some View {
        ZStack {
            Circle()
                .fill(Theme.Palette.primary.opacity(0.1))
                .frame(width: 120, height: 120)
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 56))
                .foregroundStyle(Theme.Palette.primary)
        }
    }

    private var statusText: some View {
        Group {
            switch state {
            case .idle:
                Text("Budget Goat uses Plaid to connect securely. Access tokens stay on our servers — never on your device.")
            case .fetchingToken:
                ProgressView("Contacting Plaid…")
            case .presenting:
                ProgressView("Awaiting bank authorization…")
            case .exchanging:
                ProgressView("Importing transactions…")
            case .success:
                Text("Linked successfully.")
            case .failed(let message):
                Text(message)
            }
        }
        .multilineTextAlignment(.center)
        .font(Theme.Typography.body)
        .foregroundStyle(.secondary)
        .padding(.horizontal)
    }

    private var privacyDisclosure: some View {
        VStack(spacing: Theme.Spacing.xs) {
            Image(systemName: "hand.raised.fill")
                .foregroundStyle(Theme.Palette.primary)
            Text("Zero-knowledge: your transaction data is analyzed on-device. No third-party analytics.")
                .font(Theme.Typography.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding()
    }

    private func begin() async {
        state = .fetchingToken
        do {
            let token: String
            if let itemId = updateItemId {
                // Reauth / update mode — Plaid Link scoped to existing item
                token = try await dependencies.syncProvider.createUpdateLinkToken(forItemId: itemId)
            } else {
                token = try await dependencies.linkUseCase.createLinkToken()
            }
            self.linkToken = token
            state = .presenting
            let success = try await presentLink(token: token)

            if updateItemId != nil {
                // Update mode: no token exchange — the existing access_token
                // is already valid on the backend. Clear the reauth flag and
                // trigger a fresh sync on the caller.
                dependencies.reauthCoordinator.clear()
                state = .success(SyncSummary(added: 0, modified: 0, removed: 0, durationSeconds: 0))
            } else {
                state = .exchanging
                let summary = try await dependencies.linkUseCase.completeLink(
                    publicToken: success.publicToken,
                    institutionId: success.institutionId
                )
                state = .success(summary)
            }
        } catch BudgetError.linkCancelled {
            state = .idle
        } catch let err as BudgetError {
            state = .failed(err.errorDescription ?? "Link failed")
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    @MainActor
    private func presentLink(token: String) async throws -> PlaidLinkSuccess {
        #if canImport(UIKit)
        guard let host = UIApplication.shared.topViewController() else {
            throw BudgetError.linkFailed("no presenting VC")
        }
        return try await dependencies.linkPresenter.presentLink(on: host, linkToken: token)
        #else
        throw BudgetError.linkFailed("Plaid Link requires iOS UIKit runtime")
        #endif
    }
}

#if canImport(UIKit)
extension UIApplication {
    func topViewController() -> UIViewController? {
        let scene = connectedScenes
            .filter { $0.activationState == .foregroundActive }
            .compactMap { $0 as? UIWindowScene }
            .first
        guard let root = scene?.windows.first(where: \.isKeyWindow)?.rootViewController else { return nil }
        var current: UIViewController = root
        while let presented = current.presentedViewController { current = presented }
        return current
    }
}
#endif
