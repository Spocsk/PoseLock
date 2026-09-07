import Foundation
import simd

struct FeatureScore: Sendable, Equatable {
    let feature: PoseFeature
    let value: Float?
    let target: Float
    let tolerance: Float
    let weight: Float
    let error: Float
    let inTolerance: Bool
    let cue: String
    let region: SkeletonRegion
}

struct PoseEvaluation: Sendable, Equatable {
    var gate: FrameGate
    var rawScore: Float
    var greenRegions: Set<SkeletonRegion>
    var missingJoints: Set<Joint>
    var worstCue: String
    var features: [FeatureScore]

    static let hidden = PoseEvaluation(
        gate: .outOfFrame,
        rawScore: 0,
        greenRegions: [],
        missingJoints: [],
        worstCue: "",
        features: []
    )

    var showsScore: Bool { gate == .ok || gate == .missingLimbs }
    var isGloballyGreen: Bool { gate == .ok && rawScore >= ScoringConstants.lockScore }
}

enum ScoringEngine {
    static func gate(_ frame: BodyFrame) -> (FrameGate, Set<Joint>) {
        let missing = missingKeyJoints(frame)
        if frame.subjectHeightRatio < ScoringConstants.minSubjectHeight || !frame.feetVisible || !frame.handsVisible {
            return (.outOfFrame, missing)
        }
        if frame.confidence < ScoringConstants.minConfidence {
            return (.lowConfidence, missing)
        }
        if !missing.isEmpty {
            return (.missingLimbs, missing)
        }
        return (.ok, [])
    }

    static func evaluate(frame: BodyFrame, template: PoseTemplate) -> PoseEvaluation {
        let (gate, missing) = gate(frame)
        guard gate == .ok || gate == .missingLimbs else {
            var ev = PoseEvaluation.hidden
            ev.gate = gate
            ev.missingJoints = missing
            return ev
        }

        var featureScores: [FeatureScore] = []
        var weightedSum: Float = 0
        var weightTotal: Float = 0
        var green: Set<SkeletonRegion> = []
        var worstWeightError: Float = -1
        var worstCue = "Tiens la ligne."

        for target in template.features {
            let value = extract(target.feature, from: frame)
            let error: Float
            let inTol: Bool
            if let value {
                error = abs(value - target.target)
                inTol = error <= target.tolerance
            } else {
                error = target.tolerance * 2
                inTol = false
            }
            if inTol { green.insert(target.region) }
            let normalized = error / max(target.tolerance, 0.001)
            weightedSum += target.weight * normalized * normalized
            weightTotal += target.weight
            let lever = target.weight * normalized
            if lever > worstWeightError {
                worstWeightError = lever
                worstCue = target.cue
            }
            featureScores.append(
                FeatureScore(
                    feature: target.feature,
                    value: value,
                    target: target.target,
                    tolerance: target.tolerance,
                    weight: target.weight,
                    error: error,
                    inTolerance: inTol,
                    cue: target.cue,
                    region: target.region
                )
            )
        }

        let mse = weightTotal > 0 ? weightedSum / weightTotal : 1
        let raw = max(0, min(100, 100 * exp(-ScoringConstants.scoreDecay * mse)))
        let effectiveGate: FrameGate = (gate == .missingLimbs) ? .missingLimbs : .ok

        return PoseEvaluation(
            gate: effectiveGate,
            rawScore: raw,
            greenRegions: green,
            missingJoints: missing,
            worstCue: worstCue,
            features: featureScores
        )
    }

    /// Lissage anti-jitter, EMA sur ~10 frames.
    static func smooth(previous: Float?, new raw: Float, frames: Int = ScoringConstants.emaFrames) -> Float {
        guard let previous else { return raw }
        let alpha = 2 / Float(frames + 1)
        return previous * (1 - alpha) + raw * alpha
    }

    static func normalize(joints: [Joint: SIMD3<Float>]) -> [Joint: SIMD3<Float>] {
        guard let origin = joints[.root] ?? midpoint(joints[.leftHip], joints[.rightHip]) else {
            return joints
        }
        var out: [Joint: SIMD3<Float>] = [:]
        for (joint, p) in joints {
            out[joint] = p - origin
        }
        let scale = scaleFactor(out)
        guard scale > 0.001 else { return out }
        for (joint, p) in out {
            out[joint] = p / scale
        }
        return out
    }

    static func angleDegrees(_ a: SIMD3<Float>, _ b: SIMD3<Float>, _ c: SIMD3<Float>) -> Float {
        let ba = simd_normalize(a - b)
        let bc = simd_normalize(c - b)
        let dot = simd_clamp(simd_dot(ba, bc), -1, 1)
        return acos(dot) * 180 / .pi
    }

    // MARK: - Features

