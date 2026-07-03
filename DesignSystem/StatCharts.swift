import SwiftUI
import Charts

/// Axis-less CPU area chart over a fixed trailing window, so the line scrolls
/// left as samples arrive instead of stretching a few points across the width.
struct CPUChart: View {
    let points: [StatsPoint]
    var window: TimeInterval = 120

    var body: some View {
        let now = Date()
        // Scale to the data (min 10%) so an idle container still shows a
        // readable trace instead of a flat line under a mostly-empty box.
        let yMax = max(10, (points.compactMap(\.cpuPercent).max() ?? 0) * 1.25)
        Chart {
            ForEach(Array(StatsMath.segments(points).enumerated()), id: \.offset) { index, segment in
                ForEach(segment) { point in
                    AreaMark(
                        x: .value("Time", point.timestamp),
                        y: .value("CPU", point.cpuPercent ?? 0),
                        series: .value("Segment", index)
                    )
                    .interpolationMethod(.monotone)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.accentColor.opacity(0.28), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    LineMark(
                        x: .value("Time", point.timestamp),
                        y: .value("CPU", point.cpuPercent ?? 0),
                        series: .value("Segment", index)
                    )
                    .interpolationMethod(.monotone)
                    .lineStyle(StrokeStyle(lineWidth: 1.5))
                    .foregroundStyle(Color.accentColor)
                }
            }
        }
        .chartXScale(domain: now.addingTimeInterval(-window)...now)
        .chartYScale(domain: 0...yMax)
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        .frame(height: 64)
    }
}

