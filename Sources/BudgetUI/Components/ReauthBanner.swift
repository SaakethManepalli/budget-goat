import SwiftUI
import BudgetCore

/// Shown when any Plaid item has entered ITEM_LOGIN_REQUIRED. Tapping it
/// launches Plaid Link in "update mode" — the same Link UI, but scoped to
/// the specific item, prompting the user to re-authenticate with the bank.
public struct ReauthBanner: View {
    public let itemId: String
    public let institutionName: String?
    public let onTap: () -> Void

    public init(itemId: String, institutionName: String?, onTap: @escaping () -> Void) {
        self.itemId = itemId
        self.institutionName = institutionName
        self.onTap = onTap
    }

    public var body: some View {
        Button(action: onTap) {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Theme.Palette.debit)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Reconnect \(institutionName ?? "bank")")
                        .font(Theme.Typography.body)
                        .foregroundStyle(Theme.Palette.primaryText)
                    Text("Your bank requires re-authentication to keep syncing.")
                        .font(Theme.Typography.micro)
                        .foregroundStyle(Theme.Palette.secondaryText)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.Palette.tertiaryText)
            }
            .padding(Theme.Spacing.md)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Theme.Radius.medium))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.medium)
                    .strokeBorder(Theme.Palette.debit.opacity(0.4), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}

/// Centralizes reauth state so any view can react to it.
@MainActor
public final class ReauthCoordinator: ObservableObject {
    @Published public var pendingItemId: String?
    @Published public var pendingInstitutionName: String?

    public init() {}

    public func flag(itemId: String, institutionName: String?) {
        pendingItemId = itemId
        pendingInstitutionName = institutionName
    }

    public func clear() {
        pendingItemId = nil
        pendingInstitutionName = nil
    }
}
