#if DEBUG
import SwiftData
import SwiftUI
import UIKit

/// Catalogue d’écrans pour la banque d’images. Activé uniquement par
/// `-ScreenBankScene <id>` au lancement debug.
enum ScreenBankScene: String, CaseIterable {
    case onboardingSplash = "01-onboarding-splash"
    case onboardingGoal = "02-onboarding-goal"
    case onboardingPack = "03-onboarding-pack"
    case onboardingPain = "04-onboarding-pain"
    case onboardingProof = "05-onboarding-proof"
    case onboardingCamera = "06-onboarding-camera"
    case onboardingRecap = "07-onboarding-recap"
    case onboardingPersonalization = "08-onboarding-personalization"
    case onboardingPaywall = "09-onboarding-paywall"
    case onboardingAccount = "10-onboarding-account"
    case home = "11-home"
    case homePoseLibrary = "12-home-pose-library"
    case journalEmpty = "13-journal-empty"
    case journalEmptyPoses = "14-journal-empty-poses"
    case settings = "15-settings"
    case settingsPrivacy = "16-settings-privacy"
    case settingsFeedback = "17-settings-feedback"
    case paywallGeneric = "18-paywall-generic"
    case paywallDailyLimit = "19-paywall-daily-limit"
    case paywallZyzz = "20-paywall-zyzz"
    case paywallDeadline = "21-paywall-deadline"
    case coachSetup = "22-coach-setup"
    case coachPose = "23-coach-pose"
    case coachHold = "24-coach-hold"
    case cameraLive = "25-camera-live"
    case cameraLock = "26-camera-lock"
    case journalTakes = "27-journal-takes"
    case journalDetail = "28-journal-detail"
    case journalDetailOverlay = "29-journal-detail-overlay"
    case journalShareCard = "30-journal-share-card"
    case journalPoses = "31-journal-poses"
    case journalRecapShare = "32-journal-recap-share"

    var title: String {
        switch self {
        case .onboardingSplash: return "Onboarding · splash"
        case .onboardingGoal: return "Onboarding · objectif"
        case .onboardingPack: return "Onboarding · pack"
        case .onboardingPain: return "Onboarding · pain"
        case .onboardingProof: return "Onboarding · preuve"
        case .onboardingCamera: return "Onboarding · caméra"
        case .onboardingRecap: return "Onboarding · récap"
        case .onboardingPersonalization: return "Onboarding · personnalisation"
        case .onboardingPaywall: return "Onboarding · paywall"
        case .onboardingAccount: return "Onboarding · compte"
        case .home: return "Accueil"
        case .homePoseLibrary: return "Accueil · bibliothèque de poses"
        case .journalEmpty: return "Journal · vide (prises)"
        case .journalEmptyPoses: return "Journal · vide (poses)"
        case .settings: return "Réglages"
        case .settingsPrivacy: return "Réglages · confidentialité"
        case .settingsFeedback: return "Réglages · signalement"
        case .paywallGeneric: return "Paywall · générique"
        case .paywallDailyLimit: return "Paywall · plafond quotidien"
        case .paywallZyzz: return "Paywall · Zyzz"
        case .paywallDeadline: return "Paywall · échéance"
        case .coachSetup: return "Coach · corps entier"
        case .coachPose: return "Coach · pose"
        case .coachHold: return "Coach · tenue"
        case .cameraLive: return "Caméra · pose live"
        case .cameraLock: return "Caméra · lock"
        case .journalTakes: return "Journal · prises"
        case .journalDetail: return "Journal · détail"
        case .journalDetailOverlay: return "Journal · détail silhouette"
        case .journalShareCard: return "Journal · carte de partage"
        case .journalPoses: return "Journal · récap poses"
        case .journalRecapShare: return "Journal · carte récap"
        }
    }

