import SwiftData
import SwiftUI

/// Upsell en cours de route, quand le palier gratuit bloque quelque chose. Le titre
/// et le message viennent de `reason` : sans eux, la feuille surgit sans dire ce
/// qui vient d'être refusé.
struct PaywallSheet: View {
    var reason: PaywallReason
    @Environment(StoreManager.self) private var store
    @Environment(AppSession.self) private var session
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var settingsRows: [AppSettings]

    @State private var selectedID: String?

    private var selected: PlanOffer? {
        store.offers.first { $0.id == selectedID } ?? store.offers.last
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    PaywallHero()
                        .frame(height: 220)

                    VStack(alignment: .leading, spacing: 10) {
                        Text(reason.title)
                            .font(.system(size: 26, weight: .regular))
                            .foregroundStyle(Theme.ivory)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(reason.message)
                            .font(Theme.bodyFont)
                            .foregroundStyle(Theme.ivoryMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let selected, let trial = selected.trialLabel {
                        TrialTimeline(trialLabel: trial, priceLabel: selected.priceLabel)
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(ProBenefit.allCases) { benefit in
                            PaywallBenefitRow(benefit: benefit)
                        }
                    }

                    if store.offers.isEmpty {
                        unavailable
                    } else {
                        HStack(alignment: .top, spacing: 10) {
                            ForEach(store.offers) { offer in
                                PlanCard(offer: offer, isSelected: offer.id == selected?.id) {
                                    selectedID = offer.id
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            .safeAreaInset(edge: .bottom) {
                if !store.offers.isEmpty { footer }
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }.foregroundStyle(Theme.gold)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Restaurer") { Task { await store.restore() } }
                        .font(Theme.supportFont)
                        .foregroundStyle(Theme.ivoryMuted)
                        .disabled(store.isLoading)
                }
            }
            .task { await store.refreshOffers() }
            .onChange(of: store.isPro) { _, isPro in
                guard isPro else { return }
                // Le pack demandé au moment du blocage s'applique enfin.
                if let pending = session.pendingPack {
                    settingsRows.first?.pack = pending
                    session.pendingPack = nil
                }
                dismiss()
            }
        }
        .preferredColorScheme(.dark)
    }

    private var footer: some View {
        VStack(spacing: 10) {
            Text(PaywallCopy.reassurance(for: selected))
                .font(Theme.supportFont)
                .foregroundStyle(Theme.ivoryMuted)
                .multilineTextAlignment(.center)

            Button(PaywallCopy.callToAction(for: selected)) {
                guard let selected else { return }
                Task { await store.purchase(selected) }
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
}
