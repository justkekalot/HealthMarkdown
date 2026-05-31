import Foundation
import StoreKit
import Combine

/// Owns the one-time unlock purchase via StoreKit 2.
///
/// Model: the first export is free (forever). After that, generating requires a
/// single non-consumable purchase — pay once, unlock all exports forever. No
/// subscriptions. The free-export-used flag lives in UserDefaults; the unlock is
/// the source of truth from the App Store (restored across reinstalls).
@MainActor
final class PurchaseManager: ObservableObject {
    /// The non-consumable product id (configure in App Store Connect / .storekit).
    static let unlockProductID = "app.escrime.healthmarkdown.unlock"

    @Published private(set) var isUnlocked = false
    @Published private(set) var product: Product?
    @Published private(set) var purchaseInFlight = false
    @Published var lastError: String?

    private var updatesTask: Task<Void, Never>?

    /// The free tier: Quick export over the last 24 hours, always available.
    /// Everything else (Full, or any longer/custom window) requires the unlock.
    static func isFreeCombo(mode: ExportMode, range: DateRangeOption) -> Bool {
        mode == .quick && range == .last24Hours
    }

    /// Can the user generate this specific combo right now?
    func canExport(mode: ExportMode, range: DateRangeOption) -> Bool {
        isUnlocked || Self.isFreeCombo(mode: mode, range: range)
    }

    /// Price string for UI, e.g. "$4.99". Nil until the product loads.
    var priceText: String? { product?.displayPrice }

    init() {
        updatesTask = listenForTransactions()
        Task {
            await refreshEntitlements()
            await loadProduct()
        }
    }

    deinit { updatesTask?.cancel() }

    // MARK: - Loading

    func loadProduct() async {
        do {
            let products = try await Product.products(for: [Self.unlockProductID])
            product = products.first
        } catch {
            lastError = "Couldn't load the store. Check your connection and try again."
        }
    }

    /// Re-check whether the unlock is owned (current entitlements).
    func refreshEntitlements() async {
        var owned = false
        for await result in Transaction.currentEntitlements {
            if case let .verified(transaction) = result,
               transaction.productID == Self.unlockProductID,
               transaction.revocationDate == nil {
                owned = true
            }
        }
        isUnlocked = owned
    }

    // MARK: - Purchase / restore

    func purchase() async {
        guard let product else {
            await loadProduct()
            guard product != nil else { return }
            return await purchase()
        }
        purchaseInFlight = true
        defer { purchaseInFlight = false }
        do {
            let result = try await product.purchase()
            switch result {
            case let .success(verification):
                if case let .verified(transaction) = verification {
                    isUnlocked = true
                    await transaction.finish()
                }
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            lastError = "Purchase failed. You weren't charged — try again."
        }
    }

    func restore() async {
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            if !isUnlocked {
                lastError = "No previous purchase found on this Apple ID."
            }
        } catch {
            lastError = "Couldn't restore purchases. Try again."
        }
    }

    // MARK: - Transaction updates

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard let self else { continue }
                if case let .verified(transaction) = result {
                    await transaction.finish()
                    await self.refreshEntitlements()
                }
            }
        }
    }
}