    var summary: String {
        switch self {
        case .onboardingSplash:
            return "Première slide plein écran : photo, wordmark, CTA. Aucune question."
        case .onboardingGoal:
            return "Choix d’objectif (compèt’, contenu, forme). Décide du pack suggéré."
        case .onboardingPack:
            return "Les trois packs onboarding (Scène, Contenu, Physique). Zyzz exclu."
        case .onboardingPain:
            return "Reformulation du problème selon l’objectif. Les deux réponses avancent."
        case .onboardingProof:
            return "Comparatif exemple J-30, scores étiquetés « Exemple »."
        case .onboardingCamera:
            return "Demande d’autorisation caméra. Preuve on-device, pas de serveur."
        case .onboardingRecap:
            return "Récap des choix avant personnalisation."
        case .onboardingPersonalization:
            return "Décompte 100 % rejouant objectif, pack, pose du jour, seuil de lock."
        case .onboardingPaywall:
            return "Paywall dur de fin de tunnel. Prix issus de RevenueCat."
        case .onboardingAccount:
            return "Sign in with Apple, contournable. Pas d’entitlement Apple Sign In."
        case .home:
            return "Onglet Accueil : pose du jour, tendance, stats, échéance."
        case .homePoseLibrary:
            return "Feuille de choix de pose, catalogues par pack."
        case .journalEmpty:
            return "Journal sans prises. Empty state vers la pose."
        case .journalEmptyPoses:
            return "Onglet Poses du journal, encore vide."
        case .settings:
            return "Réglages : pack, photo, haptics, caméra, abonnement, debug."
        case .settingsPrivacy:
            return "Texte de confidentialité : vidéo on-device, pas de photo envoyée."
        case .settingsFeedback:
            return "Feuille « Un problème ? » vers Mail, sans pièce jointe image."
        case .paywallGeneric:
            return "Paywall in-app générique PoseLock Pro."
        case .paywallDailyLimit:
            return "Paywall déclenché par le plafond 3 locks / jour."
        case .paywallZyzz:
            return "Paywall catalogue Zyzz, sans affiliation."
        case .paywallDeadline:
            return "Paywall rappels d’échéance J-7 / J-3 / J-1."
        case .coachSetup:
            return "Coach page 1 : reculer, corps entier dans le cadre."
        case .coachPose:
            return "Coach page 2 : cues et référence low-poly guidée."
        case .coachHold:
            return "Coach page 3 : tenir jusqu’au vert, seuil de lock."
        case .cameraLive:
            return "Session caméra debug : photo démo, tête floutée, skeleton vert."
        case .cameraLock:
            return "Overlay de lock après prise, score estampillé, photo démo."
        case .journalTakes:
            return "Grille des prises avec la photo démo Front double biceps."
        case .journalDetail:
            return "Détail d’une prise, photo clean, comparatifs J-7 / J-30."
        case .journalDetailOverlay:
            return "Détail avec silhouette / skeleton superposé."
        case .journalShareCard:
            return "Carte 9:16 à partager, signature ShareMark."
        case .journalPoses:
            return "Récap par pose : skeleton de référence vs capturé + photo."
        case .journalRecapShare:
            return "Carte de partage du récap pose."
        }
    }

    var tags: [String] {
        var tags = [
            "app:poselock",
            "locale:fr",
            "platform:ios",
            "source:simulator",
            "screen:\(rawValue)"
        ]
        tags.append("flow:\(flow)")
        tags.append("section:\(section)")
        tags.append(contentsOf: extraTags)
        return tags
    }

    var flow: String {
        switch self {
        case .onboardingSplash, .onboardingGoal, .onboardingPack, .onboardingPain,
             .onboardingProof, .onboardingCamera, .onboardingRecap,
             .onboardingPersonalization, .onboardingPaywall, .onboardingAccount:
            return "onboarding"
        case .home, .homePoseLibrary:
            return "home"
        case .journalEmpty, .journalEmptyPoses, .journalTakes, .journalDetail,
             .journalDetailOverlay, .journalShareCard, .journalPoses, .journalRecapShare:
            return "journal"
        case .settings, .settingsPrivacy, .settingsFeedback:
            return "settings"
        case .paywallGeneric, .paywallDailyLimit, .paywallZyzz, .paywallDeadline:
            return "paywall"
        case .coachSetup, .coachPose, .coachHold:
            return "coach"
        case .cameraLive, .cameraLock:
            return "camera"
        }
    }

    var section: String {
        switch self {
        case .onboardingSplash: return "splash"
        case .onboardingGoal: return "goal"
        case .onboardingPack: return "pack"
        case .onboardingPain: return "pain"
        case .onboardingProof: return "proof"
        case .onboardingCamera: return "permission"
        case .onboardingRecap: return "recap"
        case .onboardingPersonalization: return "personalization"
        case .onboardingPaywall: return "paywall"
        case .onboardingAccount: return "account"
        case .home: return "dashboard"
        case .homePoseLibrary: return "pose-library"
        case .journalEmpty, .journalEmptyPoses: return "empty"
        case .settings: return "list"
        case .settingsPrivacy: return "privacy"
        case .settingsFeedback: return "feedback"
        case .paywallGeneric: return "generic"
        case .paywallDailyLimit: return "daily-limit"
        case .paywallZyzz: return "zyzz"
        case .paywallDeadline: return "deadline"
        case .coachSetup: return "setup"
        case .coachPose: return "pose"
        case .coachHold: return "hold"
        case .cameraLive: return "live"
        case .cameraLock: return "lock"
        case .journalTakes: return "takes"
        case .journalDetail: return "detail"
        case .journalDetailOverlay: return "overlay"
        case .journalShareCard: return "share-card"
        case .journalPoses: return "pose-recap"
        case .journalRecapShare: return "recap-share"
        }
    }

