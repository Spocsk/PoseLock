import Foundation
import RevenueCat

@MainActor
@Observable
final class StoreManager {
    private(set) var isPro = false
    /// Fin de la période en cours — donc fin de l'essai juste après l'achat.
    private(set) var renewalDate: Date?
    /// Ce que le paywall affiche, prix et essai compris. Vide : il n'y a rien à
    /// vendre, et le paywall doit montrer sa sortie de secours.
    private(set) var offers: [PlanOffer] = []
    private(set) var purchaseError: String?
    private(set) var isLoading = false

    private var offering: Offering?
    private var updatesTask: Task<Void, Never>?

    /// À appeler une seule fois, au plus tôt : tout accès à `Purchases.shared`
    /// avant la configuration lève une exception.
    static func configure() {
        guard RevenueCatConfig.isConfigured, !Purchases.isConfigured else { return }
        #if DEBUG
        Purchases.logLevel = .info
        #endif
        Purchases.configure(withAPIKey: RevenueCatConfig.apiKey)
    }

    func load() async {
        guard Purchases.isConfigured else { return }
        updatesTask?.cancel()
        updatesTask = Task { await listenForUpdates() }
        await refreshOffers()
        await refreshEntitlements()
    }

    func refreshOffers() async {
        guard Purchases.isConfigured else {
            purchaseError = "Impossible de charger les offres."
            return
        }
        do {
            let offerings = try await Purchases.shared.offerings()
            let found = offerings.offering(identifier: RevenueCatConfig.defaultOffering) ?? offerings.current
            offering = found
            offers = found.map(PlanOffer.make(from:)) ?? []
            purchaseError = offers.isEmpty ? "Impossible de charger les offres." : nil
        } catch {
            offering = nil
            offers = []
            purchaseError = "Impossible de charger les offres."
        }
    }

    func purchase(_ offer: PlanOffer) async {
        guard Purchases.isConfigured else { return }
        isLoading = true
        purchaseError = nil
        defer { isLoading = false }
        do {
            let result = try await Purchases.shared.purchase(package: offer.package)
            // Une annulation n'est pas une erreur : rien à dire à l'écran.
            guard !result.userCancelled else { return }
            apply(result.customerInfo)
            // Le Test Store peut renvoyer un customerInfo sans entitlement
            // encore actif : un second fetch débloque le paywall.
            await refreshEntitlements()
        } catch {
            purchaseError = "L’achat n’a pas abouti."
        }
    }

    func restore() async {
        guard Purchases.isConfigured else { return }
        isLoading = true
        purchaseError = nil
        defer { isLoading = false }
        do {
            apply(try await Purchases.shared.restorePurchases())
        } catch {
            purchaseError = "Restauration impossible."
        }
    }

    func refreshEntitlements() async {
        guard Purchases.isConfigured,
              let info = try? await Purchases.shared.customerInfo()
        else { return }
        apply(info)
    }

    /// `entitlements.active` est la seule source de vérité : un abonnement expiré
    /// reste dans l'historique mais en sort.
    private func apply(_ info: CustomerInfo) {
        let entitlement = info.entitlements[RevenueCatConfig.proEntitlement]
        isPro = entitlement?.isActive == true
        renewalDate = entitlement?.expirationDate
    }

    /// Couvre le renouvellement et l'expiration, que l'app ne verrait pas sinon.
    private func listenForUpdates() async {
        for await info in Purchases.shared.customerInfoStream {
            apply(info)
        }
    }
}

/// Tout ce que le paywall doit écrire pour un abonnement, calculé une fois depuis
/// le produit. Rien n'est écrit en dur : les prix, l'essai et la remise viennent
/// de RevenueCat, donc du dashboard.
struct PlanOffer: Identifiable {
    let package: Package
    /// « 1 mois », « 1 an ».
    let periodLabel: String
    /// « 9,99 € », déjà dans la devise de l'App Store de l'utilisateur.
    let priceLabel: String
    /// « 5,00 € », seulement quand la période dépasse le mois.
    let monthlyEquivalentLabel: String?
    /// « 50 », en pourcents, face au prix mensuel. Nil sans mensuel de référence.
    let discountPercent: Int?
    /// « 1 semaine », nil quand le produit ne porte aucun essai gratuit.
    let trialLabel: String?

    var id: String { package.identifier }

    static func make(from offering: Offering) -> [PlanOffer] {
        // Le mensuel d'abord, comme sur l'écran : le moins cher à gauche.
        let packages = offering.availablePackages
            .sorted { $0.storeProduct.price < $1.storeProduct.price }

        let monthlyReference = packages
            .first { $0.storeProduct.monthCount == 1 }?
            .storeProduct

        return packages.map { package in
            let product = package.storeProduct
            // L'équivalent mensuel n'a d'intérêt que si la période dépasse le mois.
            let equivalent = (product.monthCount ?? 0) > 1 ? product.monthlyPrice : nil

            return PlanOffer(
                package: package,
                periodLabel: product.subscriptionPeriod?.frenchLabel ?? product.localizedTitle,
                priceLabel: product.localizedPriceString,
                monthlyEquivalentLabel: equivalent.flatMap { product.formatted($0) },
                discountPercent: discount(of: product, against: monthlyReference),
                trialLabel: product.freeTrialLabel
            )
        }
    }

    /// La remise annoncée compare des mensualités, pas un total contre un autre.
    private static func discount(of product: StoreProduct, against reference: StoreProduct?) -> Int? {
        guard let reference, reference.id != product.id,
              let monthly = product.monthlyPrice, reference.price > 0,
              monthly < reference.price
        else { return nil }

        let ratio = (reference.price - monthly) / reference.price
        let percent = Int((ratio as NSDecimalNumber).doubleValue * 100)
        return percent > 0 ? percent : nil
    }
}

private extension StoreProduct {
    var id: String { productIdentifier }

    /// Durée exprimée en mois, quand ça a un sens. Une offre hebdomadaire n'en a pas.
    var monthCount: Int? {
        guard let period = subscriptionPeriod else { return nil }
        switch period.unit {
        case .month: return period.value
        case .year: return period.value * 12
        case .day, .week: return nil
        @unknown default: return nil
        }
    }

    var monthlyPrice: Decimal? {
        guard let months = monthCount, months > 0 else { return nil }
        return price / Decimal(months)
    }

    /// L'essai n'existe que si l'offre d'introduction en est un : une remise
    /// d'introduction payante n'est pas gratuite.
    var freeTrialLabel: String? {
        guard let discount = introductoryDiscount, discount.paymentMode == .freeTrial else { return nil }
        return discount.subscriptionPeriod.frenchLabel
    }

    /// Formate dans la devise du produit, sans jamais inventer de symbole.
    func formatted(_ amount: Decimal) -> String? {
        priceFormatter?.string(from: amount as NSDecimalNumber)
    }
}

extension SubscriptionPeriod {
    /// « 1 mois », « 1 an », « 1 semaine ». Le pluriel suit la valeur, et « mois »
    /// est invariable.
    var frenchLabel: String {
        switch unit {
        case .day: return "\(value) jour\(value > 1 ? "s" : "")"
        case .week: return "\(value) semaine\(value > 1 ? "s" : "")"
        case .month: return "\(value) mois"
        case .year: return value == 1 ? "1 an" : "\(value) ans"
        @unknown default: return "\(value)"
        }
    }
}
