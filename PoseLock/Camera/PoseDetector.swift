import AVFoundation
import CoreVideo
import simd
import UIKit
import Vision

/// Une request 3D + une request 2D, réutilisées pour toute la session.
final class PoseDetector: @unchecked Sendable {
    private let request3D = VNDetectHumanBodyPose3DRequest()
    private let request2D = VNDetectHumanBodyPoseRequest()

    func detect(sampleBuffer: CMSampleBuffer, isFront: Bool) -> BodyFrame? {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }
        // Buffers bruts (non miroir). Front = leftMirrored pour coller au preview selfie.
        let orientation: CGImagePropertyOrientation = isFront ? .leftMirrored : .right
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: [:])
        do {
            try handler.perform([request3D, request2D])
        } catch {
            do { try handler.perform([request3D]) } catch { }
            do { try handler.perform([request2D]) } catch { }
        }

        let observation3D = request3D.results?.first
        let observation2D = request2D.results?.first

        var joints3D: [Joint: SIMD3<Float>] = [:]
        var joints2D: [Joint: SIMD2<Float>] = [:]
        var confidences: [Float] = []

        if let observation3D {
            for joint in Joint.allCases {
                for mapped in Self.vision3DNames(joint) {
                    if joints3D[joint] == nil,
                       let point = try? observation3D.recognizedPoint(mapped) {
                        joints3D[joint] = Self.translation(point)
                        confidences.append(1)
                    }
                }
            }
        }

        if let observation2D {
            let all = (try? observation2D.recognizedPoints(.all)) ?? [:]
            for (joint, name) in Self.vision2D {
                if let point = all[name], point.confidence > 0.08 {
                    joints2D[joint] = SIMD2(Float(point.location.x), Float(1 - point.location.y))
                    if joints3D[joint] == nil {
                        joints3D[joint] = SIMD3(Float(point.location.x) - 0.5, Float(point.location.y) - 0.5, 0)
                    }
                    confidences.append(Float(point.confidence))
                }
            }
        }

        if joints2D.isEmpty, let observation3D {
            for joint in Joint.allCases {
                for mapped in Self.vision3DNames(joint) {
                    if joints2D[joint] == nil,
                       let image = try? observation3D.pointInImage(mapped) {
                        joints2D[joint] = SIMD2(Float(image.x), Float(1 - image.y))
                    }
                }
            }
        }

        guard !joints3D.isEmpty || !joints2D.isEmpty else { return nil }

        let normalized = ScoringEngine.normalize(joints: joints3D)
        let confidence = confidences.isEmpty ? 0 : confidences.reduce(0, +) / Float(confidences.count)
        let height = subjectHeight(joints2D)
        let hands = joints2D[.leftWrist] != nil && joints2D[.rightWrist] != nil
        let feet = joints2D[.leftAnkle] != nil && joints2D[.rightAnkle] != nil

        return BodyFrame(
            joints3D: normalized,
            joints2D: joints2D,
            confidence: confidence,
            subjectHeightRatio: height,
            handsVisible: hands,
            feetVisible: feet
        )
    }

    private func subjectHeight(_ points: [Joint: SIMD2<Float>]) -> Float {
        let tops = [points[.head], points[.neck]].compactMap { $0?.y }
        let bottoms = [points[.leftAnkle], points[.rightAnkle]].compactMap { $0?.y }
        guard let minY = tops.min(), let maxY = bottoms.max() else { return 0 }
        return max(0, maxY - minY)
    }

    private static func translation(_ point: VNHumanBodyRecognizedPoint3D) -> SIMD3<Float> {
        let column = point.position.columns.3
        return SIMD3(column.x, column.y, column.z)
    }

    private static func vision3DNames(_ joint: Joint) -> [VNHumanBodyPose3DObservation.JointName] {
        switch joint {
        case .head: return [.topHead, .centerHead]
        case .neck: return [.centerShoulder]
        default:
            if let name = vision3D[joint] { return [name] }
            return []
        }
    }

    private static let vision3D: [Joint: VNHumanBodyPose3DObservation.JointName] = [
        .root: .root,
        .spine: .spine,
        .neck: .centerShoulder,
        .head: .topHead,
        .leftShoulder: .leftShoulder,
        .rightShoulder: .rightShoulder,
        .leftElbow: .leftElbow,
        .rightElbow: .rightElbow,
        .leftWrist: .leftWrist,
        .rightWrist: .rightWrist,
        .leftHip: .leftHip,
        .rightHip: .rightHip,
        .leftKnee: .leftKnee,
        .rightKnee: .rightKnee,
        .leftAnkle: .leftAnkle,
        .rightAnkle: .rightAnkle
    ]

    private static let vision2D: [Joint: VNHumanBodyPoseObservation.JointName] = [
        .root: .root,
        .neck: .neck,
        .head: .nose,
        .leftShoulder: .leftShoulder,
        .rightShoulder: .rightShoulder,
        .leftElbow: .leftElbow,
        .rightElbow: .rightElbow,
        .leftWrist: .leftWrist,
        .rightWrist: .rightWrist,
        .leftHip: .leftHip,
        .rightHip: .rightHip,
        .leftKnee: .leftKnee,
        .rightKnee: .rightKnee,
        .leftAnkle: .leftAnkle,
        .rightAnkle: .rightAnkle
    ]
}
