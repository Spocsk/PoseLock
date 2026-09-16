import Foundation
import simd

enum Joint: String, CaseIterable, Codable, Sendable {
    case root
    case spine
    case neck
    case head
    case leftShoulder
    case rightShoulder
    case leftElbow
    case rightElbow
    case leftWrist
    case rightWrist
    case leftHip
    case rightHip
    case leftKnee
    case rightKnee
    case leftAnkle
    case rightAnkle
}

/// Paire de joints = un segment rigide du skeleton.
struct Bone: Hashable, Sendable {
    let from: Joint
    let to: Joint

    static let all: [Bone] = [
        Bone(from: .leftHip, to: .rightHip),
        Bone(from: .leftHip, to: .root),
        Bone(from: .rightHip, to: .root),
        Bone(from: .root, to: .spine),
        Bone(from: .spine, to: .neck),
        Bone(from: .neck, to: .head),
        Bone(from: .leftShoulder, to: .rightShoulder),
        Bone(from: .spine, to: .leftShoulder),
        Bone(from: .spine, to: .rightShoulder),
        Bone(from: .leftShoulder, to: .leftElbow),
        Bone(from: .leftElbow, to: .leftWrist),
        Bone(from: .rightShoulder, to: .rightElbow),
        Bone(from: .rightElbow, to: .rightWrist),
        Bone(from: .leftHip, to: .leftKnee),
        Bone(from: .leftKnee, to: .leftAnkle),
        Bone(from: .rightHip, to: .rightKnee),
        Bone(from: .rightKnee, to: .rightAnkle)
    ]
}

/// Une observation normalisée, indépendante de Vision — testable sans device.
struct BodyFrame: Sendable, Equatable {
    /// Positions 3D, origine bassin, échelle hanches–tête ≈ 1.
    var joints3D: [Joint: SIMD3<Float>]
    /// Projection image, origine haut-gauche, 0…1.
    var joints2D: [Joint: SIMD2<Float>]
    var confidence: Float
    /// Hauteur du sujet dans l’image (cheville→tête), 0…1.
    var subjectHeightRatio: Float
    var handsVisible: Bool
    var feetVisible: Bool

    static let empty = BodyFrame(
        joints3D: [:],
        joints2D: [:],
        confidence: 0,
        subjectHeightRatio: 0,
        handsVisible: false,
        feetVisible: false
    )

    func has(_ joint: Joint) -> Bool {
        joints3D[joint] != nil || joints2D[joint] != nil
    }

    func position(_ joint: Joint) -> SIMD3<Float>? {
        joints3D[joint]
    }

    func imagePoint(_ joint: Joint) -> SIMD2<Float>? {
        joints2D[joint]
    }

    /// Silhouette face, bras le long du corps — preview coaching et tests.
    static func standingPreview() -> BodyFrame {
        let joints: [Joint: SIMD3<Float>] = [
            .root: SIMD3(0, 0, 0),
            .spine: SIMD3(0, 0.4, 0),
            .neck: SIMD3(0, 0.75, 0),
            .head: SIMD3(0, 1.0, 0),
            .leftShoulder: SIMD3(-0.22, 0.72, 0),
            .rightShoulder: SIMD3(0.22, 0.72, 0),
            .leftElbow: SIMD3(-0.24, 0.4, 0),
            .rightElbow: SIMD3(0.24, 0.4, 0),
            .leftWrist: SIMD3(-0.25, 0.08, 0),
            .rightWrist: SIMD3(0.25, 0.08, 0),
            .leftHip: SIMD3(-0.12, 0, 0),
            .rightHip: SIMD3(0.12, 0, 0),
            .leftKnee: SIMD3(-0.12, -0.45, 0),
            .rightKnee: SIMD3(0.12, -0.45, 0),
            .leftAnkle: SIMD3(-0.12, -0.9, 0),
            .rightAnkle: SIMD3(0.12, -0.9, 0)
        ]
        let normalized = ScoringEngine.normalize(joints: joints)
        var joints2D: [Joint: SIMD2<Float>] = [:]
        for (joint, p) in normalized {
            joints2D[joint] = SIMD2(p.x * 0.25 + 0.5, 0.15 + (1 - (p.y + 1) / 2) * 0.7)
        }
        return BodyFrame(
            joints3D: normalized,
            joints2D: joints2D,
            confidence: 0.9,
            subjectHeightRatio: 0.7,
            handsVisible: true,
            feetVisible: true
        )
    }
}

