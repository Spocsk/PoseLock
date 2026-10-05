import MessageUI
import SwiftUI
import UIKit

/// Signalement utilisateur : Mail.app vers une adresse fixe. Texte + version, jamais
/// une photo ni un score — la session caméra ne quitte pas l’iPhone.
enum FeedbackMail {
    static let supportAddress = "apps@dylan-cdo.fr"
    static var subject: String { String(localized: "PoseLock — un problème") }

    static func body(
        message: String,
        version: String,
        build: String,
        systemVersion: String
    ) -> String {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        return """
        \(trimmed)

        —
        PoseLock \(version) (\(build))
        iOS \(systemVersion)
        """
    }

    static func currentVersion(bundle: Bundle = .main) -> (version: String, build: String) {
        let version = bundle.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = bundle.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return (version, build)
    }

    static func mailtoURL(
        message: String,
        version: String,
        build: String,
        systemVersion: String
    ) -> URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = supportAddress
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body(
                message: message,
                version: version,
                build: build,
                systemVersion: systemVersion
            ))
        ]
        return components.url
    }
}

struct MailComposeView: UIViewControllerRepresentable {
    var recipients: [String]
    var subject: String
    var body: String
    var onFinish: (MFMailComposeResult) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onFinish: onFinish)
    }

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let controller = MFMailComposeViewController()
        controller.mailComposeDelegate = context.coordinator
        controller.setToRecipients(recipients)
        controller.setSubject(subject)
        controller.setMessageBody(body, isHTML: false)
        return controller
    }

    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {
        context.coordinator.onFinish = onFinish
    }

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        var onFinish: (MFMailComposeResult) -> Void

        init(onFinish: @escaping (MFMailComposeResult) -> Void) {
            self.onFinish = onFinish
        }

        func mailComposeController(
            _ controller: MFMailComposeViewController,
            didFinishWith result: MFMailComposeResult,
            error: Error?
        ) {
            onFinish(result)
        }
    }
}
