import AppIntents
import Foundation

/// A product exposed to Siri/Shortcuts as an `AppEntity` so it can be parsed
/// inline in a spoken phrase ("Buy AA batteries with Zinc") for ANY product,
/// not just a fixed list. Siri resolves the spoken words through
/// `ProductEntityQuery` (a string query backed by product search).
struct ProductEntity: AppEntity, Identifiable {
    /// The retailer product URL doubles as the stable identifier.
    let id: String
    let title: String
    let priceCents: Int
    let retailer: String
    let imageURL: URL?

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Product")
    static let defaultQuery = ProductEntityQuery()

    var displayRepresentation: DisplayRepresentation {
        let price = (Double(priceCents) / 100).formatted(.currency(code: "USD"))
        let image: DisplayRepresentation.Image? = imageURL.map { .init(url: $0) }
        return priceCents > 0
            ? DisplayRepresentation(title: "\(title)", subtitle: "\(price)", image: image)
            : DisplayRepresentation(title: "\(title)", image: image)
    }

    init(_ product: Product) {
        self.id = product.url
        self.title = product.title
        self.priceCents = product.priceCents
        self.retailer = product.retailer
        self.imageURL = product.imageURL
    }

    /// Convert back to the domain model used by the purchase flow.
    var product: Product {
        Product(url: id, title: title, priceCents: priceCents,
                imageURL: imageURL, retailer: retailer)
    }
}
