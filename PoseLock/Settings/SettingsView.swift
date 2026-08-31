import AuthenticationServices
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
    @State private var showPrivacy = false
    @State private var showPaywall = false

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
                    Toggle("Haptics", isOn: $settings.hapticsEnabled)
                    Picker("Caméra par défaut", selection: $settings.cameraFront) {
                        Text("Arrière").tag(false)
                        Text("Avant").tag(true)
                    }
                    Button("Effacer le journal", role: .destructive) {
                        confirmErase = true
                    }
                    Button("Confidentialité") { showPrivacy = true }
                    LabeledContent("Version", value: version)
                }

                Section("Abonnement") {
                    LabeledContent("État") {
                        Text(store.isPro ? "PoseLock Pro" : "Free · 3 locks/jour")
                            .foregroundStyle(Theme.ivoryMuted)
                    }
                    Button("PoseLock Pro") { showPaywall = true }
                    Button("Restaurer les achats") {
                        Task { await store.restore() }
                    }
                    Link("Privacy Policy", destination: privacyURL)
                    Link("EULA (Apple)", destination: eulaURL)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Réglages")
            .navigationBarTitleDisplayMode(.inline)
            .tint(Theme.gold)
            .confirmationDialog("Effacer toutes les photos lockées ?", isPresented: $confirmErase, titleVisibility: .visible) {
                Button("Effacer le journal", role: .destructive) { eraseJournal() }
                Button("Annuler", role: .cancel) {}
            }
            .sheet(isPresented: $showPrivacy) { PrivacyView() }
            .sheet(isPresented: $showPaywall) { PaywallSheet(reason: .generic) }
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
    static let body = """
    La vidéo de session ne quitte pas l’iPhone.

    PoseLock note l’exécution d’une pose sur l’appareil (Vision, on-device). Les photos lockées restent dans l’app, dans le stockage local. Rien n’est envoyé à un serveur applicatif en V1.

    Si tu actives « Sauvegarder aussi dans Photos », une copie de la photo clean est écrite dans l’album système.

    Le reçu d’abonnement est géré par Apple. PoseLock n’a pas de compte social.

    Tu peux effacer le journal dans Réglages.
    """
}

struct PaywallSheet: View {
    var reason: PaywallReason
    @Environment(StoreManager.self) private var store
    @Environment(AppSession.self) private var session
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var settingsRows: [AppSettings]

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text(reason.title)
                    .font(Theme.titleFont)
                    .foregroundStyle(Theme.ivory)
                Text(reason.message)
                    .font(Theme.bodyFont)
                    .foregroundStyle(Theme.ivoryMuted)

                ForEach(store.products, id: \.id) { product in
                    Button {
                        Task { await store.purchase(product) }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(product.displayName)
                                    .foregroundStyle(Theme.ivory)
                                Text(product.description)
                                    .font(Theme.captionFont)
                                    .foregroundStyle(Theme.ivoryMuted)
                            }
                            Spacer()
                            Text(product.displayPrice)
                                .foregroundStyle(Theme.gold)
                        }
                        .padding(16)
                        .background(Theme.elevated)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.hairline, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }

                if store.products.isEmpty {
                    Text("Offres indisponibles. Connecte un compte App Store, ou utilise Products.storekit dans le scheme Xcode.")
                        .font(Theme.captionFont)
                        .foregroundStyle(Theme.ivoryMuted)
                }

                if let purchaseError = store.purchaseError {
                    Text(purchaseError)
                        .font(Theme.captionFont)
                        .foregroundStyle(Theme.frameRed)
                }

                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = []
                } onCompletion: { result in
                    if case .success(let auth) = result,
                       let credential = auth.credential as? ASAuthorizationAppleIDCredential {
                        settingsRows.first?.appleUserID = credential.user
                    }
                }
                .signInWithAppleButtonStyle(.white)
                .frame(height: 44)
                .padding(.top, 8)

                Text("Sign in with Apple sert uniquement à retrouver l’abonnement sur un autre appareil. Restore Purchases reste le chemin Apple.")
                    .font(Theme.captionFont)
                    .foregroundStyle(Theme.ivoryFaint)

                Spacer()
            }
            .padding(24)
            .background(Theme.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }.foregroundStyle(Theme.gold)
                }
            }
            .task { await store.refreshProducts() }
            .onChange(of: store.isPro) { _, isPro in
                if isPro {
                    if let pending = session.pendingPack {
                        settingsRows.first?.pack = pending
                        session.pendingPack = nil
                    }
                    dismiss()
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
