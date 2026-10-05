import SwiftData
import SwiftUI

/// Upsell en cours de route, quand le palier gratuit bloque quelque chose. Le titre
/// et le message viennent de `reason` : sans eux, la feuille surgit sans dire ce
/// qui vient d'être refusé.
struct PaywallSheet: View {
    var reason: PaywallReason
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(StoreManager.self) private var store
    @Environment(AppSession.self) private var session
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var settingsRows: [AppSettings]

    @State private var selectedID: String?

    private var offerLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
    }

    private var selected: PlanOffer? {
        store.offers.first { $0.id == selectedID } ?? store.offers.last
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    PaywallHero()
                        .frame(height: 170)

                    VStack(alignment: .leading, spacing: 10) {
                        Text(store.isPro ? "PoseLock Pro" : reason.title)
                            .font(Theme.titleFont)
                            .foregroundStyle(Theme.ivory)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(store.isPro ? String(localized: "Tous tes avantages sont débloqués.") : reason.message)
                            .font(Theme.bodyFont)
                            .foregroundStyle(Theme.ivoryMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if !store.isPro, let selected, let trial = selected.trialLabel {
                        TrialTimeline(trialLabel: trial, priceLabel: selected.priceLabel)
                    }



                    if store.isPro {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Ton abonnement Pro est actif.").font(Theme.bodyFont)
                            if let date = store.renewalDate {
                                Text("Fin de la période en cours : \(date.formatted(.dateTime.day().month().year()))")
                                    .font(Theme.supportFont).foregroundStyle(Theme.ivoryMuted)
                            }
                        }
                    } else if store.offers.isEmpty {
                        unavailable
                    } else {
                        offerLayout {
                            ForEach(store.offers) { offer in
                                PlanCard(offer: offer, isSelected: offer.id == selected?.id) {
                                    selectedID = offer.id
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(ProBenefit.allCases) { benefit in
                            PaywallBenefitRow(benefit: benefit)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
                if dynamicTypeSize.isAccessibilitySize && !store.isPro && !store.offers.isEmpty { footer }
            }
            .safeAreaInset(edge: .bottom) {
                if !dynamicTypeSize.isAccessibilitySize && !store.isPro && !store.offers.isEmpty { footer }
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }.foregroundStyle(Theme.gold)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Restaurer") {
                        Task {
                            await store.restore()
                            if store.isPro { dismissAfterPurchase() }
                        }
                    }
                    .font(Theme.supportFont)
                    .foregroundStyle(Theme.ivoryMuted)
                    .disabled(store.isLoading)
                }
            }
            .task {
                await store.refreshOffers()
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { PoseLockAnalytics.capture(.paywallViewed) }
    }

    private var footer: some View {
        VStack(spacing: 10) {
            Text(PaywallCopy.reassurance(for: selected))
                .font(Theme.supportFont)
                .foregroundStyle(Theme.ivoryMuted)
                .multilineTextAlignment(.center)

            Button(PaywallCopy.callToAction(for: selected)) {
                guard let selected else { return }
                Task {
                    await store.purchase(selected)
                    if store.isPro { dismissAfterPurchase() }
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(store.isLoading || selected == nil)

            if let purchaseError = store.purchaseError {
                Text(purchaseError)
                    .font(Theme.supportFont)
                    .foregroundStyle(Theme.frameRed)
                    .multilineTextAlignment(.center)
            }

            Text(PaywallCopy.fineprint(for: selected))
                .font(Theme.captionFont)
                .foregroundStyle(Theme.ivoryFaint)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 20)
        .background(Theme.background)
    }

    private var unavailable: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Les offres ne se chargent pas. Vérifie ta connexion.")
                .font(Theme.supportFont)
                .foregroundStyle(Theme.ivoryFaint)
                .fixedSize(horizontal: false, vertical: true)

            Button("Réessayer") {
                Task { await store.refreshOffers() }
            }
            .buttonStyle(PrimaryButtonStyle())
        }
    }

    /// Le pack demandé au moment du blocage s'applique enfin.
    private func dismissAfterPurchase() {
        if let pending = session.pendingPack {
            settingsRows.first?.pack = pending
            session.pendingPack = nil
        }
        dismiss()
    }
}
