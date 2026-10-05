import StoreKit
import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(StoreManager.self) private var store
    @Environment(AppSession.self) private var session
    @Environment(\.modelContext) private var modelContext
    @Bindable var settings: AppSettings
    var entries: [LockEntry]
    @State private var confirmErase = false
    @State private var confirmDevReset = false
    @State private var showPrivacy = false
    @State private var showPaywall = false
    @State private var showManageSubscriptions = false
    @AppStorage("poselock.mixpanelConsent") private var analyticsConsent = false

    private var version: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }

    var body: some View {
        NavigationStack {
            List {
                Section("App") {
                    Picker("Pack actif", selection: Binding(
                        get: { settings.pack },
                        set: { session.requestPackChange($0, settings: settings, isPro: store.isPro, entries: entries) }
                    )) {
                        ForEach(Pack.allCases) { pack in
                            Text(pack.displayName).tag(pack)
                        }
                    }
                    Toggle("Qualité photo haute", isOn: $settings.photoQualityHigh)
                    Toggle("Sauvegarder aussi dans Photos", isOn: $settings.saveToPhotos)
                    Toggle("Retours haptiques", isOn: $settings.hapticsEnabled)
                    Picker("Caméra par défaut", selection: $settings.cameraFront) {
                        Text("Arrière").tag(false)
                        Text("Avant").tag(true)
                    }
                    Button("Effacer le journal", role: .destructive) {
                        confirmErase = true
                    }
                    Button("Un problème ?") {
                        session.presentFeedback(hapticsEnabled: settings.hapticsEnabled)
                    }
                    Button("Confidentialité") { showPrivacy = true }
                    LabeledContent("Version", value: version)
                }

                Section {
                    if store.isPro {
                        deadlineFields
                    } else {
                        Button {
                            session.paywallReason = .deadline
                            session.showPaywall = true
                        } label: {
                            HStack {
                                Text("Échéance")
                                Spacer()
                                Image(systemName: "lock.fill")
                                    .font(Theme.captionFont)
                                    .foregroundStyle(Theme.goldMuted)
                            }
                        }
                    }
                } header: {
                    Text("Échéance")
                } footer: {
                    if store.isPro, settings.competitionDate != nil {
                        Text("Un rappel à 9 h, à J-7, J-3 et J-1 de ton échéance.")
                    }
                }


                Section("Abonnement") {
                    LabeledContent("État") {
                        Text(store.isPro ? "PoseLock Pro" : String(localized: "Gratuit · \(ScoringConstants.freeLocksPerDay) locks/jour"))
                            .foregroundStyle(Theme.ivoryMuted)
                    }
                    Button("PoseLock Pro") { showPaywall = true }
                    Button("Restaurer les achats") {
                        Task { await store.restore() }
                    }
                    if store.isPro {
                        Button("Gérer l’abonnement") {
                            showManageSubscriptions = true
                        }
                    }
                    Link("Confidentialité", destination: privacyURL)
                    Link("Conditions d’utilisation", destination: eulaURL)
                }
                Section {
                    Toggle("Statistiques d’usage sans compte", isOn: $analyticsConsent)
                        .disabled(!PoseLockAnalytics.isConfigured)
                    if !PoseLockAnalytics.isConfigured {
                        Text("Indisponibles pour le moment.")
                    }
                } header: {
                    Text("Statistiques")
                } footer: {
                    Text("Facultatives. Aucun score, pose, image ou vidéo n’est envoyé. Désactive-les ici à tout moment.")
                }
                #if DEBUG
                Section {
                    Button("Effacer toutes les données locales", role: .destructive) {
                        confirmDevReset = true
                    }
                } header: {
                    Text("Développement")
                } footer: {
                    Text("Debug uniquement. Journal, photos et réglages. Relance l’onboarding au prochain écran.")
                }
                #endif

            }
            .listStyle(.insetGrouped)
            .environment(\.defaultMinListRowHeight, 52)
            .scrollContentBackground(.hidden)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Réglages")
            .navigationBarTitleDisplayMode(.large)
            .tint(Theme.gold)
            .confirmationDialog("Effacer toutes les photos lockées ?", isPresented: $confirmErase, titleVisibility: .visible) {
                Button("Effacer le journal", role: .destructive) { eraseJournal() }
                Button("Annuler", role: .cancel) {}
            }
            #if DEBUG
            .confirmationDialog(
                "Effacer toutes les données locales ?",
                isPresented: $confirmDevReset,
                titleVisibility: .visible
            ) {
                Button("Tout effacer et revoir l’onboarding", role: .destructive) {
                    session.resetAllLocalData(settings: settings, entries: entries, modelContext: modelContext)
                }
                Button("Annuler", role: .cancel) {}
            }
            #endif
            .sheet(isPresented: $showPrivacy) { PrivacyView() }
            .sheet(isPresented: $showPaywall) { PaywallSheet(reason: .generic) }
            .manageSubscriptionsSheet(isPresented: $showManageSubscriptions)
            .onChange(of: analyticsConsent) { _, granted in
                PoseLockAnalytics.setConsent(granted)
            }
        }
    }

    @ViewBuilder
    private var deadlineFields: some View {
        Toggle("Activer", isOn: Binding(
            get: { settings.competitionDate != nil },
            set: { enabled in
                if enabled {
                    settings.competitionDate = Calendar.current.date(byAdding: .day, value: 30, to: Date())
                } else {
                    settings.competitionDate = nil
                    settings.competitionPlace = nil
                    settings.competitionRemindersEnabled = false
                    CompetitionReminder.cancel()
                }
            }
        ))
        if settings.competitionDate != nil {
            DatePicker(
                "Date",
                selection: Binding(
                    get: { settings.competitionDate ?? Date() },
                    set: { newDate in
                        settings.competitionDate = newDate
                        Task { await syncDeadlineReminders() }
                    }
                ),
                in: Date()...,
                displayedComponents: .date
            )
            TextField("Lieu (optionnel)", text: Binding(
                get: { settings.competitionPlace ?? "" },
                set: { newValue in
                    settings.competitionPlace = newValue.isEmpty ? nil : newValue
                    if settings.competitionRemindersEnabled {
                        Task { await syncDeadlineReminders() }
                    }
                }
            ))
            Toggle("Rappels", isOn: Binding(
                get: { settings.competitionRemindersEnabled },
                set: { enabled in
                    settings.competitionRemindersEnabled = enabled
                    Task { await syncDeadlineReminders() }
                }
            ))
        }
    }

    private func syncDeadlineReminders() async {
        guard store.isPro,
              settings.competitionRemindersEnabled,
              let date = settings.competitionDate else {
            CompetitionReminder.cancel()
            if settings.competitionDate == nil {
                settings.competitionRemindersEnabled = false
            }
            return
        }
        let granted = await CompetitionReminder.schedule(
            date: date,
            place: settings.competitionPlace,
            pack: settings.pack,
            entries: entries.map(\.snapshot)
        )
        if !granted {
            settings.competitionRemindersEnabled = false
        }
    }

    private var privacyURL: URL {
        URL(string: "https://www.apple.com/legal/privacy/")!
    }

    private var eulaURL: URL {
        URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    }

    private func eraseJournal() {
        for entry in entries {
            PhotoStore.delete(cleanPath: entry.cleanPath, overlayPath: entry.overlayPath)
            modelContext.delete(entry)
        }
        PhotoStore.deleteAll()
    }
}

