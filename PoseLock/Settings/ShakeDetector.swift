import SwiftData
import SwiftUI
import UIKit

/// First responder invisible : le `fullScreenCover` caméra/coach a son propre
/// hosting controller, donc le shake du root ne suffit pas — le modifier
/// `poseLockFeedback` se pose aussi là.
struct ShakeDetector: UIViewControllerRepresentable {
    var onShake: () -> Void

    func makeUIViewController(context: Context) -> ShakeDetectingController {
        let controller = ShakeDetectingController()
        controller.onShake = onShake
        return controller
    }

    func updateUIViewController(_ uiViewController: ShakeDetectingController, context: Context) {
        uiViewController.onShake = onShake
    }
}

final class ShakeDetectingController: UIViewController {
    var onShake: (() -> Void)?

    override var canBecomeFirstResponder: Bool { true }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = false
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        becomeFirstResponder()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        resignFirstResponder()
    }

    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            onShake?()
        }
        super.motionEnded(motion, with: event)
    }
}

private struct FeedbackPresentation: ViewModifier {
    @Environment(AppSession.self) private var session
    @Query private var settingsRows: [AppSettings]

    func body(content: Content) -> some View {
        @Bindable var session = session
        content
            .background {
                ShakeDetector {
                    session.presentFeedback(hapticsEnabled: settingsRows.first?.hapticsEnabled ?? true)
                }
                .frame(width: 0, height: 0)
                .allowsHitTesting(false)
            }
            .sheet(isPresented: $session.showFeedback) {
                FeedbackSheet()
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
    }
}

extension View {
    func poseLockFeedback() -> some View {
        modifier(FeedbackPresentation())
    }
}
