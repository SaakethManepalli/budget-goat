import SwiftUI
import Charts
import BudgetCore

/// An organic, living spend-over-time chart.
/// Architectural choices:
/// - `AreaMark` with `.catmullRom` interpolation: curves feel natural, not mechanical.
/// - Gradient fill drops from the line to transparent — reads as "light falloff"
///   rather than a solid tinted block.
/// - The top `LineMark` is rendered separately with a stronger alpha so the
///   stroke "edge" catches the eye; the area underneath is glazed.
/// - Scrub interaction uses `chartXSelection` — no overlay view needed.
public struct LivingAreaChart: View {

    public struct Point: Identifiable, Hashable {
        public let id = UUID()
        public let date: Date
        public let value: Double
        public init(date: Date, value: Double) {
            self.date = date
            self.value = value
        }
    }

    public let points: [Point]
    public let accent: Color
    @State private var selectedDate: Date?

    public init(points: [Point], accent: Color = Theme.Palette.accent) {
        self.points = points
        self.accent = accent
    }

    public var body: some View {
        Chart {
            ForEach(points) { p in
                AreaMark(
                    x: .value("Date", p.date),
                    y: .value("Spent", p.value)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(fillGradient)
                .alignsMarkStylesWithPlotArea()

                LineMark(
                    x: .value("Date", p.date),
                    y: .value("Spent", p.value)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(accent.opacity(0.9))
                .lineStyle(StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
                .shadow(color: accent.opacity(0.4), radius: 6, x: 0, y: 0)
            }

            if let selectedDate, let selected = nearest(to: selectedDate) {
                RuleMark(x: .value("Selected", selected.date))
                    .foregroundStyle(Theme.Palette.glassBorder)
                    .lineStyle(StrokeStyle(lineWidth: 0.5, dash: [2, 3]))

                PointMark(
                    x: .value("Date", selected.date),
                    y: .value("Spent", selected.value)
                )
                .foregroundStyle(accent)
                .symbolSize(80)
                .annotation(position: .top, alignment: .center, spacing: 6) {
                    annotationBubble(for: selected)
                }
            }
        }
        .chartXSelection(value: $selectedDate)
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { _ in
                AxisGridLine()
                    .foregroundStyle(Theme.Palette.glassBorder)
                AxisValueLabel()
                    .foregroundStyle(Theme.Palette.tertiaryText)
                    .font(Theme.Typography.micro)
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisValueLabel(format: .dateTime.month(.abbreviated).day(),
                               collisionResolution: .greedy)
                    .foregroundStyle(Theme.Palette.tertiaryText)
                    .font(Theme.Typography.micro)
            }
        }
        .chartLegend(.hidden)
    }

    // MARK: - Subviews

    private var fillGradient: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: accent.opacity(0.35), location: 0.0),
                .init(color: accent.opacity(0.12), location: 0.45),
                .init(color: accent.opacity(0.0),  location: 1.0),
            ],
            startPoint: .top, endPoint: .bottom
        )
    }

    private func annotationBubble(for p: Point) -> some View {
        VStack(spacing: 2) {
            Text(p.date, format: .dateTime.month(.abbreviated).day())
                .font(Theme.Typography.micro)
                .foregroundStyle(Theme.Palette.secondaryText)
            Text(p.value, format: .currency(code: "USD"))
                .font(Theme.Typography.amountSmall)
                .foregroundStyle(Theme.Palette.primaryText)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Theme.Palette.glassBorder, lineWidth: 0.5))
    }

    private func nearest(to date: Date) -> Point? {
        points.min(by: { abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date)) })
    }
}