struct PrivacyView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(PrivacyCopy.body)
                    .font(Theme.bodyFont)
                    .foregroundStyle(Theme.ivoryMuted)
                    .padding(24)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Confidentialité")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }.foregroundStyle(Theme.gold)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

enum PrivacyCopy {
    static var body: String { String(localized: """
    La vidéo de session ne quitte pas l’iPhone.

    PoseLock note l’exécution d’une pose sur l’appareil (Vision, on-device). Les photos lockées restent dans l’app, dans le stockage local. Aucune image, aucune vidéo, aucun score n’est envoyé ailleurs.

    Si tu actives « Sauvegarder aussi dans Photos », une copie de la photo clean est écrite dans l’album système.

    Un signalement (secousse ou Réglages) ouvre Mail avec ton texte et la version de l’app. Pas de photo, pas de pose, pas de score.

    L’abonnement est géré par Apple et RevenueCat. RevenueCat reçoit l’historique d’achat nécessaire à l’état de Pro, jamais tes photos ni tes poses.

    Si tu actives les statistiques dans Réglages, PoseLock transmet à Mixpanel EU quelques événements d’usage sans compte (étapes du parcours, caméra démarrée, photo lockée, partage commencé). Un identifiant technique aléatoire distingue les installations consentantes. Sans ton accord, aucune statistique Mixpanel n’est envoyée. Tu peux retirer l’accord dans Réglages ; les envois en cours sont annulés et l’identifiant local effacé. Aucun nom, identifiant Apple, objectif, image, vidéo, pose ou score n’est transmis. Pas de suivi publicitaire ni d’enregistrement de session.

    Tu peux effacer le journal dans Réglages.
    """) }
}