    private var extraTags: [String] {
        switch self {
        case .onboardingSplash: return ["hero", "photo-fond", "cta"]
        case .onboardingGoal: return ["choix", "training-goal"]
        case .onboardingPack: return ["pack-scene", "pack-contenu", "pack-physique"]
        case .onboardingPain: return ["micro-engagement"]
        case .onboardingProof: return ["exemple", "comparatif", "no-social-proof"]
        case .onboardingCamera: return ["permission-camera", "on-device"]
        case .onboardingRecap: return ["resume"]
        case .onboardingPersonalization: return ["progress", "trust-signals"]
        case .onboardingPaywall: return ["hard-paywall", "revenuecat"]
        case .onboardingAccount: return ["sign-in-with-apple", "skippable"]
        case .home: return ["pose-du-jour", "front-double-biceps", "tab-accueil"]
        case .homePoseLibrary: return ["sheet", "pose-catalog"]
        case .journalEmpty, .journalEmptyPoses: return ["empty-state", "tab-journal"]
        case .settings: return ["tab-reglages", "debug-section"]
        case .settingsPrivacy: return ["legal", "on-device"]
        case .settingsFeedback: return ["sheet", "mail", "no-photo"]
        case .paywallGeneric, .paywallDailyLimit, .paywallZyzz, .paywallDeadline:
            return ["pro", "revenuecat", "native-paywall"]
        case .coachSetup, .coachPose, .coachHold:
            return ["low-poly", "pose-reference", "front-double-biceps"]
        case .cameraLive:
            return ["demo-photo", "face-blurred", "skeleton-vert", "front-double-biceps"]
        case .cameraLock:
            return ["demo-photo", "face-blurred", "score-93", "lock-overlay"]
        case .journalTakes:
            return ["demo-photo", "face-blurred", "grid", "score-93"]
        case .journalDetail:
            return ["demo-photo", "face-blurred", "score-93"]
        case .journalDetailOverlay:
            return ["demo-photo", "face-blurred", "skeleton-vert", "overlay"]
        case .journalShareCard, .journalRecapShare:
            return ["share", "sharemark", "9-16", "demo-photo", "face-blurred"]
        case .journalPoses:
            return ["skeleton-3d", "demo-photo", "comparatif"]
        }
    }

    var onboardingStep: OnboardingStep? {
        switch self {
        case .onboardingSplash: return .splash
        case .onboardingGoal: return .goal
        case .onboardingPack: return .pack
        case .onboardingPain: return .pain
        case .onboardingProof: return .proof
        case .onboardingCamera: return .camera
        case .onboardingRecap: return .recap
        case .onboardingPersonalization: return .personalization
        case .onboardingPaywall: return .paywall
        case .onboardingAccount: return .account
        default: return nil
        }
    }

    var tab: RootTab {
        switch self {
        case .journalEmpty, .journalEmptyPoses, .journalTakes, .journalPoses:
            return .journal
        case .settings, .settingsPrivacy, .settingsFeedback:
            return .settings
        default:
            return .home
        }
    }

    var journalTab: JournalTab {
        switch self {
        case .journalEmptyPoses, .journalPoses: return .poses
        default: return .takes
        }
    }

    var paywallReason: PaywallReason? {
        switch self {
        case .paywallGeneric: return .generic
        case .paywallDailyLimit: return .dailyLimit
        case .paywallZyzz: return .zyzz
        case .paywallDeadline: return .deadline
        default: return nil
        }
    }

    var coachPage: Int? {
        switch self {
        case .coachSetup: return 0
        case .coachPose: return 1
        case .coachHold: return 2
        default: return nil
        }
    }

    var needsJournal: Bool {
        switch self {
        case .home, .homePoseLibrary, .journalTakes, .journalDetail, .journalDetailOverlay,
             .journalShareCard, .journalPoses, .journalRecapShare, .cameraLock:
            return true
        default:
            return false
        }
    }

    var clearsJournal: Bool {
        switch self {
        case .journalEmpty, .journalEmptyPoses: return true
        default: return false
        }
    }

