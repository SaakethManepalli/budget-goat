import SwiftUI

public struct OnboardingView: View {
    @EnvironmentObject private var coordinator: AppCoordinator

    public init() {}

    public var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Spacer()
            Image(systemName: "chart.pie.fill")
                .font(.system(size: 96))
                .foregroundStyle(Theme.Palette.primary)
            Text("Welcome to Budget Goat")
                .font(Theme.Typography.display)
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                OnboardingRow(icon: "lock.shield.fill", title: "Private by default", subtitle: "Your data is analyzed on-device. No third-party analytics.")
                OnboardingRow(icon: "sparkles", title: "Smart categorization", subtitle: "LLM-powered cleaning of noisy bank descriptions.")
                OnboardingRow(icon: "repeat.circle.fill", title: "Find subscriptions", subtitle: "Automatic detection of recurring expenses.")
            }
            Spacer()
            Button {
                coordinator.showLink()
            } label: {
                Text("Get Started").font(Theme.Typography.heading).padding(.horizontal)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding()
    }
}

struct OnboardingRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(Theme.Palette.primary)
                .frame(width: 32)
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(title).font(Theme.Typography.heading)
                Text(subtitle).font(Theme.Typography.body).foregroundStyle(.secondary)
            }
        }
    }
}
