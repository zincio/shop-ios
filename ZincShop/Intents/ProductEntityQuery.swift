import AppIntents

/// Resolves spoken/typed text and identifiers to `ProductEntity` values.
/// `EntityStringQuery` is what lets an App Shortcut phrase accept an arbitrary
/// product: Siri passes the words it heard to `entities(matching:)`, which runs
/// a product search. Coverage is whatever search returns — the full catalog once
/// live Zinc search is enabled, or `MockCatalog` in this prototype.
struct ProductEntityQuery: EntityStringQuery {
    /// Resolve arbitrary spoken/typed text (the App Shortcut parameter path).
    func entities(matching string: String) async throws -> [ProductEntity] {
        let products = try await ZincClient().search(string)
        await ProductEntityCache.shared.store(products)
        return products.map(ProductEntity.init)
    }

    /// Re-resolve a previously chosen entity by its id (URL).
    func entities(for identifiers: [String]) async throws -> [ProductEntity] {
        var out: [ProductEntity] = []
        for id in identifiers {
            if let product = await ProductEntityCache.shared.product(for: id) {
                out.append(ProductEntity(product))
            }
        }
        return out
    }

    /// Intentionally empty so the Shortcuts/Siri value picker opens straight to
    /// its search field (which drives `entities(matching:)` → live Zinc search)
    /// rather than presenting a canned list of demo products. Arbitrary spoken or
    /// typed products still resolve via `entities(matching:)`.
    func suggestedEntities() async throws -> [ProductEntity] {
        []
    }
}

/// Small id→Product cache so `entities(for:)` can resolve an entity Siri chose
/// from a prior `entities(matching:)` call. Seeded with the demo catalog.
actor ProductEntityCache {
    static let shared = ProductEntityCache()
    private var byID: [String: Product]

    init() {
        byID = Dictionary(uniqueKeysWithValues: MockCatalog.items.map { ($0.url, $0) })
    }

    func store(_ products: [Product]) {
        for p in products { byID[p.url] = p }
    }

    func product(for id: String) -> Product? { byID[id] }
}
