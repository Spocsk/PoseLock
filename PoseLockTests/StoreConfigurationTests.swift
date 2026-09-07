import XCTest
@testable import PoseLock

/// Les prix affichés viennent de RevenueCat, plus de ce fichier. `Products.storekit`
/// reste la description de ce qu'il faudra créer dans App Store Connect, et
/// `ProProductID` la liste des identifiants enregistrés côté RevenueCat : trois
/// catalogues qui doivent porter les mêmes identifiants sans que rien ne le
/// vérifie à la compilation. Ce test tient les deux bouts qu'il peut lire.
final class StoreConfigurationTests: XCTestCase {
    func testConfigurationCoversEveryDeclaredProduct() throws {
        let subscriptions = try loadSubscriptions()
        XCTAssertEqual(
            Set(subscriptions.map(\.productID)),
            Set(ProProductID.allCases.map(\.rawValue))
        )
    }

    func testEverySubscriptionOffersTheSameOneWeekFreeTrial() throws {
        for subscription in try loadSubscriptions() {
            let offer = try XCTUnwrap(
                subscription.introductoryOffer,
                "\(subscription.productID) n’a pas d’offre d’introduction"
            )
            XCTAssertEqual(offer.paymentMode, "free")
            XCTAssertEqual(offer.subscriptionPeriod, "P1W")
            XCTAssertEqual(offer.numberOfPeriods, 1)
        }
    }

    /// Un seul groupe : c'est ce qui autorise le passage mensuel / annuel sans
    /// racheter, et ce qui fait qu'un seul essai gratuit est offert.
    func testSubscriptionsShareASingleGroup() throws {
        let configuration = try loadConfiguration()
        XCTAssertEqual(configuration.subscriptionGroups.count, 1)
        let group = try XCTUnwrap(configuration.subscriptionGroups.first)
        for subscription in group.subscriptions {
            XCTAssertEqual(subscription.subscriptionGroupID, group.id)
        }
    }

    // MARK: - Lecture du fichier

    private struct Configuration: Decodable {
        struct Group: Decodable {
            let id: String
            let subscriptions: [Subscription]
        }

        struct Subscription: Decodable {
            let productID: String
            let subscriptionGroupID: String
            let introductoryOffer: Offer?
        }

        struct Offer: Decodable {
            let paymentMode: String
            let subscriptionPeriod: String
            let numberOfPeriods: Int?
        }

        let subscriptionGroups: [Group]
    }

    private func loadConfiguration() throws -> Configuration {
        let url = try XCTUnwrap(
            Bundle.main.url(forResource: "Products", withExtension: "storekit"),
            "Products.storekit n’est pas embarqué dans l’app"
        )
        return try JSONDecoder().decode(Configuration.self, from: Data(contentsOf: url))
    }

    private func loadSubscriptions() throws -> [Configuration.Subscription] {
        try loadConfiguration().subscriptionGroups.flatMap(\.subscriptions)
    }
}