/// Skeleton d’une prise, persisté dans le journal. Tableau explicite plutôt
/// qu’un dictionnaire à clé enum, qui s’encoderait en liste alternée clé / valeur.
struct SkeletonSnapshot: Codable, Sendable, Equatable {
    struct JointPosition: Codable, Sendable, Equatable {
        let joint: Joint
        /// 3D normalisé, bassin à l’origine, échelle hanches–tête ≈ 1.
        let x: Float
        let y: Float
        let z: Float
        /// Projection image, 0…1.
        let u: Float
        let v: Float
    }

    var joints: [JointPosition]
    var greenRegions: [SkeletonRegion]
    var confidence: Float

    init(joints: [JointPosition], greenRegions: [SkeletonRegion], confidence: Float) {
        self.joints = joints
        self.greenRegions = greenRegions
        self.confidence = confidence
    }

    init(frame: BodyFrame, evaluation: PoseEvaluation) {
        let names = Set(frame.joints3D.keys).union(frame.joints2D.keys)
        joints = names.sorted { $0.rawValue < $1.rawValue }.map { joint in
            let p = frame.joints3D[joint] ?? .zero
            let image = frame.joints2D[joint] ?? SIMD2<Float>(0.5, 0.5)
            return JointPosition(joint: joint, x: p.x, y: p.y, z: p.z, u: image.x, v: image.y)
        }
        greenRegions = evaluation.greenRegions.sorted { $0.rawValue < $1.rawValue }
        confidence = frame.confidence
    }

    var joints3D: [Joint: SIMD3<Float>] {
        Dictionary(uniqueKeysWithValues: joints.map { ($0.joint, SIMD3($0.x, $0.y, $0.z)) })
    }

    var joints2D: [Joint: SIMD2<Float>] {
        Dictionary(uniqueKeysWithValues: joints.map { ($0.joint, SIMD2($0.u, $0.v)) })
    }
}

enum FrameGate: Equatable, Sendable {
    case ok
    case outOfFrame
    case lowConfidence
    case missingLimbs
}

enum ScoringConstants {
    static let lockScore: Float = 85
    static let lockHoldSeconds: TimeInterval = 1.5
    static let emaFrames: Int = 10
    static let minSubjectHeight: Float = 0.33
    static let minConfidence: Float = 0.35
    static let freeLocksPerDay = 3
    static let templateVersion = "v2"
    /// `score = 100 * exp(-k * weightedMSE)`
    static let scoreDecay: Float = 0.65
}

enum PoseFeature: String, CaseIterable, Codable, Sendable {
    case leftElbow
    case rightElbow
    case leftKnee
    case rightKnee
    case leftShoulderAbduction
    case rightShoulderAbduction
    /// Orientation globale face / profil / dos par rapport à la caméra.
    case bodyYaw
    /// Rotation des épaules par rapport au bassin.
    case torsoTwist
    case shoulderLevel
    case hipLevel
    case spineInclination
    case vTaper
    case stanceWidth
    case leftWristHeight
    case rightWristHeight
    case chestOpen
    case headAlignment
}

enum SkeletonRegion: String, Codable, Sendable, CaseIterable {
    case leftArm
    case rightArm
    case leftLeg
    case rightLeg
    case torso
    case shoulders
    case hips
    case head

    var bones: [Bone] {
        switch self {
        case .leftArm:
            return [Bone(from: .leftShoulder, to: .leftElbow), Bone(from: .leftElbow, to: .leftWrist)]
        case .rightArm:
            return [Bone(from: .rightShoulder, to: .rightElbow), Bone(from: .rightElbow, to: .rightWrist)]
        case .leftLeg:
            return [Bone(from: .leftHip, to: .leftKnee), Bone(from: .leftKnee, to: .leftAnkle)]
        case .rightLeg:
            return [Bone(from: .rightHip, to: .rightKnee), Bone(from: .rightKnee, to: .rightAnkle)]
        case .torso:
            return [Bone(from: .root, to: .spine), Bone(from: .spine, to: .neck), Bone(from: .leftHip, to: .rightHip)]
        case .shoulders:
            return [Bone(from: .leftShoulder, to: .rightShoulder), Bone(from: .spine, to: .leftShoulder), Bone(from: .spine, to: .rightShoulder)]
        case .hips:
            return [Bone(from: .leftHip, to: .rightHip), Bone(from: .leftHip, to: .root), Bone(from: .rightHip, to: .root)]
        case .head:
            return [Bone(from: .neck, to: .head)]
        }
    }
}
