import SwiftUI
import UIKit

enum Theme {
    /// Fond quasi noir — référence appareil photo iOS / Fitness+ au repos.
    static let background = Color(red: 0.039, green: 0.039, blue: 0.039)
    static let elevated = Color(red: 0.09, green: 0.09, blue: 0.09)
    static let hairline = Color.white.opacity(0.08)

    /// Or froid — seul accent.
    static let gold = Color(red: 0.769, green: 0.690, blue: 0.545)
    static let goldMuted = Color(red: 0.769, green: 0.690, blue: 0.545).opacity(0.55)

    /// Blanc cassé pour le texte et le skeleton hors tolérance.
    static let ivory = Color(red: 0.91, green: 0.89, blue: 0.86)
    static let ivoryMuted = Color(red: 0.91, green: 0.89, blue: 0.86).opacity(0.55)
    static let ivoryFaint = Color(red: 0.91, green: 0.89, blue: 0.86).opacity(0.28)

    /// Vert lockable — pas de néon salle.
    static let lockGreen = Color(red: 0.55, green: 0.78, blue: 0.58)
    static let frameRed = Color(red: 0.78, green: 0.28, blue: 0.28)

    /// Réservé au splash : le seul gras de l'app.
    static let wordmarkFont: Font = .system(size: 42, weight: .bold).width(.condensed)
    static let scoreFont: Font = .system(size: 64, weight: .light, design: .default)
    static let titleFont: Font = .system(size: 22, weight: .regular, design: .default)
    static let bodyFont: Font = .system(size: 15, weight: .regular, design: .default)
    /// Texte d'appui : sous-titres d'options, arguments, lignes de réassurance.
    /// Le saut direct du corps à la légende était trop brutal pour de la prose.
    static let supportFont: Font = .system(size: 13, weight: .regular, design: .default)
    /// Réservée aux micro-libellés : badges, unités, mentions légales.
    static let captionFont: Font = .system(size: 11, weight: .regular, design: .default)
    static let bubbleNameFont: Font = .system(size: 11, weight: .regular, design: .default)

    static let continuousCorner: CGFloat = 12
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
