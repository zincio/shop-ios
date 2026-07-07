import Foundation

protocol ProductSearching {
    func search(_ query: String) async throws -> [Product]
}

/// Maps Zinc search responses into `Product`, handling both shapes:
///  - cross-retailer `GET /search` and MPP `GET /agent/search`: items carry a
///    `url` and per-item `retailer`.
///  - retailer-specific `GET /products/search`: items carry a `product_id`
///    (e.g. an Amazon ASIN) and no `retailer`; the URL is derived from
///    `defaultRetailer` + `product_id`.
/// Decodes defensively; items missing an id/title are skipped, and anything
/// unmappable yields an empty list (→ fallback).
enum SearchResponseMapper {
    static func products(from data: Data, defaultRetailer: String = "amazon") -> [Product] {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rawList = root["results"] as? [[String: Any]]
        else { return [] }
        return rawList.compactMap { item in
            guard let title = item["title"] as? String else { return nil }
            let retailer = (item["retailer"] as? String) ?? defaultRetailer
            let url: String
            if let u = item["url"] as? String {
                url = u
            } else if let pid = item["product_id"] as? String {
                url = productURL(pid, retailer: retailer)
            } else {
                return nil
            }
            let cents = (item["price"] as? Int) ?? Int((item["price"] as? Double ?? 0) * 100)
            let image = (item["image"] as? String).flatMap(URL.init(string:))
            return Product(url: url, title: title, priceCents: cents,
                           imageURL: image, retailer: retailer)
        }
    }

    /// Build an orderable product URL from a retailer product id.
    static func productURL(_ productID: String, retailer: String) -> String {
        switch retailer.lowercased() {
        case "walmart": return "https://www.walmart.com/ip/\(productID)"
        default:        return "https://www.amazon.com/dp/\(productID)"
        }
    }
}

/// Demo catalog with real Amazon product URLs so the Siri → confirm → pay flow
/// works without depending on the live (metered) search endpoint. Replace with
/// live search results in production.
struct MockCatalog: ProductSearching {
    // Titles are short, speakable category names. They double as the values Siri
    // learns for the AppEntity phrase parameter (from `suggestedEntities`), so a
    // spoken "order paper towels on Zinc" resolves to an item. Long marketing
    // names here would break voice matching.
    static let items: [Product] = [
        Product(url: "https://www.amazon.com/dp/B01N5IB20Q",
                title: "Toilet Paper", priceCents: 2399,
                imageURL: nil, retailer: "amazon"),
        Product(url: "https://www.amazon.com/dp/B00OFM4RHA",
                title: "Paper Towels", priceCents: 1997,
                imageURL: nil, retailer: "amazon"),
        Product(url: "https://www.amazon.com/dp/B07GR4Y4Y8",
                title: "Coffee", priceCents: 1499,
                imageURL: nil, retailer: "amazon"),
        Product(url: "https://www.amazon.com/dp/B00DBA92RC",
                title: "Laundry Detergent", priceCents: 1294,
                imageURL: nil, retailer: "amazon"),
        Product(url: "https://www.amazon.com/dp/B07JGBW826",
                title: "Dish Soap", priceCents: 399,
                imageURL: nil, retailer: "amazon"),
    ]

    func search(_ query: String) async throws -> [Product] {
        let q = query.lowercased()
        // Return matches ranked by overlap; no match -> empty (so an unknown
        // spoken product reports "not found" rather than the wrong item). Live
        // Zinc search covers arbitrary products; the mock covers its own list.
        return Self.items
            .map { (item: $0, score: Self.score($0.title.lowercased(), against: q)) }
            .filter { $0.score > 0 }
            .sorted { $0.score > $1.score }
            .map(\.item)
    }

    private static func score(_ title: String, against query: String) -> Int {
        let words = query.split(separator: " ").map(String.init)
        return words.reduce(0) { $0 + (title.contains($1) ? 1 : 0) }
    }
}
