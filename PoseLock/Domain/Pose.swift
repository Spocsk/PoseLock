import Foundation

/// Identifiants stables. Ne pas renommer : ils sont persistés dans le journal.
enum PoseID: String, Codable, CaseIterable, Identifiable, Sendable {
    // Scène — Classic Physique
    case quarterTurnFace
    case quarterTurnProfile
    case quarterTurnBack
    case frontDoubleBiceps
    case frontLatSpread
    case sideChest
    case backDoubleBiceps
    case backLatSpread
    case sideTriceps
    case absAndThigh
    case mostMuscular

    // Contenu
    case threeQuarterLat
    case sideChestMirror
    case mostMuscularCrop
    case vacuum
    case backDoubleThreeQuarter
    case handsOnHips

    // Physique
    case frontPosture
    case profilePosture
    case shoulderToWaist
    case clavicleOpen
    case shoulderSymmetry
    case twistThreeQuarter

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .quarterTurnFace: return "Quarter turn face"
        case .quarterTurnProfile: return "Quarter turn profil"
        case .quarterTurnBack: return "Quarter turn dos"
        case .frontDoubleBiceps: return "Front double biceps"
        case .frontLatSpread: return "Front lat spread"
        case .sideChest: return "Side chest"
        case .backDoubleBiceps: return "Back double biceps"
        case .backLatSpread: return "Back lat spread"
        case .sideTriceps: return "Side triceps"
        case .absAndThigh: return "Abs and thigh"
        case .mostMuscular: return "Most muscular"
        case .threeQuarterLat: return "¾ lat"
        case .sideChestMirror: return "Side chest miroir"
        case .mostMuscularCrop: return "Most muscular crop"
        case .vacuum: return "Vacuum"
        case .backDoubleThreeQuarter: return "Back double ¾"
        case .handsOnHips: return "Hands-on-hips"
        case .frontPosture: return "Posture face"
        case .profilePosture: return "Posture profil"
        case .shoulderToWaist: return "Shoulder-to-waist"
        case .clavicleOpen: return "Ouverture cage"
        case .shoulderSymmetry: return "Symétrie épaules"
        case .twistThreeQuarter: return "Twist ¾"
        }
    }

    var pack: Pack {
        switch self {
        case .quarterTurnFace, .quarterTurnProfile, .quarterTurnBack,
             .frontDoubleBiceps, .frontLatSpread, .sideChest,
             .backDoubleBiceps, .backLatSpread, .sideTriceps,
             .absAndThigh, .mostMuscular:
            return .scene
        case .threeQuarterLat, .sideChestMirror, .mostMuscularCrop,
             .vacuum, .backDoubleThreeQuarter, .handsOnHips:
            return .content
        case .frontPosture, .profilePosture, .shoulderToWaist,
             .clavicleOpen, .shoulderSymmetry, .twistThreeQuarter:
            return .physique
        }
    }

    /// SF Symbol placeholder — silhouettes dédiées plus tard.
    var symbolName: String {
        switch pack {
        case .scene: return "figure.stand"
        case .content: return "camera.filters"
        case .physique: return "person"
        }
    }
}

struct PoseDefinition: Identifiable, Sendable, Equatable {
    var id: PoseID { poseID }
    let poseID: PoseID
    let pack: Pack
    let displayName: String
    let symbolName: String
}

enum PoseCatalog {
    static let templateVersion = "v1"

    static let all: [PoseDefinition] = PoseID.allCases.map {
        PoseDefinition(poseID: $0, pack: $0.pack, displayName: $0.displayName, symbolName: $0.symbolName)
    }

    static func poses(for pack: Pack) -> [PoseDefinition] {
        all.filter { $0.pack == pack }
    }

    static func definition(for id: PoseID) -> PoseDefinition {
        PoseDefinition(poseID: id, pack: id.pack, displayName: id.displayName, symbolName: id.symbolName)
    }
}
