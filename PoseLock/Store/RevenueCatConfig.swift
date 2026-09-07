import Foundation

/// Le catalogue Pro vit chez RevenueCat : prix, période d'essai et paywall se
/// changent depuis le dashboard, sans build. Ne restent ici que les identifiants
/// qui font le lien entre l'app et le projet distant.
enum RevenueCatConfig {
    /// Une faute de frappe ici ne casse rien à la compilation : elle ferme Pro à
    /// tout le monde, en silence.
    static let proEntitlement = "pro"

    /// Le paywall publié est attaché à cet offering côté dashboard.
    static let defaultOffering = "default"

    /// Clé publique SDK, jamais la clé secrète. En debug, le Test Store : il rend
    /// les prix dans le simulateur sans passer par l'App Store. En release, la clé
    /// `appl_` de l'app App Store Connect, absente jusqu'au compte payant — d'où
    /// la lecture dans `Info.plist` plutôt qu'une constante à remplacer.
    static var apiKey: String {
        #if DEBUG
        return "test_qzbgtpPkyssgCzmLkgrJMqyTYaq"
        #else
        let key = Bundle.main.object(forInfoDictionaryKey: "RCPublicAPIKey") as? String
        return key ?? ""
        #endif
    }

    /// Sans clé, le SDK ne peut pas être configuré : le paywall tombe alors sur sa
    /// sortie de secours au lieu d'afficher un écran vide.
    static var isConfigured: Bool { !apiKey.isEmpty }
}

/// Les prix ne viennent plus de là, mais les identifiants doivent rester alignés
/// entre `Products.storekit`, App Store Connect et le catalogue RevenueCat.
/// `StoreConfigurationTests` tient les deux premiers bouts.
enum ProProductID: String, CaseIterable {
    case monthly = "poselock.pro.monthly"
    case yearly = "poselock.pro.yearly"
}
