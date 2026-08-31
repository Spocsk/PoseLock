import Foundation
import StoreKit

enum StoreProductID: String, CaseIterable {
    case monthly = "poselock.pro.monthly"
    case prep = "poselock.pro.prep"
}

@MainActor
@Observable
final class StoreManager {
    private(set) var isPro = false
    private(set) var products: [Product] = []
    private(set) var purchaseError: String?
    private(set) var isLoading = false

    private var updatesTask: Task<Void, Never>?

    func load() async {
        updatesTask?.cancel()
        updatesTask = Task { await listenForUpdates() }
        await refreshProducts()
        await refreshEntitlements()
    }

    func refreshProducts() async {
        do {
            let ids = StoreProductID.allCases.map(\.rawValue)
            products = try await Product.products(for: ids).sorted { $0.price < $1.price }
        } catch {
            purchaseError = "Impossible de charger les offres."
        }
    }

    func purchase(_ product: Product) async {
        isLoading = true
        purchaseError = nil
        defer { isLoading = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                await refreshEntitlements()
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            purchaseError = "Achat impossible. Réessaie."
        }
    }

    func restore() async {
        isLoading = true
        purchaseError = nil
        defer { isLoading = false }
        do {
            try await AppStore.sync()
            await refreshEntitlements()
        } catch {
            purchaseError = "Restauration impossible."
        }
    }

    func refreshEntitlements() async {
        var entitled = false
        for await entitlement in Transaction.currentEntitlements {
            if let transaction = try? checkVerified(entitlement),
               StoreProductID(rawValue: transaction.productID) != nil,
               transaction.revocationDate == nil {
                entitled = true
            }
        }
        isPro = entitled
    }

    private func listenForUpdates() async {
        for await update in Transaction.updates {
            if let transaction = try? checkVerified(update) {
                await transaction.finish()
                await refreshEntitlements()
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let value):
            return value
        }
    }

    func product(for id: StoreProductID) -> Product? {
        products.first { $0.id == id.rawValue }
    }
}
