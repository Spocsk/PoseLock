import Foundation

enum PoseReferenceVariant: String, CaseIterable, Sendable {
    case plain
    case guided
}

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

    // Zyzz — Pro only
    case zyzzClassic
    case zyzzVacuum
    case zyzzTwist

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
        case .zyzzClassic: return "Pose Zyzz"
        case .zyzzVacuum: return "Vacuum face"
        case .zyzzTwist: return "Twist esthétique"
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
        case .zyzzClassic, .zyzzVacuum, .zyzzTwist:
            return .zyzz
        }
    }

    var referenceAssetStem: String {
        switch self {
        case .quarterTurnFace: return "pose_quarterTurnFace"
        case .quarterTurnProfile: return "pose_quarterTurnProfile"
        case .quarterTurnBack: return "pose_quarterTurnBack"
        case .frontDoubleBiceps: return "pose_frontDoubleBiceps"
        case .frontLatSpread: return "pose_frontLatSpread"
        case .sideChest: return "pose_sideChest"
        case .backDoubleBiceps: return "pose_backDoubleBiceps"
        case .backLatSpread: return "pose_backLatSpread"
        case .sideTriceps: return "pose_sideTriceps"
        case .absAndThigh: return "pose_absAndThigh"
        case .mostMuscular: return "pose_mostMuscular"
        case .threeQuarterLat: return "pose_threeQuarterLat"
        case .sideChestMirror: return "pose_sideChestMirror"
        case .mostMuscularCrop: return "pose_mostMuscularCrop"
        case .vacuum: return "pose_vacuum"
        case .backDoubleThreeQuarter: return "pose_backDoubleThreeQuarter"
        case .handsOnHips: return "pose_handsOnHips"
        case .frontPosture: return "pose_frontPosture"
        case .profilePosture: return "pose_profilePosture"
        case .shoulderToWaist: return "pose_shoulderToWaist"
        case .clavicleOpen: return "pose_clavicleOpen"
        case .shoulderSymmetry: return "pose_shoulderSymmetry"
        case .twistThreeQuarter: return "pose_twistThreeQuarter"
        case .zyzzClassic: return "pose_zyzzClassic"
        case .zyzzVacuum: return "pose_zyzzVacuum"
        case .zyzzTwist: return "pose_zyzzTwist"
        }
    }

    func referenceAssetName(for variant: PoseReferenceVariant) -> String {
        "\(referenceAssetStem)_\(variant.rawValue)"
    }

    /// Icône de pack. La pose elle-même utilise une référence low-poly dédiée.
    var symbolName: String {
        switch pack {
        case .scene: return "figure.stand"
        case .content: return "camera.filters"
        case .physique: return "person"
        case .zyzz: return "sparkles"
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
    static let templateVersion = "v2"

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
