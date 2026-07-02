import Foundation
import Combine

/// A purchase chosen via Siri but not yet paid for. The intent stashes this and
/// opens the app, which presents Apple Pay to complete it (Apple Pay = Face ID).
struct PendingPurchase: Codable, Equatable {
    let product: Product
    let quantity: Int
}

/// App-wide observable state, persisted to UserDefaults as JSON.
/// (Real keys/cards never live here — MPP keeps them off-device.)
@MainActor
final class ProfileStore: ObservableObject {
    static let shared = ProfileStore()

    @Published var shipping: ShippingProfile { didSet { persist(\.shipping, "shipping") } }
    @Published var orders: [OrderRecord] { didSet { persist(\.orders, "orders") } }
    @Published var priceCapCents: Int { didSet { defaults.set(priceCapCents, forKey: "priceCap") } }
    @Published var pendingPurchase: PendingPurchase? {
        didSet { persist(\.pendingPurchase, "pending") }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.shipping = Self.load(ShippingProfile.self, "shipping", defaults) ?? ShippingProfile()
        self.orders = Self.load([OrderRecord].self, "orders", defaults) ?? []
        let cap = defaults.integer(forKey: "priceCap")
        self.priceCapCents = cap == 0 ? 5000 : cap   // default $50 cap
        self.pendingPurchase = Self.load(PendingPurchase.self, "pending", defaults)
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
