import Foundation

enum Pack: String, Codable, CaseIterable, Identifiable, Sendable {
    case scene
    case content
    case physique

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .scene: return "Scène"
        case .content: return "Contenu"
        case .physique: return "Physique"
        }
    }

    var subtitle: String {
        switch self {
        case .scene: return "Mandatories Classic. Une ligne, un juge."
        case .content: return "L’angle, le cadre, la take qui claque."
        case .physique: return "Posture, ouverture, symétrie de pose."
        }
    }

    var defaultPoseID: PoseID {
        switch self {
        case .scene: return .frontDoubleBiceps
        case .content: return .threeQuarterLat
        case .physique: return .frontPosture
        }
    }
}
