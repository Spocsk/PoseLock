import Foundation
import SwiftData
import SwiftUI

@MainActor
@Observable
final class AppSession {
    var selectedPoseID: PoseID
    var showCamera = false
    var showJournal = false
    var showPaywall = false
    var showPoseLibrary = false
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
        showCamera = true
    }

    func requestPackChange(_ pack: Pack, settings: AppSettings, isPro: Bool, entries: [LockEntry]) {
        if !isPro && pack != settings.pack {
            pendingPack = pack
            paywallReason = .otherPack
            showPaywall = true
            return
        }
        settings.pack = pack
        syncPoseOfTheDay(pack: pack, entries: entries)
        PoseLockHaptics.selection(enabled: settings.hapticsEnabled)
    }
}

enum PaywallReason: Sendable {
    case dailyLimit
    case otherPack
    case generic

    var title: String {
        switch self {
        case .dailyLimit: return "3 locks aujourd’hui"
        case .otherPack: return "Les 3 packs, avec Pro"
        case .generic: return "PoseLock Pro"
        }
    }

    var message: String {
        switch self {
        case .dailyLimit:
            return "Le plafond free, c’est trois photos lockées par jour. Pro enlève le plafond. Le mode caméra ne change pas."
        case .otherPack:
            return "Free garde le pack choisi à l’onboarding. Pro ouvre Scène, Contenu et Physique."
        case .generic:
            return "Locks illimités, trois packs, comparatif J-30, carte share sans mention."
        }
    }
}
