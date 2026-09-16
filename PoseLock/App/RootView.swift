import SwiftData
import SwiftUI
import UIKit

struct RootView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.modelContext) private var modelContext
    @Environment(StoreManager.self) private var store
    @Environment(AppSession.self) private var session
    @Query private var settingsRows: [AppSettings]
    @Query(sort: \LockEntry.date, order: .reverse) private var entries: [LockEntry]

    var body: some View {
        @Bindable var session = session
        Group {
            if let settings, settings.onboardingDone {
                TabView(selection: $session.selectedTab) {
                    HomeView(settings: settings, entries: entries)
                        .tabItem { Label("Accueil", systemImage: "square.grid.2x2") }
                        .tag(RootTab.home)
                    JournalView(entries: entries, isPro: store.isPro)
                        .tabItem { Label("Journal", systemImage: "rectangle.stack") }
                        .tag(RootTab.journal)
                    SettingsView(settings: settings, entries: entries)
                        .tabItem { Label("Réglages", systemImage: "gearshape") }
                        .tag(RootTab.settings)
                }
                .tint(Theme.gold)
                .fullScreenCover(isPresented: $session.showCoach) {
                    PoseCoachView(poseID: session.selectedPoseID) {
                        session.beginCameraFromCoach()
                    }
                }
                .fullScreenCover(isPresented: $session.showCamera) {
                    CameraSessionView(settings: settings, entries: entries)
                }
                .sheet(isPresented: $session.showPaywall) {
                    PaywallSheet(reason: session.paywallReason)
                }
                .onAppear {
                    session.syncPoseOfTheDay(pack: settings.pack, entries: entries)
                }
                .onChange(of: settings.pack) { _, newPack in
                    session.syncPoseOfTheDay(pack: newPack, entries: entries)
                    if store.isPro, settings.competitionRemindersEnabled, let date = settings.competitionDate {
                        Task {
                            await CompetitionReminder.schedule(
                                date: date,
                                place: settings.competitionPlace,
                                pack: newPack,
                                entries: entries.map(\.snapshot)
                            )
                        }
                    }
                }
                .onChange(of: store.isPro) { _, isPro in
                    if !isPro {
                        CompetitionReminder.cancel()
                        if settings.pack == .zyzz {
                            let fallback = settings.goal?.suggestedPack ?? .scene
                            settings.pack = fallback
                            session.syncPoseOfTheDay(pack: fallback, entries: entries)
                        }
                    } else if settings.competitionRemindersEnabled, let date = settings.competitionDate {
                        Task {
                            await CompetitionReminder.schedule(
                                date: date,
                                place: settings.competitionPlace,
                                pack: settings.pack,
                                entries: entries.map(\.snapshot)
                            )
                        }
                    }
                }
            } else {
                OnboardingFlow(settings: ensureSettings())
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .task {
            _ = ensureSettings()
            await store.load()
        }
        .onAppear { styleTabBar() }
        .transaction { transaction in
            if reduceMotion { transaction.disablesAnimations = true }
        }
    }

    private var settings: AppSettings? { settingsRows.first }

    private func styleTabBar() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Theme.background)
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    @discardableResult
    private func ensureSettings() -> AppSettings {
        if let existing = settingsRows.first { return existing }
        let created = AppSettings()
        modelContext.insert(created)
        return created
    }
}
