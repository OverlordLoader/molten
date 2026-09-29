import StoreKit

/// StoreKit 2 in-app purchases. All billing goes through Apple — no web
/// links, no external payment providers (App Store review requirement).
///
/// Products (create these EXACTLY in App Store Connect — IDs must match):
/// - app.molten.studio.removeads            non-consumable  $4.99  "Remove Ads"
/// - app.molten.studio.colorpack.aurora      non-consumable  $1.99  "Aurora Pack"
/// - app.molten.studio.colorpack.inferno     non-consumable  $1.99  "Inferno Pack"
/// - app.molten.studio.colorpack.abyss       non-consumable  $1.99  "Abyss Pack"
@MainActor
final class StoreManager: ObservableObject {
    static let removeAdsID = "app.molten.studio.removeads"

    private static let allIDs: [String] =
        [removeAdsID] + ColorPack.allCases.map(\.productID)

    private static let purchasedKey = "molten.purchased.v1"
    private static let adUnlockedColorKey = "molten.adUnlockedColor.v1"

    enum StoreError: LocalizedError {
        case unverified
        case productNotFound

        var errorDescription: String? {
            switch self {
            case .unverified: return "The purchase couldn't be verified. Please try again."
            case .productNotFound: return "Product not available right now."
            }
        }
    }

    // MARK: - Published state

    @Published private(set) var products: [Product] = []
    @Published private(set) var purchasedIDs: Set<String> = []
    @Published private(set) var isPurchasing = false
    @Published var notice: String?

    /// Single-use unlock from a rewarded ad: the rawValue of a PieceColor
    /// the player may use for their next piece without owning its pack.
    /// Cleared after one use.
    @Published var adUnlockedColorID: String?

    var isRemoveAdsPurchased: Bool { purchasedIDs.contains(Self.removeAdsID) }

    func isPackOwned(_ pack: ColorPack) -> Bool {
        purchasedIDs.contains(pack.productID)
    }

    /// True if the color can currently be picked in the Studio.
    func isColorAvailable(_ color: PieceColor) -> Bool {
        guard let pack = color.pack else { return true } // base colors: always
        return isPackOwned(pack) || adUnlockedColorID == color.rawValue
    }

    /// Consume the single-use ad unlock (called when the piece is started).
    func consumeAdUnlock(for color: PieceColor) {
        if adUnlockedColorID == color.rawValue {
            adUnlockedColorID = nil
            UserDefaults.standard.removeObject(forKey: Self.adUnlockedColorKey)
        }
    }

    func product(for id: String) -> Product? {
        products.first { $0.id == id }
    }

    func priceString(for id: String, fallback: String) -> String {
        product(for: id)?.displayPrice ?? fallback
    }

    // MARK: - Lifecycle

    private var transactionListener: Task<Void, Never>?

    /// Call once at app launch: restores entitlements, fetches products,
    /// and starts listening for transactions (refunds, family sharing, etc).
    func load() async {
        adUnlockedColorID = UserDefaults.standard.string(forKey: Self.adUnlockedColorKey)
        if let saved = UserDefaults.standard.array(forKey: Self.purchasedKey) as? [String] {
            purchasedIDs = Set(saved) // fast local cache; entitlements refresh below
        }
        listenForTransactions()
        await refreshEntitlements()
        await requestProducts()
    }

    func requestProducts() async {
        do {
            products = try await Product.products(for: Self.allIDs)
        } catch {
            #if DEBUG
            print("[Store] product request failed: \(error.localizedDescription)")
            #endif
            // Products simply show fallback prices; purchase buttons retry.
        }
    }

    // MARK: - Purchase

    func purchase(productID: String) async {
        guard let product = product(for: productID) else {
            // Products may not have loaded (offline / App Store hiccup) —
            // try once more before giving up.
            await requestProducts()
            guard let retry = product(for: productID) else {
                notice = StoreError.productNotFound.localizedDescription
                return
            }
            await purchase(retry)
            return
        }
        await purchase(product)
    }

    func purchase(_ product: Product) async {
        guard !isPurchasing else { return }
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checked(verification)
                purchasedIDs.insert(transaction.productID)
                persistPurchased()
                await transaction.finish()
                Haptics.success()
            case .userCancelled:
                break // no notice — cancelling is a normal choice
            case .pending:
                notice = "Purchase is pending approval (e.g. Ask to Buy). It will unlock automatically once approved."
            @unknown default:
                break
            }
        } catch {
            notice = error.localizedDescription
        }
    }

    /// Apple's required "Restore Purchases" — also picks up refunds,
    /// family-shared purchases, and purchases made on other devices.
    func restore() async {
        do {
            try await AppStore.sync()
        } catch {
            // sync() throws if the user cancels sign-in; entitlements below
            // still refresh from whatever is on device.
        }
        await refreshEntitlements()
        await requestProducts()
        notice = purchasedIDs.isEmpty
            ? "No previous purchases found for this Apple ID."
            : "Purchases restored."
    }

    // MARK: - Verification & entitlements

    private func checked<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let safe): return safe
        case .unverified: throw StoreError.unverified
        }
    }

    /// Authoritative source of truth: current App Store entitlements.
    private func refreshEntitlements() async {
        var ids = Set<String>()
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checked(result)
                // Non-consumables: any non-revoked, non-refunded transaction counts.
                if transaction.revocationDate == nil {
                    ids.insert(transaction.productID)
                }
            } catch {
                #if DEBUG
                print("[Store] unverified entitlement skipped")
                #endif
            }
        }
        purchasedIDs = ids
        persistPurchased()
    }

    private func listenForTransactions() {
        transactionListener?.cancel()
        transactionListener = Task.detached { [weak self] in
            for await result in Transaction.updates {
                await self?.handleUpdate(result)
            }
        }
    }

    private func handleUpdate(_ result: VerificationResult<StoreKit.Transaction>) async {
        do {
            let transaction = try checked(result)
            if transaction.revocationDate == nil {
                purchasedIDs.insert(transaction.productID)
            } else {
                purchasedIDs.remove(transaction.productID) // refunded / revoked
            }
            persistPurchased()
            await transaction.finish()
        } catch {
            #if DEBUG
            print("[Store] unverified transaction update skipped")
            #endif
        }
    }

    private func persistPurchased() {
        UserDefaults.standard.set(Array(purchasedIDs), forKey: Self.purchasedKey)
    }

    // MARK: - Rewarded-ad color unlock

    func grantAdColorUnlock(_ color: PieceColor) {
        adUnlockedColorID = color.rawValue
        UserDefaults.standard.set(color.rawValue, forKey: Self.adUnlockedColorKey)
    }
}
