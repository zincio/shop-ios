import AppIntents

/// Shared mapping so every entry point (typed/spoken query, visual search)
/// shapes results identically.
///
/// Order is **preserved** from search: the Zinc API ranks results by relevance,
/// so its first item is the best match for the query. Re-sorting here (e.g. by
/// price) put a cheap accessory above the actual product and made the Siri
/// disambiguation list jump around between calls — so we keep the API's order.
enum ProductEntityMapping {
    static func entities(from products: [Product]) -> [ProductEntity] {
        products.map(ProductEntity.init)
    }
}

/// Resolves spoken/typed text and identifiers to `ProductEntity` values.
/// `EntityStringQuery` is what lets an App Shortcut phrase accept an arbitrary
/// product: Siri passes the words it heard to `entities(matching:)`, which runs
/// a product search. Coverage is whatever search returns — the full catalog once
/// live Zinc search is enabled, or `MockCatalog` in this prototype.
struct ProductEntityQuery: EntityStringQuery {
    /// Resolve arbitrary spoken/typed text (the App Shortcut parameter path).
    /// Kept in the search API's relevance order so the Shortcuts/Siri picker
    /// lists the best-matching product first (see `ProductEntityMapping`).
    func entities(matching string: String) async throws -> [ProductEntity] {
        // Keep resolution resilient: a thrown search error (rejected key, network
        // blip) must NOT bubble up to Siri, which reacts by abandoning the
        // headless flow (and can bounce into the app). Return no matches instead
        // — the in-app search screen is where a bad key is surfaced to the user.
        let products = (try? await ZincClient().search(string)) ?? []
        await ProductEntityCache.shared.store(products)
        return ProductEntityMapping.entities(from: products)
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