    var isCamera: Bool {
        self == .cameraLive || self == .cameraLock
    }

    var locksOnAppear: Bool { self == .cameraLock }

    var readyDelayMs: Int {
        switch self {
        case .onboardingPaywall, .paywallGeneric, .paywallDailyLimit, .paywallZyzz, .paywallDeadline:
            return 2200
        case .cameraLock:
            return 1400
        case .homePoseLibrary, .journalShareCard, .journalRecapShare:
            return 900
        default:
            return 1100
        }
    }
}

enum ScreenBank {
    /// Scènes propres destinées aux enregistrements marketing. Ce mode est
    /// strictement DEBUG et ne peut donc jamais être activé dans l'app livrée.
    static var videoDemoScene: ScreenBankScene? {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "-VideoDemoMode") else { return nil }
        let next = args.index(after: index)
        guard next < args.endIndex else { return .cameraLock }
        switch args[next] {
        case "camera-lock": return .cameraLock
        case "journal": return .journalTakes
        case "share": return .journalShareCard
        default: return nil
        }
    }

    static var current: ScreenBankScene? {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "-ScreenBankScene") else { return nil }
        let next = args.index(after: index)
        guard next < args.endIndex else { return nil }
        return ScreenBankScene(rawValue: args[next])
    }

    static var usesDemoCamera: Bool {
        // Tout build DEBUG travaille sur la photo embarquée : le simulateur et
        // un iPhone de développement donnent ainsi exactement la même détection
        // Vision, sans demander ni démarrer la caméra physique.
        return true
    }

    static func markReady(_ scene: ScreenBankScene) {
        if videoDemoScene == nil {
            UIView.setAnimationsEnabled(false)
        }
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let meta: [String: Any] = [
            "id": scene.rawValue,
            "title": scene.title,
            "summary": scene.summary,
            "flow": scene.flow,
            "section": scene.section,
            "tags": scene.tags
        ]
        if let data = try? JSONSerialization.data(withJSONObject: meta, options: [.prettyPrinted, .sortedKeys]),
           let text = String(data: data, encoding: .utf8) {
            try? text.write(to: docs.appendingPathComponent("screenbank-meta.json"), atomically: true, encoding: .utf8)
        }
        try? scene.rawValue.write(
            to: docs.appendingPathComponent("screenbank-ready.txt"),
            atomically: true,
            encoding: .utf8
        )
    }

    static func wipeJournal(_ entries: [LockEntry], modelContext: ModelContext) {
        for entry in entries {
            PhotoStore.delete(cleanPath: entry.cleanPath, overlayPath: entry.overlayPath)
            modelContext.delete(entry)
        }
        PhotoStore.deleteAll()
        try? modelContext.save()
    }

    static func seedDemoLock(modelContext: ModelContext) {
        guard let clean = DebugDemoPose.image else { return }
        let frame = PoseDetector().detect(image: clean, isFront: false) ?? .preview(for: .frontDoubleBiceps)
        var evaluation = ScoringEngine.evaluate(
            frame: frame,
            template: TemplateLibrary.template(for: .frontDoubleBiceps)
        )
        evaluation.gate = .ok
        evaluation.rawScore = DebugDemoPose.stampedScore
        evaluation.greenRegions = Set(SkeletonRegion.allCases)
        evaluation.missingJoints = []
        evaluation.worstCue = "Tiens la ligne."
        let overlay = SkeletonRenderer.overlayImage(base: clean, frame: frame, evaluation: evaluation)
        let id = UUID()
        guard let saved = try? PhotoStore.save(id: id, clean: clean, overlay: overlay, highQuality: true) else { return }
        let snapshot = SkeletonSnapshot(frame: frame, evaluation: evaluation)
        let entry = LockEntry(
            id: id,
            pack: .scene,
            poseID: .frontDoubleBiceps,
            score: DebugDemoPose.stampedScore,
            durationToLock: 2.4,
            cleanPath: saved.cleanPath,
            overlayPath: saved.overlayPath,
            skeletonData: try? JSONEncoder().encode(snapshot)
        )
        modelContext.insert(entry)
        try? modelContext.save()
    }
}

struct ScreenBankRoot: View {
    var scene: ScreenBankScene
    @Environment(\.modelContext) private var modelContext
    @Environment(StoreManager.self) private var store
    @Environment(AppSession.self) private var session
    @Query private var settingsRows: [AppSettings]
    @Query(sort: \LockEntry.date, order: .reverse) private var entries: [LockEntry]

