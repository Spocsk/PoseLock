import Foundation

enum Pack: String, Codable, CaseIterable, Identifiable, Sendable {
    case scene
    case content
    case physique
    /// Catalogue Pro : jamais proposé à l’onboarding, jamais le pack free.
    case zyzz

    var id: String { rawValue }

    /// Les trois catalogues choisissables à l’onboarding. Zyzz en est exclu.
    static let onboardingCases: [Pack] = [.scene, .content, .physique]

    var displayName: String {
        switch self {
        case .scene: return String(localized: "Scène")
        case .content: return String(localized: "Contenu")
        case .physique: return String(localized: "Physique")
        case .zyzz: return "Zyzz"
        }
    }

    var subtitle: String {
        switch self {
        case .scene: return String(localized: "Mandatories Classic. Une ligne, un juge.")
        case .content: return String(localized: "L’angle, le cadre, la take qui claque.")
        case .physique: return String(localized: "Posture, ouverture, symétrie de pose.")
        case .zyzz: return String(localized: "Vacuum, twist, V-taper. La ligne esthétique.")
        }
    }

    var defaultPoseID: PoseID {
        switch self {
        case .scene: return .frontDoubleBiceps
        case .content: return .threeQuarterLat
        case .physique: return .frontPosture
        case .zyzz: return .zyzzClassic
        }
    }
}

/// Intention déclarée à l'onboarding. Sert à suggérer un pack et à personnaliser le récap.
enum TrainingGoal: String, Codable, CaseIterable, Identifiable, Sendable {
    case competition
    case content
    case shape

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .competition: return String(localized: "Une compèt’")
        case .content: return String(localized: "Du contenu")
        case .shape: return String(localized: "Ma forme")
        }
    }

    var subtitle: String {
        switch self {
        case .competition: return String(localized: "Mandatories, tour de scène, un juge en face.")
        case .content: return String(localized: "L’angle qui rend, la take qui claque.")
        case .shape: return String(localized: "Posture et symétrie, sans échéance.")
        }
    }

    var symbolName: String {
        switch self {
        case .competition: return "trophy"
        case .content: return "camera"
        case .shape: return "figure.stand"
        }
    }

    var suggestedPack: Pack {
        switch self {
        case .competition: return .scene
        case .content: return .content
        case .shape: return .physique
        }
    }

    /// Ce que l'app fait du choix, dit tout de suite après le tap. Un choix sans
    /// accusé de réception donne l'impression d'un formulaire.
    var acknowledgement: String {
        switch self {
        case .competition: return String(localized: "Noté. On part sur les mandatories.")
        case .content: return String(localized: "Noté. On part sur l’angle contenu.")
        case .shape: return String(localized: "Noté. On part sur la posture.")
        }
    }

    /// Le problème reformulé dans les mots de l'objectif. L'onboarding le montre
    /// juste après le choix, avant toute promesse : c'est le moment où l'utilisateur
    /// se reconnaît.
    var painTitle: String {
        switch self {
        case .competition: return String(localized: "Sur scène, personne ne te reprend.")
        case .content: return String(localized: "Tu refais la prise dix fois.")
        case .shape: return String(localized: "Une asymétrie ne se voit pas de l’intérieur.")
        }
    }

    var painDetail: String {
        switch self {
        case .competition:
            return String(localized: "Tu tiens la pose ou tu la perds, et tu ne l’apprends qu’en voyant les photos, une semaine plus tard.")
        case .content:
            return String(localized: "Tu shootes, tu regardes, tu recommences. L’angle qui rendait la semaine dernière, tu ne sais plus lequel c’était.")
        case .shape:
            return String(localized: "Une épaule plus haute, un bassin qui part : ça s’installe pendant des mois avant que quelqu’un te le dise.")
        }
    }

    var painPoints: [String] {
        switch self {
        case .competition:
            return [
                String(localized: "Le miroir inverse ton côté fort."),
                String(localized: "Tenir la pose et se juger en même temps, ça ne marche pas."),
                String(localized: "Les photos arrivent trop tard pour corriger quoi que ce soit.")
            ]
        case .content:
            return [
                String(localized: "Dix takes pour une seule qui passe."),
                String(localized: "Aucune trace de l’angle qui marchait."),
                String(localized: "Tu juges après coup, jamais pendant.")
            ]
        case .shape:
            return [
                String(localized: "Un côté prend le dessus sans prévenir."),
                String(localized: "Le miroir te montre la version que tu corriges déjà."),
                String(localized: "Sans mesure, un mois plus tard tu ne sais pas si ça bouge.")
            ]
        }
    }
}
