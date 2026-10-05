import SwiftUI

/// La copie du paywall, dérivée de l'offre choisie. Les deux écrans disent la même
/// chose, et surtout : sans essai gratuit sur le produit, plus une seule phrase ne
/// promet d'essai. Aucune durée ni aucun prix n'est écrit en dur.
enum PaywallCopy {
    static func title(for offer: PlanOffer?) -> String {
        guard let trial = offer?.trialLabel else { return String(localized: "Passe en Pro") }
        return String(localized: "Essaie \(trial) gratuitement.")
    }

    static func callToAction(for offer: PlanOffer?) -> String {
        guard let trial = offer?.trialLabel else { return String(localized: "Passer en Pro") }
        return String(localized: "Essayer \(trial) gratuitement")
    }

    static func reassurance(for offer: PlanOffer?) -> String {
        offer?.trialLabel == nil
            ? String(localized: "Sans engagement. Résiliable dans l’App Store.")
            : String(localized: "Carte demandée, rien de prélevé aujourd’hui.")
    }

    static func fineprint(for offer: PlanOffer?) -> String {
        guard let offer else { return "" }
        let renewal = String(localized: "\(offer.priceLabel) / \(offer.periodLabel), renouvelé automatiquement.")
        guard let trial = offer.trialLabel else {
            return String(localized: "\(renewal) Résiliable dans l’App Store.")
        }
        return String(localized: "Essai gratuit : \(trial), puis \(renewal) Résiliable dans l’App Store.")
    }
}

/// Ce que l'essai engage, dans l'ordre. Les libellés ne calculent pas de dates :
/// « 24 h avant la fin » dit ce que `TrialReminder` fait vraiment.
struct TrialTimeline: View {
    var trialLabel: String
    var priceLabel: String

    private var steps: [(symbol: String, title: String, detail: String)] {
        [
            (
                "lock.open",
                String(localized: "Aujourd’hui"),
                String(localized: "Tout Pro s’ouvre. Ta carte est enregistrée, rien n’est prélevé.")
            ),
            (
                "bell",
                String(localized: "24 h avant la fin"),
                String(localized: "Si tu autorises les notifications, PoseLock te prévient qu’il reste un jour pour annuler.")
            ),
            (
                "creditcard",
                String(localized: "À la fin de l’essai"),
                String(localized: "\(priceLabel) prélevés, sauf résiliation avant.")
            )
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: 12) {
                    VStack(spacing: 0) {
                        Image(systemName: step.symbol)
                            .font(Theme.captionFont)
                            .foregroundStyle(Theme.background)
                            .frame(width: 26, height: 26)
                            .background(Theme.gold, in: Circle())

                        if index < steps.count - 1 {
                            Rectangle()
                                .fill(Theme.gold.opacity(0.35))
                                .frame(width: 2)
                                .frame(maxHeight: .infinity)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(step.title)
                            .font(Theme.bodyFont)
                            .foregroundStyle(Theme.ivory)
                        Text(step.detail)
                            .font(Theme.supportFont)
                            .foregroundStyle(Theme.ivoryMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.bottom, index < steps.count - 1 ? 18 : 0)

                    Spacer(minLength: 0)
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.elevated)
        .clipShape(RoundedRectangle(cornerRadius: Theme.continuousCorner, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.continuousCorner, style: .continuous)
                .stroke(Theme.hairline, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Essai de \(trialLabel)")
    }
}

struct PaywallBenefitRow: View {
    var benefit: ProBenefit

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "checkmark")
                .font(Theme.captionFont)
                .foregroundStyle(Theme.gold)
                .frame(width: 18, height: 18)
                .background(Theme.gold.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(benefit.title)
                    .font(Theme.bodyFont)
                    .foregroundStyle(Theme.ivory)
                Text(benefit.detail)
                    .font(Theme.supportFont)
                    .foregroundStyle(Theme.ivoryMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }
}

struct PlanCard: View {
    var offer: PlanOffer
    var isSelected: Bool
    var onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    if let discount = offer.discountPercent {
                        badge(discount)
                    } else {
                        badge(0).hidden().accessibilityHidden(true)
                    }
                    Spacer()
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? Theme.gold : Theme.ivoryMuted)
                        .accessibilityHidden(true)
                }

                Text(offer.periodLabel)
                    .font(Theme.supportFont)
                    .foregroundStyle(Theme.ivoryMuted)
                    .textCase(.uppercase)
                    .tracking(0.8)

                Text(offer.priceLabel)
                    .font(Theme.titleFont)
                    .foregroundStyle(Theme.ivory)

                Text(offer.monthlyEquivalentLabel.map { String(localized: "\($0) / mois") } ?? " ")
                    .font(Theme.supportFont)
                    .foregroundStyle(Theme.ivoryMuted)
                    .accessibilityHidden(offer.monthlyEquivalentLabel == nil)
            }
            .padding(14)
            // Les deux cartes prennent la hauteur du rang : sans ça, celle qui
            // n'a ni remise ni équivalent mensuel est plus courte que l'autre.
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(isSelected ? Theme.gold.opacity(0.10) : Theme.elevated)
            .clipShape(RoundedRectangle(cornerRadius: Theme.continuousCorner, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.continuousCorner, style: .continuous)
                    .stroke(
                        isSelected ? Theme.gold.opacity(0.65) : Theme.hairline,
                        lineWidth: isSelected ? 1.5 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private func badge(_ percent: Int) -> some View {
        Text("-\(percent) %")
            .font(Theme.captionFont)
            .foregroundStyle(Theme.background)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Theme.gold, in: Capsule())
    }
}

/// Preuve visuelle en tête de la feuille : la pose tenue, verte, et le score qui
/// autorise le lock. Pas de photo — l'app n'en montre jamais d'autre que les tiennes.
struct PaywallHero: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Theme.continuousCorner, style: .continuous)
                .fill(Theme.elevated)

            VStack(spacing: 12) {
                PoseReferenceImage(poseID: .frontDoubleBiceps, variant: .guided)
                    .frame(height: 100)
                    .padding(.top, 20)

                HStack(spacing: 8) {
                    Text("\(Int(ScoringConstants.lockScore))")
                        .font(Theme.titleFont)
                        .foregroundStyle(Theme.lockGreen)
                    Text("lockable")
                        .font(Theme.captionFont)
                        .foregroundStyle(Theme.ivoryMuted)
                        .textCase(.uppercase)
                        .tracking(1)
                }
                .padding(.bottom, 20)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: Theme.continuousCorner, style: .continuous)
                .stroke(Theme.lockGreen.opacity(0.28), lineWidth: 1)
        )
        .accessibilityHidden(true)
    }
}
