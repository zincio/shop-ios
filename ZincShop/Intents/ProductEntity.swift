import AppIntents
import Foundation

/// A product exposed to Siri/Shortcuts as an `AppEntity` so it can be parsed
/// inline in a spoken phrase for ANY product, not just a fixed list. Siri
/// resolves the spoken words through `ProductEntityQuery` (a string query backed
/// by product search) and renders these in its own picker list.
struct ProductEntity: AppEntity, Identifiable {
    /// The retailer product URL doubles as the stable identifier.
    let id: String
    let title: String
    let priceCents: Int
    let retailer: String
    let imageURL: URL?
    let stars: Double?

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Product")
    static let defaultQuery = ProductEntityQuery()

    var displayRepresentation: DisplayRepresentation {
        let image: DisplayRepresentation.Image? = imageURL.map { .init(url: $0) }
        let short = Self.conciseTitle(title)
        let subtitle = subtitleText
        return subtitle.isEmpty
            ? DisplayRepresentation(title: "\(short)", image: image)
            : DisplayRepresentation(title: "\(short)", subtitle: "\(subtitle)", image: image)
    }

    /// "$4.97 · Amazon ★4.5" — price, retailer, then the star rating (unicode ★)
    /// after the retailer when we have one.
    private var subtitleText: String {
        var parts: [String] = []
        if priceCents > 0 {
            parts.append((Double(priceCents) / 100).formatted(.currency(code: "USD")))
        }
        var retailerPart = retailer.capitalized
        if let stars {
            retailerPart += " ★\(stars.formatted(.number.precision(.fractionLength(1))))"
        }
        parts.append(retailerPart)
        return parts.joined(separator: " · ")
    }

    /// Tighten a noisy retailer product name into a short label for the Siri
    /// list. Instant heuristic (an on-device model summary would read nicer but
    /// can't meet a sub-250ms budget across a live list): drop trailing
    /// product-id suffixes and parenthetical notes, collapse whitespace, and cap
    /// the length so the ellipsis lands early and rows stay short.
    static func conciseTitle(_ raw: String) -> String {
        var t = raw
        t = t.replacingOccurrences(of: #"\s*[|\-–]\s*\d{4,}\s*$"#, with: "", options: .regularExpression)
        t = t.replacingOccurrences(of: #"\s*\([^)]*\)"#, with: "", options: .regularExpression)
        t = t.replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
        t = t.trimmingCharacters(in: .whitespacesAndNewlines)
        let maxLength = 28
        if t.count > maxLength {
            t = String(t.prefix(maxLength)).trimmingCharacters(in: .whitespaces) + "…"
        }
        return t
    }

    init(_ product: Product) {
        self.id = product.url
        self.title = product.title
        self.priceCents = product.priceCents
        self.retailer = product.retailer
        self.imageURL = product.imageURL
        self.stars = product.stars
    }

    /// Convert back to the domain model used by the purchase flow.
    var product: Product {
        Product(url: id, title: title, priceCents: priceCents,
                imageURL: imageURL, retailer: retailer, stars: stars)
    }
}
