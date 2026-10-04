import SwiftUI
import UIKit

enum Theme {
    /// Fond quasi noir — référence appareil photo iOS / Fitness+ au repos.
    static let background = Color(red: 0.039, green: 0.039, blue: 0.039)
    static let elevated = Color(red: 0.09, green: 0.09, blue: 0.09)
    static let hairline = Color.white.opacity(0.12)

    /// Or froid — seul accent.
    static let gold = Color(red: 0.769, green: 0.690, blue: 0.545)
    static let goldMuted = Color(red: 0.769, green: 0.690, blue: 0.545).opacity(0.76)

    /// Blanc cassé pour le texte et le skeleton hors tolérance.
    static let ivory = Color(red: 0.91, green: 0.89, blue: 0.86)
    static let ivoryMuted = Color(red: 0.91, green: 0.89, blue: 0.86).opacity(0.76)
    static let ivoryFaint = Color(red: 0.91, green: 0.89, blue: 0.86).opacity(0.60)

    /// Vert lockable — pas de néon salle.
    static let lockGreen = Color(red: 0.55, green: 0.78, blue: 0.58)
    static let frameRed = Color(red: 0.78, green: 0.28, blue: 0.28)

    // Styles système : San Francisco et Dynamic Type, sans nom de police privé.
    // 22 / 15 / 13 / 11 points à la taille standard.
    static let wordmarkFont: Font = .system(.largeTitle, design: .default, weight: .bold)
    static let scoreFont: Font = .system(size: 64, weight: .light)
    /// Cue live, lu à 2–3 m — exception comme `scoreFont`, pas une 5e marche d’échelle.
    static let distanceCueFont: Font = .system(size: 28, weight: .semibold)
    static let metricFont: Font = .system(.title, design: .default, weight: .light)
    static let titleFont: Font = .system(.title2)
    static let bodyFont: Font = .system(.subheadline)
    static let supportFont: Font = .system(.footnote)
    static let captionFont: Font = .system(.caption2)
    static let bubbleNameFont = supportFont
    static let iconFont: Font = .system(.subheadline, design: .default, weight: .medium)
    static let emblemFont: Font = .system(.largeTitle, design: .default, weight: .light)
    static let buttonFont: Font = .system(.subheadline, design: .default, weight: .medium)

    static let pageInset: CGFloat = 24
    static let minimumTarget: CGFloat = 44
    static let continuousCorner: CGFloat = 16
    static let skeletonLine: CGFloat = 5
    static let skeletonLineLocked: CGFloat = 8
    static let skeletonJoint: CGFloat = 8
}

enum PoseLockHaptics {
    static func lockClick(enabled: Bool) {
        guard enabled else { return }
        let generator = UIImpactFeedbackGenerator(style: .rigid)
        generator.prepare()
        generator.impactOccurred(intensity: 0.85)
    }

    static func selection(enabled: Bool) {
        guard enabled else { return }
        UISelectionFeedbackGenerator().selectionChanged()
    }
}
