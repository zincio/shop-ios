import Foundation
import Combine

/// A purchase chosen via Siri but not yet paid for. The intent stashes this and
/// opens the app, which presents Apple Pay to complete it (Apple Pay = Face ID).
struct PendingPurchase: Codable, Equatable, Identifiable {
    let product: Product
    let quantity: Int
    var id: String { product.url }
}

/// App-wide observable state, persisted to UserDefaults as JSON.
/// (Real keys/cards never live here — MPP keeps them off-device.)
@MainActor
final class ProfileStore: ObservableObject {
    static let shared = ProfileStore()

    @Published var hasOnboarded: Bool { didSet { defaults.set(hasOnboarded, forKey: "hasOnboarded") } }
    @Published var shipping: ShippingProfile { didSet { persist(\.shipping, "shipping") } }
    @Published var orders: [OrderRecord] { didSet { persist(\.orders, "orders") } }
    @Published var priceCapCents: Int { didSet { defaults.set(priceCapCents, forKey: "priceCap") } }
    /// When on, orders are sent with max_price = 0 so they never finalize —
    /// safe for testing the order plumbing without a real purchase.
    @Published var devMode: Bool { didSet { defaults.set(devMode, forKey: "devMode") } }
    @Published var recentSearches: [String] {
        didSet { defaults.set(recentSearches, forKey: "recentSearches") }
    }
    /// The user's own Zinc API key. Mirrored to the Keychain (not the UserDefaults
    /// blob) since it's a live credential; an empty value means "fall back to the
    /// bundled dev key" (see `ZincCredentials`).
    @Published var zincApiKey: String { didSet { ZincCredentials.setUserApiKey(zincApiKey) } }
    @Published var pendingPurchase: PendingPurchase? {
        didSet {
            // Remove the key when nil instead of persisting `null` (which would
            // fail to decode on next load).
            if let pending = pendingPurchase, let data = try? JSONEncoder().encode(pending) {
                defaults.set(data, forKey: "pending")
            } else {
                defaults.removeObject(forKey: "pending")
            }
        }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.hasOnboarded = defaults.bool(forKey: "hasOnboarded")
        self.shipping = Self.load(ShippingProfile.self, "shipping", defaults) ?? ShippingProfile()
        self.orders = Self.load([OrderRecord].self, "orders", defaults) ?? []
        let cap = defaults.integer(forKey: "priceCap")
        self.priceCapCents = cap == 0 ? 5000 : cap   // default $50 cap
        self.devMode = defaults.bool(forKey: "devMode")
        self.recentSearches = defaults.stringArray(forKey: "recentSearches") ?? []
        self.zincApiKey = ZincCredentials.userApiKey
        self.pendingPurchase = Self.load(PendingPurchase.self, "pending", defaults)
    }

    /// Record a search term (most-recent-first, deduped, capped).
    func addRecentSearch(_ query: String) {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return }
        var list = recentSearches.filter { $0.caseInsensitiveCompare(term) != .orderedSame }
        list.insert(term, at: 0)
        recentSearches = Array(list.prefix(8))
    }

    func upsert(_ order: OrderRecord) {
        if let i = orders.firstIndex(where: { $0.id == order.id }) { orders[i] = order }
        else { orders.insert(order, at: 0) }
    }

    // MARK: Persistence helpers

    private func persist<T: Encodable>(_ keyPath: KeyPath<ProfileStore, T>, _ key: String) {
        if let data = try? JSONEncoder().encode(self[keyPath: keyPath]) {
            defaults.set(data, forKey: key)
        }
    }

    private static func load<T: Decodable>(_ type: T.Type, _ key: String,
                                           _ defaults: UserDefaults) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}
