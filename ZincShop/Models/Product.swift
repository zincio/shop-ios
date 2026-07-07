import Foundation

/// A purchasable product surfaced by search. `url` is the retailer product URL
/// that Zinc's `/agent/orders` endpoint expects.
struct Product: Identifiable, Codable, Hashable {
    var id: String { url }
    let url: String
    let title: String
    let priceCents: Int
    let imageURL: URL?
    let retailer: String
    // Optional (default nil) so existing call sites and persisted data still
    // decode; populated from search results.
    var brand: String? = nil
    var stars: Double? = nil
    var numReviews: Int? = nil

    var priceFormatted: String {
        (Double(priceCents) / 100).formatted(.currency(code: "USD"))
    }
}
