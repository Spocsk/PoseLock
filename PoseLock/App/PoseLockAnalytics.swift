import CryptoKit
import Foundation

/// Transport TelemetryDeck minimal : seuls les événements listés ici partent, avec un contexte
/// technique fixe (version, appareil, iOS, langue). Aucun SDK ne collecte d'écrans ou de fichiers.
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
    private static let firstSessionKey = "poselock.analyticsFirstSessionDate"
    /// Clés laissées par l'ancien adaptateur Mixpanel, effacées au prochain choix.
    private static let legacyKeys = ["poselock.mixpanelConsent", "poselock.mixpanelAnonymousID", "poselock.mixpanelChoiceMade"]
    private static let endpoint = URL(string: "https://nom.telemetrydeck.com/v2/")!
    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpCookieStorage = nil
        configuration.urlCache = nil
        return URLSession(configuration: configuration)
    }()
    /// Même règle que le SwiftSDK : nouvelle session au lancement et après 5 min en arrière-plan.
    private static let sessionTimeout: TimeInterval = 5 * 60
    private static var sessionID = UUID().uuidString
    private static var sessionAnnounced = false
    private static var enteredBackgroundAt: Date?
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
        if granted {
            startSession()
        } else {
            for task in tasks.values { task.cancel() }
            tasks.removeAll()
            UserDefaults.standard.removeObject(forKey: visitorKey)
            UserDefaults.standard.removeObject(forKey: firstSessionKey)
            sessionID = UUID().uuidString
            sessionAnnounced = false
        }
    }

    static func appBecameActive() {
        if let enteredBackgroundAt, Date().timeIntervalSince(enteredBackgroundAt) > sessionTimeout {
            sessionID = UUID().uuidString
            sessionAnnounced = false
        }
        enteredBackgroundAt = nil
        if !sessionAnnounced { startSession() }
    }

    static func appEnteredBackground() {
        enteredBackgroundAt = Date()
    }

    static func capture(_ event: Event) {
        send(event)
    }

    static func completedOnboardingStep(_ step: OnboardingStep) {
        send(.onboardingStepCompleted, step: String(describing: step))
    }

    /// Signaux internes que le SwiftSDK enverrait seul : ils alimentent les tableaux par défaut.
    private static func startSession() {
        guard hasConsent, isConfigured, !sessionAnnounced else { return }
        sessionAnnounced = true
        if UserDefaults.standard.string(forKey: firstSessionKey) == nil {
            let today = Date().formatted(.iso8601.year().month().day())
            UserDefaults.standard.set(today, forKey: firstSessionKey)
            post("TelemetryDeck.Acquisition.newInstallDetected")
        }
        post("TelemetryDeck.Session.started")
    }

    /// Contexte technique de l'appareil, sous les noms du SwiftSDK. Rien qui identifie la personne.
    private static let deviceParameters: [String: String] = {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
        let os = ProcessInfo.processInfo.operatingSystemVersion
        var machine = utsname()
        uname(&machine)
        let model = withUnsafeBytes(of: &machine.machine) { String(decoding: $0.prefix { $0 != 0 }, as: UTF8.self) }
        #if targetEnvironment(simulator)
        let isSimulator = true
        #else
        let isSimulator = false
        #endif
        #if DEBUG
        let isDebug = true
        #else
        let isDebug = false
        #endif
        return [
            "TelemetryDeck.AppInfo.version": version,
            "TelemetryDeck.AppInfo.buildNumber": build,
            "TelemetryDeck.AppInfo.versionAndBuildNumber": "\(version) (build \(build))",
            "TelemetryDeck.Device.modelName": model,
            "TelemetryDeck.Device.operatingSystem": "iOS",
            "TelemetryDeck.Device.platform": "iOS",
            "TelemetryDeck.Device.systemVersion": "iOS \(os.majorVersion).\(os.minorVersion).\(os.patchVersion)",
            "TelemetryDeck.Device.systemMajorVersion": "iOS \(os.majorVersion)",
            "TelemetryDeck.Device.systemMajorMinorVersion": "iOS \(os.majorVersion).\(os.minorVersion)",
            "TelemetryDeck.RunContext.isDebug": "\(isDebug)",
            "TelemetryDeck.RunContext.isSimulator": "\(isSimulator)",
            "TelemetryDeck.RunContext.language": Locale.current.language.languageCode?.identifier ?? "",
            "TelemetryDeck.RunContext.locale": Locale.current.identifier,
        ]
    }()

    private static func send(_ event: Event, step: String? = nil) {
        if !sessionAnnounced { startSession() }
        var parameters: [String: String] = [:]
        if let step { parameters["Onboarding.step"] = step }
        post(event.rawValue, parameters: parameters)
    }

    private static func post(_ type: String, parameters: [String: String] = [:]) {
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
            "type": type,
        ]
        #if DEBUG
        signal["isTestMode"] = true
        #else
        signal["isTestMode"] = false
        #endif
        var payload = deviceParameters.merging(parameters) { _, custom in custom }
        if let firstSession = UserDefaults.standard.string(forKey: firstSessionKey) {
            payload["TelemetryDeck.Acquisition.firstSessionDate"] = firstSession
        }
        signal["payload"] = payload
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
