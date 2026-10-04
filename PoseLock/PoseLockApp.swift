import SwiftUI
import SwiftData
import UIKit

enum HomeScreenQuickAction: String {
    case reportProblem = "com.spocsk.PoseLock.reportProblem"

    init?(shortcutItemType: String) {
        self.init(rawValue: shortcutItemType)
    }

    @MainActor
    func perform(in session: AppSession) {
        switch self {
        case .reportProblem:
            // Le raccourci peut arriver avant le chargement des réglages.
            // Ne pas vibrer évite de contourner la préférence de l’utilisateur.
            session.presentFeedback(hapticsEnabled: false)
        }
    }
}

@MainActor
final class HomeScreenQuickActionRouter {
    static let shared = HomeScreenQuickActionRouter()

    private weak var session: AppSession?
    private var pendingQuickAction: HomeScreenQuickAction?

    private init() {}

    func connect(to session: AppSession) {
        self.session = session
        guard let pendingQuickAction else { return }
        self.pendingQuickAction = nil
        pendingQuickAction.perform(in: session)
    }

    func handle(_ shortcutItem: UIApplicationShortcutItem) -> Bool {
        guard let action = HomeScreenQuickAction(shortcutItemType: shortcutItem.type) else {
            return false
        }

        if let session {
            action.perform(in: session)
        } else {
            pendingQuickAction = action
        }
        return true
    }
}

@MainActor
final class PoseLockSceneDelegate: NSObject, UIWindowSceneDelegate {
    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let shortcutItem = connectionOptions.shortcutItem else { return }
        _ = HomeScreenQuickActionRouter.shared.handle(shortcutItem)
    }

    func windowScene(
        _ windowScene: UIWindowScene,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        completionHandler(HomeScreenQuickActionRouter.shared.handle(shortcutItem))
    }
}

final class PoseLockAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(
            name: nil,
            sessionRole: connectingSceneSession.role
        )
        configuration.delegateClass = PoseLockSceneDelegate.self
        return configuration
    }
}

@main
struct PoseLockApp: App {
    @UIApplicationDelegateAdaptor(PoseLockAppDelegate.self) private var appDelegate
    @State private var store = StoreManager()
    @State private var session = AppSession()

    init() {
        StoreManager.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(session)
                .preferredColorScheme(.dark)
                .onAppear { HomeScreenQuickActionRouter.shared.connect(to: session) }
        }
        .modelContainer(for: [AppSettings.self, LockEntry.self])
    }
}
