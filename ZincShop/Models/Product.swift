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

    var priceFormatted: String {
        (Double(priceCents) / 100).formatted(.currency(code: "USD"))
    }
}
