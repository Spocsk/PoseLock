import AVFoundation
import CoreImage
import SwiftUI
import UIKit

@MainActor
@Observable
final class CameraViewModel {
    let capture = CaptureSessionController()
    var evaluation = PoseEvaluation.hidden
    var smoothedScore: Float = 0
    var bodyFrame = BodyFrame.empty
    var isFront = false
    var didLock = false
    var flashOpacity: Double = 0
    var cameraDenied = false
    var lastClean: UIImage?
    var lastOverlay: UIImage?
    var lastScore: Float = 0
    var durationToLock: TimeInterval = 0
    var poseID: PoseID = Pack.scene.defaultPoseID

    private let detector = PoseDetector()
    private let smoother = ScoreSmoother()
    private var holdStart: Date?
    private var latestPixelBuffer: CVPixelBuffer?
    private var sessionStartedAt = Date()
    private var locking = false

    func start(front: Bool) {
        isFront = front
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            cameraDenied = false
            beginSession(front: front)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                Task { @MainActor in
                    self?.cameraDenied = !granted
                    if granted { self?.beginSession(front: front) }
                }
            }
        default:
            cameraDenied = true
        }
    }

    func stop() {
        capture.onFrame = nil
        capture.stop()
        if let old = latestPixelBuffer {
            CVPixelBufferRelease(old)
            latestPixelBuffer = nil
        }
    }

    func flip() {
        capture.flip()
        isFront = capture.isFront
        smoother.reset()
        holdStart = nil
        attachFrameHandler()
    }

    func requestPermissionAgain() {
        start(front: isFront)
    }

    func resetAfterLock() {
        didLock = false
        lastClean = nil
        lastOverlay = nil
        locking = false
        holdStart = nil
        smoother.reset()
        sessionStartedAt = Date()
    }

    func notePoseChange(_ poseID: PoseID) {
        self.poseID = poseID
        smoother.reset()
        holdStart = nil
    }

    private func beginSession(front: Bool) {
        sessionStartedAt = Date()
        capture.configure(front: front)
        isFront = capture.isFront
        attachFrameHandler()
        capture.start()
    }

    private func attachFrameHandler() {
        let detector = detector
        capture.onFrame = { [weak self] buffer in
            guard let pixel = CMSampleBufferGetImageBuffer(buffer) else { return }
            CVPixelBufferRetain(pixel)
            let front = self?.capture.isFront ?? false
            let frame = detector.detect(sampleBuffer: buffer, isFront: front)
            Task { @MainActor in
                guard let self else {
                    CVPixelBufferRelease(pixel)
                    return
                }
                if let old = self.latestPixelBuffer {
                    CVPixelBufferRelease(old)
                }
                self.latestPixelBuffer = pixel
                self.apply(frame)
            }
        }
    }

    private func apply(_ frame: BodyFrame?) {
        guard !didLock, !locking else { return }
        guard let frame else {
            evaluation = .hidden
            holdStart = nil
            return
        }
        bodyFrame = frame
        let template = TemplateLibrary.template(for: poseID)
        var result = ScoringEngine.evaluate(frame: frame, template: template)
        if result.gate == .ok || result.gate == .missingLimbs {
            smoothedScore = smoother.push(result.rawScore)
            result.rawScore = smoothedScore
        } else {
            smoother.reset()
            smoothedScore = 0
        }
        evaluation = result

        let lockable = result.isGloballyGreen && frame.handsVisible && frame.feetVisible
        if lockable {
            if holdStart == nil { holdStart = Date() }
            if let start = holdStart, Date().timeIntervalSince(start) >= ScoringConstants.lockHoldSeconds {
                Task { await lockNow() }
            }
        } else {
            holdStart = nil
        }
    }

    private func lockNow() async {
        guard !locking, !didLock else { return }
        locking = true
        durationToLock = Date().timeIntervalSince(sessionStartedAt)
        lastScore = smoothedScore
        let image = latestPixelBuffer.flatMap { FrameImage.uiImage(pixelBuffer: $0, isFront: isFront) }
        lastClean = image
        if let image {
            lastOverlay = SkeletonRenderer.overlayImage(
                base: image,
                frame: bodyFrame,
                evaluation: evaluation
            )
        }
        withAnimation(.easeOut(duration: 0.12)) { flashOpacity = 0.35 }
        try? await Task.sleep(for: .milliseconds(120))
        withAnimation(.easeOut(duration: 0.25)) { flashOpacity = 0 }
        didLock = true
        locking = false
    }
}

enum FrameImage {
    static func uiImage(pixelBuffer: CVPixelBuffer, isFront: Bool) -> UIImage? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let oriented = ciImage.oriented(isFront ? .leftMirrored : .right)
        let context = CIContext(options: [.useSoftwareRenderer: false])
        guard let cg = context.createCGImage(oriented, from: oriented.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}

enum SkeletonRenderer {
    static func overlayImage(base: UIImage, frame: BodyFrame, evaluation: PoseEvaluation) -> UIImage {
        let size = base.size
        let format = UIGraphicsImageRendererFormat()
        format.scale = base.scale
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { ctx in
            base.draw(in: CGRect(origin: .zero, size: size))
            let cg = ctx.cgContext
            cg.setLineCap(.round)
            cg.setLineJoin(.round)
            for bone in Bone.all {
                guard let a = frame.imagePoint(bone.from), let b = frame.imagePoint(bone.to) else { continue }
                if evaluation.missingJoints.contains(bone.from) || evaluation.missingJoints.contains(bone.to) {
                    continue
                }
                let green = evaluation.isGloballyGreen || region(for: bone).map { evaluation.greenRegions.contains($0) } == true
                let color = (green ? UIColor(Theme.lockGreen) : UIColor(Theme.ivory).withAlphaComponent(0.45))
                cg.setStrokeColor(color.cgColor)
                cg.setLineWidth(green ? 3.2 : 2.0)
                cg.move(to: CGPoint(x: CGFloat(a.x) * size.width, y: CGFloat(a.y) * size.height))
                cg.addLine(to: CGPoint(x: CGFloat(b.x) * size.width, y: CGFloat(b.y) * size.height))
                cg.strokePath()
            }
        }
    }

    static func region(for bone: Bone) -> SkeletonRegion? {
        SkeletonRegion.allCases.first { $0.bones.contains(bone) }
    }
}
