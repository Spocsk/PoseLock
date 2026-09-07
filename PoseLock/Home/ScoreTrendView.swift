import Charts
import SwiftUI

struct ScoreTrendView: View {
    var poseName: String
    var points: [DailyBest]
    var average: Int?
    var lastLockDuration: TimeInterval?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Évolution · \(poseName)")
                .font(Theme.captionFont)
                .foregroundStyle(Theme.ivoryMuted)

            if points.isEmpty {
                Text("Pas encore de courbe. Un lock et ça démarre.")
                    .font(Theme.supportFont)
                    .foregroundStyle(Theme.ivoryMuted)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 20)
            } else {
                Chart(points) { point in
                    LineMark(
                        x: .value("Jour", point.day),
                        y: .value("Score", point.score)
                    )
                    .foregroundStyle(Theme.gold)
                    .interpolationMethod(.catmullRom)
                    PointMark(
                        x: .value("Jour", point.day),
                        y: .value("Score", point.score)
                    )
                    .foregroundStyle(Theme.gold)
                }
                .chartYScale(domain: 0...100)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                        AxisGridLine().foregroundStyle(Theme.hairline)
                        AxisValueLabel()
                            .foregroundStyle(Theme.ivoryFaint)
                            .font(Theme.captionFont)
                    }
                }
                .chartYAxis {
                    AxisMarks(values: [0, 50, 100]) { _ in
                        AxisGridLine().foregroundStyle(Theme.hairline)
                        AxisValueLabel()
                            .foregroundStyle(Theme.ivoryFaint)
                            .font(Theme.captionFont)
                    }
                }
                .frame(height: 140)
            }

            if let caption {
                Text(caption)
                    .font(Theme.supportFont)
                    .foregroundStyle(Theme.ivoryMuted)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.elevated)
        .overlay(RoundedRectangle(cornerRadius: Theme.continuousCorner, style: .continuous).stroke(Theme.hairline, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: Theme.continuousCorner, style: .continuous))
    }

    private var caption: String? {
        var parts: [String] = []
        if let average {
            parts.append("moyenne \(average)")
        }
        if let lastLockDuration {
            parts.append(Self.durationLabel(lastLockDuration))
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private static func durationLabel(_ duration: TimeInterval) -> String {
        let seconds = max(0, Int(duration.rounded()))
        if seconds < 60 {
            return "dernier lock en \(seconds) s"
        }
        let minutes = seconds / 60
        let rest = seconds % 60
        return "dernier lock en \(minutes) min \(rest) s"
    }
}