    static func extract(_ feature: PoseFeature, from frame: BodyFrame) -> Float? {
        let j = frame.joints3D
        switch feature {
        case .leftElbow:
            return triple(j, .leftShoulder, .leftElbow, .leftWrist)
        case .rightElbow:
            return triple(j, .rightShoulder, .rightElbow, .rightWrist)
        case .leftKnee:
            return triple(j, .leftHip, .leftKnee, .leftAnkle)
        case .rightKnee:
            return triple(j, .rightHip, .rightKnee, .rightAnkle)
        case .leftShoulderAbduction:
            return triple(j, .leftHip, .leftShoulder, .leftElbow)
                ?? triple(j, .root, .leftShoulder, .leftElbow)
        case .rightShoulderAbduction:
            return triple(j, .rightHip, .rightShoulder, .rightElbow)
                ?? triple(j, .root, .rightShoulder, .rightElbow)
        case .torsoTwist:
            return lineYawDelta(j, hipA: .leftHip, hipB: .rightHip, shA: .leftShoulder, shB: .rightShoulder)
        case .shoulderLevel:
            return levelDelta(j, .leftShoulder, .rightShoulder)
        case .hipLevel:
            return levelDelta(j, .leftHip, .rightHip)
        case .spineInclination:
            return inclinationFromVertical(j, .root, .neck) ?? inclinationFromVertical(j, .root, .head)
        case .vTaper:
            return vTaper(j)
        case .stanceWidth:
            return distanceXZ(j, .leftAnkle, .rightAnkle)
        case .leftWristHeight:
            return relativeHeight(j, upper: .leftWrist, lower: .leftShoulder)
        case .rightWristHeight:
            return relativeHeight(j, upper: .rightWrist, lower: .rightShoulder)
        case .chestOpen:
            return distanceXZ(j, .leftShoulder, .rightShoulder)
                ?? distanceXZ(j, .leftElbow, .rightElbow)
        case .headAlignment:
            // 0 = tête empilée sur le cou (axe vertical), pas un pair gauche/droite.
            return inclinationFromVertical(j, .neck, .head)
                ?? inclinationFromVertical(j, .root, .head)
        }
    }

    // MARK: - Private

    private static func missingKeyJoints(_ frame: BodyFrame) -> Set<Joint> {
        let required: [Joint] = [
            .leftWrist, .rightWrist, .leftAnkle, .rightAnkle,
            .leftShoulder, .rightShoulder, .leftHip, .rightHip
        ]
        return Set(required.filter { !frame.has($0) })
    }

    private static func triple(
        _ j: [Joint: SIMD3<Float>],
        _ a: Joint, _ b: Joint, _ c: Joint
    ) -> Float? {
        guard let pa = j[a], let pb = j[b], let pc = j[c] else { return nil }
        return angleDegrees(pa, pb, pc)
    }

    private static func midpoint(_ a: SIMD3<Float>?, _ b: SIMD3<Float>?) -> SIMD3<Float>? {
        guard let a, let b else { return a ?? b }
        return (a + b) / 2
    }

    private static func scaleFactor(_ joints: [Joint: SIMD3<Float>]) -> Float {
        if let hips = midpoint(joints[.leftHip], joints[.rightHip]) ?? joints[.root],
           let head = joints[.head] ?? joints[.neck] {
            let hipHead = simd_length(head - hips)
            if hipHead > 0.001 { return hipHead }
        }
        if let ls = joints[.leftShoulder], let rs = joints[.rightShoulder] {
            let span = simd_length(ls - rs)
            if span > 0.001 { return span }
        }
        return 1
    }

    private static func levelDelta(_ j: [Joint: SIMD3<Float>], _ a: Joint, _ b: Joint) -> Float? {
        guard let pa = j[a], let pb = j[b] else { return nil }
        let dy = abs(pa.y - pb.y)
        let dist = max(simd_length(pa - pb), 0.001)
        return (dy / dist) * 90
    }

    private static func inclinationFromVertical(_ j: [Joint: SIMD3<Float>], _ a: Joint, _ b: Joint) -> Float? {
        guard let pa = j[a], let pb = j[b] else { return nil }
        let v = simd_normalize(pb - pa)
        let vertical = SIMD3<Float>(0, 1, 0)
        let dot = simd_clamp(simd_dot(v, vertical), -1, 1)
        return acos(dot) * 180 / .pi
    }

    private static func lineYawDelta(
        _ j: [Joint: SIMD3<Float>],
        hipA: Joint, hipB: Joint, shA: Joint, shB: Joint
    ) -> Float? {
        guard let ha = j[hipA], let hb = j[hipB], let sa = j[shA], let sb = j[shB] else { return nil }
        let hip = simd_normalize(SIMD3<Float>(hb.x - ha.x, 0, hb.z - ha.z))
        let sh = simd_normalize(SIMD3<Float>(sb.x - sa.x, 0, sb.z - sa.z))
        guard simd_length(hip) > 0.001, simd_length(sh) > 0.001 else { return nil }
        let cross = hip.x * sh.z - hip.z * sh.x
        let dot = simd_clamp(simd_dot(hip, sh), -1, 1)
        return abs(atan2(cross, dot)) * 180 / .pi
    }

    private static func vTaper(_ j: [Joint: SIMD3<Float>]) -> Float? {
        guard let sw = distanceXZ(j, .leftShoulder, .rightShoulder),
              let hw = distanceXZ(j, .leftHip, .rightHip),
              hw > 0.05 else { return nil }
        return sw / hw
    }

    private static func distanceXZ(_ j: [Joint: SIMD3<Float>], _ a: Joint, _ b: Joint) -> Float? {
        guard let pa = j[a], let pb = j[b] else { return nil }
        let dx = pa.x - pb.x
        let dz = pa.z - pb.z
        return sqrt(dx * dx + dz * dz)
    }

    private static func relativeHeight(_ j: [Joint: SIMD3<Float>], upper: Joint, lower: Joint) -> Float? {
        guard let u = j[upper], let l = j[lower] else { return nil }
        return u.y - l.y
    }
}

final class ScoreSmoother: @unchecked Sendable {
    private let lock = NSLock()
    private var current: Float?

    func reset() {
        lock.lock()
        current = nil
        lock.unlock()
    }

    func push(_ raw: Float) -> Float {
        lock.lock()
        defer { lock.unlock() }
        let next = ScoringEngine.smooth(previous: current, new: raw)
        current = next
        return next
    }
}
