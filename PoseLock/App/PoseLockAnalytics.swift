import CryptoKit
import Foundation

/// Transport TelemetryDeck minimal : seuls les événements explicitement listés sont envoyés.
/// Aucun SDK ne collecte de propriétés, d'écrans ou de fichiers automatiquement.
@MainActor
enum PoseLockAnalytics {
    enum Event: String {
        case onboardingStarted = "Onboarding.started"
        case onboardingStepCompleted = "Onboarding.stepCompleted"
        case paywallViewed = "Paywall.viewed"
        case purchaseCompleted = "Purchase.completed"
        case cameraSessionStarted = "Camera.sessionStarted"
        case lockSaved = "Lock.saved"
        case shareStarted = "Share.started"
    }

    private static let consentKey = "poselock.analyticsConsent"
    private static let visitorKey = "poselock.analyticsAnonymousID"
    /// Clés laissées par l'ancien adaptateur Mixpanel, effacées au prochain choix.
    private static let legacyKeys = ["poselock.mixpanelConsent", "poselock.mixpanelAnonymousID", "poselock.mixpanelChoiceMade"]
    private static let endpoint = URL(string: "https://nom.telemetrydeck.com/v2/namespace/fr.dylan-cdo/")!
    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = nil
        configuration.urlCache = nil
        return URLSession(configuration: configuration)
    }()
    /// Une session TelemetryDeck par lancement de l'app.
    private static let sessionID = UUID().uuidString
    private static var tasks: [UUID: URLSessionDataTask] = [:]

    private static var appID: String? {
        guard let id = Bundle.main.object(forInfoDictionaryKey: "TelemetryDeckAppID") as? String,
              UUID(uuidString: id) != nil
        else { return nil }
        return id
    }

    static var isConfigured: Bool { appID != nil }
    static var hasConsent: Bool { UserDefaults.standard.bool(forKey: consentKey) }

    static func setConsent(_ granted: Bool) {
        UserDefaults.standard.set(granted, forKey: consentKey)
        for key in legacyKeys { UserDefaults.standard.removeObject(forKey: key) }
        if !granted {
            for task in tasks.values { task.cancel() }
            tasks.removeAll()
            UserDefaults.standard.removeObject(forKey: visitorKey)
        }
    }

    static func capture(_ event: Event) {
        send(event)
    }

    static func completedOnboardingStep(_ step: OnboardingStep) {
        send(.onboardingStepCompleted, step: String(describing: step))
    }

    private static func send(_ event: Event, step: String? = nil) {
        guard hasConsent, let appID else { return }
        let anonymousID: String
        if let existing = UserDefaults.standard.string(forKey: visitorKey) {
            anonymousID = existing
        } else {
            anonymousID = UUID().uuidString
            UserDefaults.standard.set(anonymousID, forKey: visitorKey)
        }
        // TelemetryDeck attend un hash : l'identifiant aléatoire local ne part jamais en clair.
        let clientUser = SHA256.hash(data: Data(anonymousID.utf8))
            .map { String(format: "%02x", $0) }
            .joined()

        var signal: [String: Any] = [
            "appID": appID,
            "clientUser": clientUser,
            "sessionID": sessionID,
            "type": event.rawValue,
        ]
        #if DEBUG
        signal["isTestMode"] = true
        #else
        signal["isTestMode"] = false
        #endif
        if let step { signal["payload"] = ["Onboarding.step": step] }
        guard let body = try? JSONSerialization.data(withJSONObject: [signal]) else { return }
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        let taskID = UUID()
        let task = session.dataTask(with: request) { _, _, _ in
            Task { @MainActor in tasks.removeValue(forKey: taskID) }
        }
        tasks[taskID] = task
        task.resume()
    }
}
