import Foundation

protocol ProductSearching {
    func search(_ query: String) async throws -> [Product]
}

/// Best-effort mapper for the live agent-search response. The exact schema is
/// unverified in this prototype, so we decode defensively and tolerate missing
/// fields; anything unmappable yields an empty list and triggers the fallback.
enum SearchResponseMapper {
    static func products(from data: Data, retailer: String) -> [Product] {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return [] }
        let rawList = (root["results"] as? [[String: Any]])
            ?? (root["products"] as? [[String: Any]])
            ?? []
        return rawList.compactMap { item in
            guard let url = (item["url"] as? String) ?? (item["product_url"] as? String),
                  let title = (item["title"] as? String) ?? (item["name"] as? String)
            else { return nil }
            let cents = (item["price"] as? Int)
                ?? Int((item["price"] as? Double ?? 0) * 100)
            let img = (item["image"] as? String) ?? (item["image_url"] as? String)
            return Product(url: url, title: title, priceCents: cents,
                           imageURL: img.flatMap(URL.init(string:)), retailer: retailer)
        }
    }
}

/// Demo catalog with real Amazon product URLs so the Siri → confirm → pay flow
/// works without depending on the live (metered) search endpoint. Replace with
/// live search results in production.
struct MockCatalog: ProductSearching {
    static let items: [Product] = [
        Product(url: "https://www.amazon.com/dp/B01N5IB20Q",
                title: "Amazon Brand Toilet Paper, 30 Rolls",
                priceCents: 2399,
                imageURL: nil, retailer: "amazon"),
        Product(url: "https://www.amazon.com/dp/B00OFM4RHA",
                title: "Bounty Quick-Size Paper Towels, 8 Family Rolls",
                priceCents: 1997,
                imageURL: nil, retailer: "amazon"),
        Product(url: "https://www.amazon.com/dp/B07GR4Y4Y8",
                title: "AmazonFresh Colombia Whole Bean Coffee, 32 oz",
                priceCents: 1499,
                imageURL: nil, retailer: "amazon"),
        Product(url: "https://www.amazon.com/dp/B00DBA92RC",
                title: "Tide Liquid Laundry Detergent, 64 loads",
                priceCents: 1294,
                imageURL: nil, retailer: "amazon"),
        Product(url: "https://www.amazon.com/dp/B07JGBW826",
                title: "Dish Soap, 28 fl oz",
                priceCents: 399,
                imageURL: nil, retailer: "amazon"),
    ]

    func search(_ query: String) async throws -> [Product] {
        let q = query.lowercased()
        let scored = Self.items
            .map { (item: $0, score: Self.score($0.title.lowercased(), against: q)) }
            .filter { $0.score > 0 }
            .sorted { $0.score > $1.score }
            .map(\.item)
        // Always return *something* so a demo voice query never dead-ends.
        return scored.isEmpty ? Array(Self.items.prefix(1)) : scored
    }

    private static func score(_ title: String, against query: String) -> Int {
        let words = query.split(separator: " ").map(String.init)
        return words.reduce(0) { $0 + (title.contains($1) ? 1 : 0) }
    }
}
