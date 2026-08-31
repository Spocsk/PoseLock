import SwiftData
import SwiftUI
import UIKit

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(StoreManager.self) private var store
    @Environment(AppSession.self) private var session
    @Query private var settingsRows: [AppSettings]
    @Query(sort: \LockEntry.date, order: .reverse) private var entries: [LockEntry]

    var body: some View {
        @Bindable var session = session
        Group {
            if let settings, settings.onboardingDone {
                TabView {
                    HomeView(settings: settings, entries: entries)
                        .tabItem { Label("Accueil", systemImage: "square.grid.2x2") }
                    SettingsView(settings: settings, entries: entries)
                        .tabItem { Label("Réglages", systemImage: "gearshape") }
                }
                .tint(Theme.gold)
                .fullScreenCover(isPresented: $session.showCamera) {
                    CameraSessionView(settings: settings, entries: entries)
                }
                .sheet(isPresented: $session.showJournal) {
                    JournalSheet(entries: entries, isPro: store.isPro)
                }
                .sheet(isPresented: $session.showPaywall) {
                    PaywallSheet(reason: session.paywallReason)
                }
                .onAppear {
                    session.syncPoseOfTheDay(pack: settings.pack, entries: entries)
                }
                .onChange(of: settings.pack) { _, newPack in
                    session.syncPoseOfTheDay(pack: newPack, entries: entries)
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