    var body: some View {
        Group {
            if let settings {
                content(settings: settings)
            } else {
                Theme.background.ignoresSafeArea()
            }
        }
        .preferredColorScheme(.dark)
        .poseLockFeedback()
        .task { await prepareAndSignal() }
    }

    private var settings: AppSettings? { settingsRows.first }

    @ViewBuilder
    private func content(settings: AppSettings) -> some View {
        if let step = scene.onboardingStep {
            OnboardingFlow(settings: settings, initialStep: step)
        } else if let page = scene.coachPage {
            PoseCoachView(poseID: .frontDoubleBiceps, onStart: {}, initialPage: page)
        } else if scene.isCamera {
            CameraSessionView(settings: settings, entries: entries)
        } else if let reason = scene.paywallReason {
            PaywallSheet(reason: reason)
        } else if scene == .settingsPrivacy {
            PrivacyView()
        } else if scene == .settingsFeedback {
            FeedbackSheet()
        } else if scene == .journalDetail || scene == .journalDetailOverlay {
            detail(overlay: scene == .journalDetailOverlay)
        } else if scene == .journalShareCard {
            shareCard
        } else if scene == .journalRecapShare {
            recapShare
        } else {
            mainTabs(settings: settings)
        }
    }

    private func mainTabs(settings: AppSettings) -> some View {
        TabView(selection: Binding(
            get: { scene.tab },
            set: { session.selectedTab = $0 }
        )) {
            HomeView(settings: settings, entries: entries)
                .tabItem { Label("Accueil", systemImage: "square.grid.2x2") }
                .tag(RootTab.home)
            JournalView(entries: entries, isPro: store.isPro, initialTab: scene.journalTab)
                .tabItem { Label("Journal", systemImage: "rectangle.stack") }
                .tag(RootTab.journal)
            SettingsView(settings: settings, entries: entries)
                .tabItem { Label("Réglages", systemImage: "gearshape") }
                .tag(RootTab.settings)
        }
        .tint(Theme.gold)
        .sheet(isPresented: Binding(
            get: { scene == .homePoseLibrary },
            set: { session.showPoseLibrary = $0 }
        )) {
            PoseLibrarySheet(pack: settings.pack, isPro: store.isPro, selected: Binding(
                get: { session.selectedPoseID },
                set: { session.selectedPoseID = $0 }
            ))
        }
    }

    @ViewBuilder
    private func detail(overlay: Bool) -> some View {
        if let entry = entries.first {
            NavigationStack {
                JournalDetailView(
                    entry: entry,
                    entries: entries,
                    isPro: store.isPro,
                    showOverlayInitially: overlay
                )
                .navigationTitle(entry.poseID.displayName)
            }
        } else {
            ProgressView().tint(Theme.gold).frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.background.ignoresSafeArea())
        }
    }

    @ViewBuilder
    private var shareCard: some View {
        if let entry = entries.first {
            ShareCardView(entry: entry)
        } else {
            ProgressView().tint(Theme.gold).frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.background.ignoresSafeArea())
        }
    }

    @ViewBuilder
    private var recapShare: some View {
        if let entry = entries.first {
            PoseRecapShareView(entry: entry, yaw: 18)
        } else {
            ProgressView().tint(Theme.gold).frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.background.ignoresSafeArea())
        }
    }

    private func prepareAndSignal() async {
        UIView.setAnimationsEnabled(false)
        guard let settings = settingsRows.first ?? insertSettings() else { return }
        settings.hapticsEnabled = false
        settings.goal = .competition
        settings.pack = .scene
        settings.cameraFront = false
        settings.onboardingDone = scene.onboardingStep == nil
        session.selectedPoseID = .frontDoubleBiceps
        session.selectedTab = scene.tab
        session.showCamera = false
        session.showCoach = false
        session.showPaywall = false
        session.showFeedback = false
        session.showPoseLibrary = scene == .homePoseLibrary
        session.paywallReason = scene.paywallReason ?? .generic

        if scene.needsJournal || scene.clearsJournal {
            ScreenBank.wipeJournal(entries, modelContext: modelContext)
        }
        if scene.needsJournal {
            ScreenBank.seedDemoLock(modelContext: modelContext)
            var waits = 0
            while entries.isEmpty && waits < 25 {
                try? await Task.sleep(for: .milliseconds(80))
                waits += 1
            }
        }
        try? await Task.sleep(for: .milliseconds(scene.readyDelayMs))
        ScreenBank.markReady(scene)
    }

    private func insertSettings() -> AppSettings? {
        let created = AppSettings(pack: .scene, goal: .competition)
        modelContext.insert(created)
        try? modelContext.save()
        return created
    }
}
#endif
