import Foundation

/// Transport Mixpanel minimal : seuls les événements explicitement listés sont envoyés.
/// Aucun SDK ne collecte de propriétés, d'écrans ou de fichiers automatiquement.
@MainActor
enum PoseLockAnalytics {
    enum Event: String {
        case onboardingStarted = "onboarding_started"
        case onboardingStepCompleted = "onboarding_step_completed"
        case paywallViewed = "paywall_viewed"
        case purchaseCompleted = "purchase_completed"
        case cameraSessionStarted = "camera_session_started"
        case lockSaved = "lock_saved"
        case shareStarted = "share_started"
    }

    private static let consentKey = "poselock.mixpanelConsent"
    private static let visitorKey = "poselock.mixpanelAnonymousID"
    private static let endpoint = URL(string: "https://api-eu.mixpanel.com/track?ip=0")!
    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = nil
        configuration.urlCache = nil
        return URLSession(configuration: configuration)
    }()
    private static var tasks: [UUID: URLSessionDataTask] = [:]

    private static var projectToken: String? {
        guard let token = Bundle.main.object(forInfoDictionaryKey: "MixpanelProjectToken") as? String,
              token.range(of: "^[A-Za-z0-9]{16,64}$", options: .regularExpression) != nil
        else { return nil }
        return token
    }

    static var isConfigured: Bool { projectToken != nil }
    static var hasConsent: Bool { UserDefaults.standard.bool(forKey: consentKey) }

    static func setConsent(_ granted: Bool) {
        UserDefaults.standard.set(granted, forKey: consentKey)
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
        guard hasConsent, let token = projectToken else { return }
        let anonymousID: String
        if let existing = UserDefaults.standard.string(forKey: visitorKey) {
            anonymousID = existing
        } else {
            anonymousID = UUID().uuidString
            UserDefaults.standard.set(anonymousID, forKey: visitorKey)
        }

        var properties: [String: String] = ["token": token, "distinct_id": anonymousID]
        #if DEBUG
        properties["environment"] = "development"
        #else
        properties["environment"] = "production"
        #endif
        if let step { properties["step"] = step }
        let payload: [[String: Any]] = [["event": event.rawValue, "properties": properties]]
        guard let body = try? JSONSerialization.data(withJSONObject: payload) else { return }
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        let taskID = UUID()
        let task = session.dataTask(with: request) { _, _, _ in
            Task { @MainActor in tasks.removeValue(forKey: taskID) }
        }
        tasks[taskID] = task
        task.resume()
    }
}
