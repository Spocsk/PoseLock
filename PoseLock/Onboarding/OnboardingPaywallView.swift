import SwiftUI

/// Paywall dur : la seule sortie normale est l'achat, qui enchaîne sur l'étape
/// compte. Prix, durée d'essai et remise viennent de RevenueCat — rien n'est écrit
/// en dur ici. `onUnavailable` n'existe que pour l'offering qui ne charge pas,
/// sinon l'onboarding boucle.
struct OnboardingPaywallView: View {
    var onBack: () -> Void
    var onUnavailable: () -> Void
    var onPurchased: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(StoreManager.self) private var store
    @State private var selectedID: String?
    @State private var loadAttempts = 0
    @State private var isLoadingOffers = true

    /// À défaut de choix explicite, l'offre la plus longue : c'est celle qui porte
    /// la remise.
    private var offerLayout: AnyLayout {
        dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
    }

    private var selected: PlanOffer? {
        store.offers.first { $0.id == selectedID } ?? store.offers.last
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            if store.isPro {
                VStack(spacing: 20) {
                    Text("PoseLock Pro est actif").font(Theme.titleFont)
                    Text("Ton abonnement est déjà reconnu sur cet appareil.")
                        .font(Theme.supportFont).foregroundStyle(Theme.ivoryMuted)
                    Button("Continuer", action: onPurchased)
                        .buttonStyle(PrimaryButtonStyle())
                }
                .padding(24)
                .frame(maxHeight: .infinity)
            } else if store.offers.isEmpty {
                if isLoadingOffers {
                    ProgressView()
                        .tint(Theme.gold)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    unavailable
                }
            } else {
                ScrollView {
                    content
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)
                    if dynamicTypeSize.isAccessibilitySize { footer }
                }
                if !dynamicTypeSize.isAccessibilitySize { footer }
            }
        }
        .task {
            await reload()
        }
    }

    private var header: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(Theme.supportFont)
                    .foregroundStyle(Theme.ivoryMuted)
                    .frame(width: Theme.minimumTarget, height: Theme.minimumTarget)
                    .background(Theme.elevated, in: Circle())
                    .overlay(Circle().stroke(Theme.hairline, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Étape précédente")

            Spacer()

            Button("Restaurer") {
                Task { await buy { await store.restore() } }
            }
            .font(Theme.supportFont)
            .foregroundStyle(Theme.ivoryMuted)
            .disabled(store.isLoading)
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 20)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 10) {
                Text(PaywallCopy.title(for: selected))
                    .font(Theme.titleFont)
                    .foregroundStyle(Theme.ivory)
                    .fixedSize(horizontal: false, vertical: true)

                Text(PaywallReason.onboarding.message)
                    .font(Theme.bodyFont)
                    .foregroundStyle(Theme.ivoryMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Sans essai, il n'y a pas de calendrier à raconter.
            if let selected, let trial = selected.trialLabel {
                TrialTimeline(trialLabel: trial, priceLabel: selected.priceLabel)
            }



            offerLayout {
                ForEach(store.offers) { offer in
                    PlanCard(offer: offer, isSelected: offer.id == selected?.id) {
                        selectedID = offer.id
                    }
                }
            }

            VStack(alignment: .leading, spacing: 14) {
                ForEach(ProBenefit.allCases) { benefit in
                    PaywallBenefitRow(benefit: benefit)
                }
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 10) {
            Text(PaywallCopy.reassurance(for: selected))
                .font(Theme.supportFont)
                .foregroundStyle(Theme.ivoryMuted)
                .multilineTextAlignment(.center)

            Button(PaywallCopy.callToAction(for: selected)) {
                guard let selected else { return }
                Task { await buy { await store.purchase(selected) } }
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
        .padding(.bottom, 28)
    }

    /// L'offering peut ne pas répondre. Sans cette porte, l'onboarding boucle.
    private var unavailable: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Les offres ne se chargent pas. Vérifie ta connexion.")
                .font(Theme.bodyFont)
                .foregroundStyle(Theme.ivoryMuted)
                .fixedSize(horizontal: false, vertical: true)

            Button("Réessayer") {
                Task { await reload() }
            }
            .buttonStyle(PrimaryButtonStyle())

            if loadAttempts >= 2 {
                Button("Continuer sans les offres", action: onUnavailable)
                    .font(Theme.bodyFont)
                    .foregroundStyle(Theme.ivoryMuted)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func reload() async {
        isLoadingOffers = true
        await store.refreshOffers()
        loadAttempts += 1
        isLoadingOffers = false
    }

    /// L'achat met `isPro` à jour, mais `@Observable` + `onChange` ne le voit
    /// pas toujours. On avance dès que l'entitlement est active, ici.
    private func buy(_ work: () async -> Void) async {
        await work()
        if store.isPro { onPurchased() }
    }
}
