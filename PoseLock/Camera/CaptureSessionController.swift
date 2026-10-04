import AVFoundation
import SwiftUI
import UIKit

struct CameraPreviewRepresentable: UIViewRepresentable {
    let session: AVCaptureSession
    var isFront: Bool

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        applyMirroring(view)
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.previewLayer.session = session
        applyMirroring(uiView)
    }

    private func applyMirroring(_ view: PreviewView) {
        guard let connection = view.previewLayer.connection, connection.isVideoMirroringSupported else { return }
        connection.automaticallyAdjustsVideoMirroring = false
        connection.isVideoMirrored = isFront
        if connection.isVideoOrientationSupported {
            connection.videoOrientation = .portrait
        }
    }
}

final class PreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
}

final class CaptureSessionController: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    let session = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let queue = DispatchQueue(label: "poselock.camera.frames")
    private var currentPosition: AVCaptureDevice.Position = .back
    var onFrame: ((CMSampleBuffer, Bool) -> Void)?

    var isFront: Bool { currentPosition == .front }

    /// Largeur / hauteur des frames analysées une fois orientées en portrait
    /// (preset `.hd1280x720`). Sert au cadrage du squelette sur l'aperçu.
    static let portraitAspect: CGFloat = 720.0 / 1280.0

    func start(front: Bool, completion: @escaping (Bool) -> Void) {
        queue.async { [weak self] in
            guard let self else { return }
            self.applyConfiguration(front: front)
            if !self.session.isRunning {
                self.session.startRunning()
            }
            let nowFront = self.currentPosition == .front
            DispatchQueue.main.async { completion(nowFront) }
        }
    }

    func stop() {
        queue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    func setCamera(front: Bool, completion: @escaping (Bool) -> Void) {
        queue.async { [weak self] in
            guard let self else { return }
            self.applyConfiguration(front: front)
            if !self.session.isRunning {
                self.session.startRunning()
            }
            let nowFront = self.currentPosition == .front
            DispatchQueue.main.async { completion(nowFront) }
        }
    }

    private func applyConfiguration(front: Bool) {
        let running = session.isRunning
        if running {
            session.stopRunning()
        }
        session.beginConfiguration()
        session.inputs.forEach { session.removeInput($0) }
        session.sessionPreset = .hd1280x720
        currentPosition = front ? .front : .back
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: currentPosition),
           let input = try? AVCaptureDeviceInput(device: device),
           session.canAddInput(input) {
            session.addInput(input)
            try? device.lockForConfiguration()
            if device.activeFormat.videoSupportedFrameRateRanges.contains(where: { $0.maxFrameRate >= 30 }) {
                device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 30)
                device.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 30)
            }
            device.unlockForConfiguration()
        }
        if session.outputs.isEmpty {
            videoOutput.alwaysDiscardsLateVideoFrames = true
            videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
            videoOutput.setSampleBufferDelegate(self, queue: queue)
            if session.canAddOutput(videoOutput) {
                session.addOutput(videoOutput)
            }
        }
        if let connection = videoOutput.connection(with: .video) {
            if connection.isVideoMirroringSupported {
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = false
            }
        }
        session.commitConfiguration()
        if running {
            session.startRunning()
        }
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        onFrame?(sampleBuffer, currentPosition == .front)
    }
}
