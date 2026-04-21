import SwiftUI

/// A reusable glass surface. Never use a solid color background for
/// information cards — compose `ultraThinMaterial` over True Black foundation
/// and let the refractive blur do the visual work.
public struct GlassCard<Content: View>: View {
    private let content: Content
    private let emphasis: Emphasis

    public enum Emphasis {
        case regular          // standard info card
        case elevated         // hero area (top-of-dashboard), slightly brighter
        case inset            // sunken surface (for long form fields)
    }

    public init(_ emphasis: Emphasis = .regular, @ViewBuilder content: () -> Content) {
        self.emphasis = emphasis
        self.content = content()
    }

    public var body: some View {
        content
            .padding(Theme.Spacing.lg)
            .background(material)
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .strokeBorder(Theme.Palette.glassBorder, lineWidth: 0.5)
            }
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
    }

    @ViewBuilder
    private var material: some View {
        switch emphasis {
        case .regular:
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(Theme.Palette.glassTint)
        case .elevated:
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(Theme.Palette.glassHighlight)
                .overlay(alignment: .top) {
                    // Subtle top highlight — the "light catch" on real glass
                    LinearGradient(
                        colors: [Color.white.opacity(0.08), .clear],
                        startPoint: .top, endPoint: .center
                    )
                }
        case .inset:
            Rectangle()
                .fill(.thinMaterial)
                .overlay(Color.black.opacity(0.25))
        }
    }
}

/// A thin horizontal divider with the same hairline weight as GlassCard borders.
public struct Hairline: View {
    public init() {}
    public var body: some View {
        Rectangle()
            .fill(Theme.Palette.glassBorder)
            .frame(height: 0.5)
    }
}
