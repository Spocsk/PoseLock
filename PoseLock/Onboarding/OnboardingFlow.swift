import AVFoundation
import SwiftUI

struct OnboardingFlow: View {
    @Bindable var settings: AppSettings
    @State private var step = 0

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            Group {
                switch step {
                case 0:
                    PromiseView { step = 1 }
                case 1:
                    PackPickerView(selected: $settings.pack) { step = 2 }
                case 2:
                    CameraPermissionView {
                        step = 3
                    }
                default:
                    FrameTutorialView(useFrontCamera: settings.cameraFront) {
                        settings.onboardingDone = true
                    }
                }
            }
            .animation(.easeInOut(duration: 0.25), value: step)
        }
    }
}

struct PromiseView: View {
    var onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            Text("Pose. Score. Lock.")
                .font(Theme.captionFont)
                .foregroundStyle(Theme.gold)
                .padding(.bottom, 20)
            Text("Ta pose, notée.\nLa vidéo ne quitte pas l’iPhone.")
                .font(Theme.titleFont)
                .foregroundStyle(Theme.ivory)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
            Button("Continuer", action: onContinue)
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
        }
    }
}

struct PackPickerView: View {
    @Binding var selected: Pack
    var onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Quel travail.")
                .font(Theme.titleFont)
                .foregroundStyle(Theme.ivory)
                .padding(.top, 64)
                .padding(.horizontal, 24)

            Text("Les trois packs restent là. Celui-ci préremplit la pose du jour.")
                .font(Theme.bodyFont)
                .foregroundStyle(Theme.ivoryMuted)
                .padding(.horizontal, 24)

            VStack(spacing: 10) {
                ForEach(Pack.allCases) { pack in
                    Button {
                        selected = pack
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(pack.displayName)
                                    .font(.system(size: 17, weight: .regular))
                                    .foregroundStyle(Theme.ivory)
                                Text(pack.subtitle)
                                    .font(Theme.captionFont)
                                    .foregroundStyle(Theme.ivoryMuted)
                            }
                            Spacer()
                            if selected == pack {
                                Circle()
                                    .stroke(Theme.gold, lineWidth: 1.5)
                                    .frame(width: 18, height: 18)
                                    .overlay(Circle().fill(Theme.gold).frame(width: 8, height: 8))
                            } else {
                                Circle()
                                    .stroke(Theme.ivoryFaint, lineWidth: 1)
                                    .frame(width: 18, height: 18)
                            }
                        }
                        .padding(16)
                        .background(Theme.elevated)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(selected == pack ? Theme.gold.opacity(0.6) : Theme.hairline, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24)

            Spacer()
            Button("Continuer", action: onContinue)
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
        }
    }
}

struct CameraPermissionView: View {
    var onContinue: () -> Void
    @State private var denied = false

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Text("Caméra")
                .font(Theme.titleFont)
                .foregroundStyle(Theme.ivory)
            Text("Demandée ici, pas au premier lock. La vidéo reste sur l’iPhone.")
                .font(Theme.bodyFont)
                .foregroundStyle(Theme.ivoryMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            if denied {
                Text("Refusée. L’app s’ouvre quand même. Tu pourras relancer depuis la caméra.")
                    .font(Theme.captionFont)
                    .foregroundStyle(Theme.goldMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.top, 8)
            }
            Spacer()
            Button(denied ? "Continuer" : "Autoriser la caméra") {
                Task { await request() }
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }

    private func request() async {
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        if granted {
            onContinue()
        } else {
            denied = true
            try? await Task.sleep(for: .milliseconds(650))
            onContinue()
        }
    }
}

struct FrameTutorialView: View {
    var useFrontCamera: Bool
    var onDone: () -> Void
    @State private var remaining = 8

    var body: some View {
        ZStack {
            CameraPreviewBackground(front: useFrontCamera)
            VStack {
                Spacer()
                VStack(spacing: 10) {
                    Text("Recule. Chevilles et mains dans l’image.")
                        .font(Theme.bodyFont)
                        .foregroundStyle(Theme.ivory)
                        .multilineTextAlignment(.center)
                    Text("\(remaining) s")
                        .font(Theme.captionFont)
                        .foregroundStyle(Theme.gold)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 56)
            }
        }
        .onAppear {
            remaining = 8
        }
        .task {
            for _ in 0..<8 {
                try? await Task.sleep(for: .seconds(1))
                remaining -= 1
            }
            onDone()
        }
    }
}

/// Preview légère pour l’écran cadre. Si la permission manque, fond noir.
struct CameraPreviewBackground: View {
    var front: Bool
    var body: some View {
        CameraPreviewRepresentable(session: SharedOnboardingCapture.session)
            .ignoresSafeArea()
            .onAppear { SharedOnboardingCapture.start(front: front) }
            .onDisappear { SharedOnboardingCapture.stop() }
    }
}

enum SharedOnboardingCapture {
    static let session = AVCaptureSession()
    private static let lock = NSLock()
    private static var configured = false

    static func start(front: Bool) {
        lock.lock()
        defer { lock.unlock() }
        if !configured {
            session.sessionPreset = .medium
            let position: AVCaptureDevice.Position = front ? .front : .back
            if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
               let input = try? AVCaptureDeviceInput(device: device),
               session.canAddInput(input) {
                session.addInput(input)
            }
            configured = true
        }
        let capture = session
        DispatchQueue.global(qos: .userInitiated).async {
            capture.startRunning()
        }
    }

    static func stop() {
        let capture = session
        DispatchQueue.global(qos: .userInitiated).async {
            capture.stopRunning()
        }
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .regular))
            .foregroundStyle(Theme.background)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Theme.gold)
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}
