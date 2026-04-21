import SwiftUI

/// Intentional data-loading sequence. Drives the "syncing transactions" view.
/// Phases are an explicit state machine — no ad-hoc `Task.sleep` choreography.
public struct PhaseLoadingView: View {

    public enum Phase: CaseIterable, Hashable {
        case idle, contacting, authenticating, syncing, settling

        var caption: String {
            switch self {
            case .idle:            "Ready"
            case .contacting:      "Contacting your bank"
            case .authenticating:  "Verifying identity"
            case .syncing:         "Retrieving transactions"
            case .settling:        "Organizing your finances"
            }
        }
    }

    public let phase: Phase

    public init(phase: Phase) {
        self.phase = phase
    }

    public var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            // Animated glyph — each phase gets a subtly different mark position,
            // and PhaseAnimator interpolates scale/opacity between them.
            PhaseAnimator([0, 1, 2], trigger: phase) { step in
                ZStack {
                    // Outer ring
                    Circle()
                        .stroke(Theme.Palette.glassBorder, lineWidth: 1)
                        .frame(width: 96, height: 96)

                    // Sweeping arc that completes as phases advance
                    Circle()
                        .trim(from: 0, to: progressFraction)
                        .stroke(
                            Theme.Palette.accent,
                            style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 96, height: 96)
                        .shadow(color: Theme.Palette.accent.opacity(0.5), radius: 4)

                    Circle()
                        .fill(Theme.Palette.accent)
                        .frame(width: 6, height: 6)
                        .scaleEffect(step == 1 ? 1.6 : 1.0)
                        .opacity(step == 2 ? 0.5 : 1.0)
                }
                .animation(.smooth(duration: 0.9), value: step)
            }

            // Caption crossfades between phases with numeric-text transition
            Text(phase.caption)
                .font(Theme.Typography.caption)
                .foregroundStyle(Theme.Palette.secondaryText)
                .textCase(.uppercase)
                .tracking(1.5)
                .contentTransition(.opacity)
                .animation(.smooth(duration: 0.35), value: phase)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(Theme.Spacing.xxl)
    }

    private var progressFraction: CGFloat {
        switch phase {
        case .idle:           0.0
        case .contacting:     0.25
        case .authenticating: 0.55
        case .syncing:        0.85
        case .settling:       1.0
        }
    }
}
