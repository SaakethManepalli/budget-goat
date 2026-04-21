import SwiftUI

/// iOS caches a snapshot of the foreground app when the user swipes up to
/// App Switcher. For a FinTech app this snapshot contains bank balances,
/// merchants, amounts — which is then visible in the task-switcher grid.
///
/// Fix: observe `scenePhase` and overlay a full-screen blur before the
/// snapshot is taken. iOS captures the snapshot during `.inactive` (between
/// `.active` and `.background`), so we must react on `.inactive` — not
/// `.background`, which is too late.
public struct PrivacyOverlay: View {
    public init() {}

    public var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 56, weight: .regular))
                    .foregroundStyle(Theme.Palette.accent)
                Text("Budget Goat")
                    .font(Theme.Typography.micro)
                    .tracking(3)
                    .foregroundStyle(Theme.Palette.secondaryText)
                    .textCase(.uppercase)
            }
        }
    }
}

public extension View {
    /// Apply a privacy overlay whenever the scene is not active.
    /// Attach at the root of your window content.
    func privacyOverlay(when scenePhase: ScenePhase) -> some View {
        self.overlay {
            if scenePhase != .active {
                PrivacyOverlay()
                    .transition(.opacity)
                    .zIndex(1000)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: scenePhase)
    }
}
