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
    static let templateVersion = "v1"
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
