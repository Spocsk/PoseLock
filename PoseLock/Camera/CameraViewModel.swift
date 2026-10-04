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
    var lastSkeleton: SkeletonSnapshot?
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
        latestPixelBuffer = nil
    }

    func setCamera(front: Bool) {
        guard front != isFront else { return }
        smoother.reset()
        holdStart = nil
        evaluation = .hidden
        capture.setCamera(front: front) { [weak self] nowFront in
            guard let self else { return }
            self.isFront = nowFront
            self.attachFrameHandler()
        }
    }

    func requestPermissionAgain() {
        start(front: isFront)
    }

    func resetAfterLock() {
        didLock = false
        lastClean = nil
        lastOverlay = nil
        lastSkeleton = nil
        locking = false
        holdStart = nil
        smoother.reset()
        sessionStartedAt = Date()
        // Sinon le squelette du lock reste dessiné sur le flux jusqu'à la
        // prochaine détection.
        bodyFrame = .empty
        evaluation = .hidden
        #if DEBUG
        lastLockWasForced = false
        #endif
    }

    func notePoseChange(_ poseID: PoseID) {
        self.poseID = poseID
        smoother.reset()
        holdStart = nil
    }

    private func beginSession(front: Bool) {
        sessionStartedAt = Date()
        attachFrameHandler()
        capture.start(front: front) { [weak self] nowFront in
            self?.isFront = nowFront
        }
    }

    private func attachFrameHandler() {
        let detector = detector
        capture.onFrame = { [weak self] buffer, front in
            guard CMSampleBufferGetImageBuffer(buffer) != nil else { return }
            let frame = detector.detect(sampleBuffer: buffer, isFront: front)
            Task { @MainActor in
                guard let self else { return }
                if let pixel = CMSampleBufferGetImageBuffer(buffer) {
                    self.latestPixelBuffer = pixel
                }
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

    /// `standIn` ne sert qu'au lock forcé de debug, quand il n'y a pas de flux
    /// caméra à photographier. Nil en production, donc comportement inchangé.
    private func lockNow(standIn: UIImage? = nil, preferStandIn: Bool = false) async {
        guard !locking, !didLock else { return }
        locking = true
        durationToLock = Date().timeIntervalSince(sessionStartedAt)
        lastScore = smoothedScore
        lastSkeleton = SkeletonSnapshot(frame: bodyFrame, evaluation: evaluation)
        let captured = latestPixelBuffer.flatMap { FrameImage.uiImage(pixelBuffer: $0, isFront: isFront) }
        let image = preferStandIn ? (standIn ?? captured) : (captured ?? standIn)
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

    #if DEBUG
    /// Aperçu démo des captures marketing (`ScreenBank.usesDemoCamera`) : la
    /// photo remplace le flux caméra. Nil pour un run DEBUG ordinaire.
    var demoPreviewImage: UIImage?
    /// Le dernier lock vient du bouton dev : la carte montre alors la photo avec
    /// son squelette, puisqu'il n'y a rien eu à voir en direct.
    var lastLockWasForced = false

    /// Aperçu hors caméra : la photo démo + le skeleton détecté dessus.
    func startDemoPreview(poseID: PoseID, front: Bool) {
        self.poseID = poseID
        isFront = front
        guard let image = DebugDemoPose.image else {
            demoPreviewImage = nil
            return
        }
        demoPreviewImage = image
        applyForcedDemo(on: image)
    }

    /// Le sélecteur avant/arrière reste testable en démo sans démarrer une
    /// `AVCaptureSession`. L'aperçu SwiftUI applique lui-même le miroir selfie.
    func setDemoCamera(front: Bool) {
        isFront = front
        capture.onFrame = nil
        capture.stop()
        latestPixelBuffer = nil
    }

    /// Lock forcé, réservé au debug : traverse lock → journal dans le simulateur,
    /// qui n'a ni caméra ni pose à tenir.
    ///
    /// Le score est estampillé, pas mesuré. La photo démo (`DebugDemoPose`) est un
    /// front double biceps : elle ne sert que pour cette pose (ou en aperçu démo),
    /// sinon le journal rangerait un double biceps sous « back lat spread ». Les
    /// autres poses gardent la silhouette cible sur fond uni. Compilé hors
    /// release, jamais dans un build distribué.
    func debugForceLock() async {
        guard !locking, !didLock else { return }
        let usesPhoto = demoPreviewImage != nil || poseID == DebugDemoPose.poseID
        let photo = usesPhoto ? DebugDemoPose.image : nil
        if let photo {
            applyForcedDemo(on: photo)
        } else {
            applyForced(frame: BodyFrame.preview(for: poseID))
        }
        lastLockWasForced = true
        await lockNow(standIn: photo ?? Self.debugBackdrop(), preferStandIn: true)
    }

    private func applyForcedDemo(on image: UIImage?) {
        if let image,
           let detected = PoseDetector().detect(image: image, isFront: false),
           detected.handsVisible,
           detected.feetVisible {
            applyForced(frame: detected)
        } else {
            applyForced(frame: DebugDemoPose.fallbackFrame)
        }
    }

    private func applyForced(frame: BodyFrame) {
        var forced = ScoringEngine.evaluate(frame: frame, template: TemplateLibrary.template(for: poseID))
        forced.gate = .ok
        forced.rawScore = DebugDemoPose.stampedScore
        forced.greenRegions = Set(SkeletonRegion.allCases)
        forced.missingJoints = []
        forced.worstCue = "Tiens la ligne."
        smoother.reset()
        smoothedScore = forced.rawScore
        bodyFrame = frame
        evaluation = forced
    }

    /// Sans image, `persistLock` abandonne et rien n'atteint le journal. Ce fond
    /// uni reste le repli si `DebugDemoPose` est absent du bundle.
    private static func debugBackdrop() -> UIImage {
        let size = CGSize(width: 1080, height: 1440)
        return UIGraphicsImageRenderer(size: size).image { context in
            UIColor(Theme.background).setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
    #endif
}

#if DEBUG
enum DebugDemoPose {
    static let imageName = "DebugDemoPose"
    /// La pose tenue sur la photo.
    static let poseID: PoseID = .frontDoubleBiceps
    /// 85 + 8 : le score de la prise de démonstration, aligné sur la carte partagée.
    static let stampedScore: Float = ScoringConstants.lockScore + 8
    static var image: UIImage? { UIImage(named: imageName) }

    /// Projection extraite une fois de la photo avec Vision 2D. Le runtime du
    /// Simulator ne livre pas toujours les poids Vision, donc ces coordonnées
    /// gardent le skeleton collé à la vraie silhouette plutôt que de revenir à
    /// la silhouette théorique du template.
    static var fallbackFrame: BodyFrame {
        var frame = BodyFrame.preview(for: .frontDoubleBiceps)
        frame.joints2D = [
            .root: SIMD2(0.489329, 0.519682),
            .spine: SIMD2(0.485464, 0.430315),
            .neck: SIMD2(0.481598, 0.340947),
            .head: SIMD2(0.481598, 0.257000),
            .leftShoulder: SIMD2(0.572467, 0.341084),
            .rightShoulder: SIMD2(0.390729, 0.340809),
            .leftElbow: SIMD2(0.732034, 0.365971),
            .rightElbow: SIMD2(0.233554, 0.360948),
            .leftWrist: SIMD2(0.711672, 0.291230),
            .rightWrist: SIMD2(0.259118, 0.287844),
            .leftHip: SIMD2(0.560411, 0.519650),
            .rightHip: SIMD2(0.418246, 0.519715),
            .leftKnee: SIMD2(0.590312, 0.675409),
            .rightKnee: SIMD2(0.395140, 0.658670),
            .leftAnkle: SIMD2(0.620747, 0.811348),
            .rightAnkle: SIMD2(0.351612, 0.794403)
        ]
        frame.confidence = 0.65
        frame.subjectHeightRatio = 0.554
        frame.handsVisible = true
        frame.feetVisible = true
        return frame
    }
}
#endif

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
            var joints: Set<Joint> = []
            for bone in Bone.all {
                guard let a = frame.imagePoint(bone.from), let b = frame.imagePoint(bone.to) else { continue }
                if evaluation.missingJoints.contains(bone.from) || evaluation.missingJoints.contains(bone.to) {
                    continue
                }
                let green = evaluation.isGloballyGreen || region(for: bone).map { evaluation.greenRegions.contains($0) } == true
                let color = (green ? UIColor(Theme.lockGreen) : UIColor(Theme.ivory).withAlphaComponent(0.45))
                cg.setStrokeColor(color.cgColor)
                cg.setLineWidth(green ? Theme.skeletonLineLocked : Theme.skeletonLine)
                cg.move(to: CGPoint(x: CGFloat(a.x) * size.width, y: CGFloat(a.y) * size.height))
                cg.addLine(to: CGPoint(x: CGFloat(b.x) * size.width, y: CGFloat(b.y) * size.height))
                cg.strokePath()
                joints.insert(bone.from)
                joints.insert(bone.to)
            }
            cg.setFillColor(UIColor(Theme.ivory).withAlphaComponent(0.9).cgColor)
            let radius = Theme.skeletonJoint / 2
            for joint in joints {
                guard let p = frame.imagePoint(joint) else { continue }
                let center = CGPoint(x: CGFloat(p.x) * size.width, y: CGFloat(p.y) * size.height)
                cg.fillEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
            }
        }
    }

    static func region(for bone: Bone) -> SkeletonRegion? {
        SkeletonRegion.allCases.first { $0.bones.contains(bone) }
    }
}
