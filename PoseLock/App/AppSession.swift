import Foundation
import SwiftData
import SwiftUI

enum RootTab: Hashable {
    case home
    case journal
    case settings
}

@MainActor
@Observable
final class AppSession {
    var selectedPoseID: PoseID
    var selectedTab: RootTab = .home
    var showCamera = false
    var showCoach = false
    var showPaywall = false
    var showPoseLibrary = false
    var showFeedback = false
    var paywallReason: PaywallReason = .generic
    var pendingPack: Pack?

    init(pose: PoseID = Pack.scene.defaultPoseID) {
        selectedPoseID = pose
    }

    func syncPoseOfTheDay(pack: Pack, entries: [LockEntry]) {
        let snapshots = entries.map(\.snapshot)
        selectedPoseID = DailyPoseSelector.poseOfTheDay(pack: pack, entries: snapshots)
    }

    func requestWork(isPro: Bool, settings: AppSettings, entries: [LockEntry]) {
        let snapshots = entries.map(\.snapshot)
        if !LockQuota.canLock(entries: snapshots, isPro: isPro) {
            paywallReason = .dailyLimit
            showPaywall = true
            return
        }
        showCoach = true
    }

    func presentFeedback(hapticsEnabled: Bool) {
        guard !showFeedback else { return }
        PoseLockHaptics.selection(enabled: hapticsEnabled)
        showFeedback = true
    }

    func beginCameraFromCoach() {
        showCoach = false
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(320))
            showCamera = true
        }
    }

    func requestPackChange(_ pack: Pack, settings: AppSettings, isPro: Bool, entries: [LockEntry]) {
        if !isPro && pack != settings.pack {
            pendingPack = pack
            paywallReason = pack == .zyzz ? .zyzz : .otherPack
            showPaywall = true
            return
        }
        settings.pack = pack
        syncPoseOfTheDay(pack: pack, entries: entries)
        PoseLockHaptics.selection(enabled: settings.hapticsEnabled)
    }

    func resetAllLocalData(settings: AppSettings, entries: [LockEntry], modelContext: ModelContext) {
        showCamera = false
        showCoach = false
        showPaywall = false
        showPoseLibrary = false
        showFeedback = false
        pendingPack = nil
        selectedTab = .home
        selectedPoseID = Pack.scene.defaultPoseID

        for entry in entries {
            PhotoStore.delete(cleanPath: entry.cleanPath, overlayPath: entry.overlayPath)
            modelContext.delete(entry)
        }
        PhotoStore.deleteAll()

        settings.onboardingDone = false
        settings.pack = .scene
        settings.goal = nil
        settings.cameraFront = false
        settings.hapticsEnabled = true
        settings.saveToPhotos = false
        settings.photoQualityHigh = true
        settings.appleUserID = nil
        settings.competitionDate = nil
        settings.competitionPlace = nil
        settings.competitionRemindersEnabled = false
        CompetitionReminder.cancel()
        try? modelContext.save()
    }
}

/// Pourquoi le paywall s'ouvre.
enum PaywallReason: Sendable {
    case dailyLimit
    case otherPack
    case deadline
    case zyzz
    case onboarding
    case generic

    var title: String {
        switch self {
        case .dailyLimit: return "3 locks aujourd’hui"
        case .otherPack: return "Les 3 packs, avec Pro"
        case .deadline: return "Rappels d’échéance"
        case .zyzz: return "Catégorie Zyzz"
        case .onboarding: return "Passe en Pro"
        case .generic: return "PoseLock Pro"
        }
    }

    var message: String {
        switch self {
        case .dailyLimit:
            return "Le plafond free, c’est trois photos lockées par jour."
        case .otherPack:
            return "Free garde le pack choisi à l’onboarding. Pro ouvre les trois."
        case .deadline:
            return "J-7, J-3, J-1. La pose à retravailler, pas un calendrier vide."
        case .zyzz:
            return "La pose esthétique. Vacuum, twist, V-taper."
        case .onboarding:
            return "Le mode caméra, les catalogues, Zyzz et le journal, sans plafond, dès la première séance."
        case .generic:
            return "Le même mode caméra. Plus de plafond, plus de packs, le recul d’un mois."
        }
    }
}

/// La carte sans marque était un quatrième argument. Elle a été retirée : toute
/// image exportée porte désormais la signature `ShareMark`, Pro compris, donc la
/// promettre serait mentir.
enum ProBenefit: CaseIterable, Identifiable {
    case unlimited
    case packs
    case compare
    case deadline
    case zyzz

    var id: Self { self }

    var step: Int {
        switch self {
        case .unlimited: return 1
        case .packs: return 2
        case .compare: return 3
        case .deadline: return 4
        case .zyzz: return 5
        }
    }

    var symbolName: String {
        switch self {
        case .unlimited: return "infinity"
        case .packs: return "square.stack.3d.up"
        case .compare: return "rectangle.split.2x1"
        case .deadline: return "calendar"
        case .zyzz: return "sparkles"
        }
    }

    var title: String {
        switch self {
        case .unlimited: return "Locks illimités"
        case .packs: return "Scène, Contenu, Physique"
        case .compare: return "Comparatif J-30"
        case .deadline: return "Rappels d’échéance"
        case .zyzz: return "Catégorie Zyzz"
        }
    }

    var detail: String {
        switch self {
        case .unlimited:
            return "Plus de plafond 3 / jour. Tu lockes autant que la séance le demande."
        case .packs:
            return "Les mandatories, l’angle contenu, la posture. Les trois catalogues, pas un seul."
        case .compare:
            return "La même pose, un mois plus tôt, à côté de la prise du jour."
        case .deadline:
            return "J-7, J-3, J-1. La pose à retravailler, pas un calendrier vide."
        case .zyzz:
            return "La pose esthétique. Vacuum, twist, V-taper."
        }
    }
}
