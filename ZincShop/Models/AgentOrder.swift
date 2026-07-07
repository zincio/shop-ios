import Foundation

// MARK: - Server response DTOs (decode `/agent/orders` 201 and `GET /orders/{id}`)

/// Mirrors the Zinc agent order JSON. Decoded with an ISO8601 date strategy.
struct AgentOrderDTO: Decodable {
    let id: String
    let status: String
    let maxPrice: Int?
    let items: [Item]
    let trackingNumbers: [String]
    /// Failure reason from `job_result`, if the order didn't complete. Populated
    /// by `ZincClient.decodeOrder` (not part of Codable — job_result's exact
    /// shape varies, so it's parsed leniently from the raw response).
    var jobResultError: String?

    struct Item: Decodable {
        let url: String?
        let quantity: Int?
        let status: String?
    }

    enum CodingKeys: String, CodingKey {
        case id, status, items
        case maxPrice = "max_price"
        case trackingNumbers = "tracking_numbers"
    }

    // `items` / `tracking_numbers` may be missing on partial responses.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        status = try c.decodeIfPresent(String.self, forKey: .status) ?? "pending"
        maxPrice = try c.decodeIfPresent(Int.self, forKey: .maxPrice)
        items = try c.decodeIfPresent([Item].self, forKey: .items) ?? []
        trackingNumbers = try c.decodeIfPresent([String].self, forKey: .trackingNumbers) ?? []
        jobResultError = nil
    }
}

// MARK: - Local domain / persistence model

/// What the app stores and renders. Combines the server order with client-side
/// context (the product we ordered and the order-scoped `X-Api-Key` used to
/// poll status).
struct OrderRecord: Codable, Identifiable, Hashable {
    let id: String
    var status: String
    var trackingNumbers: [String]
    var productTitle: String
    var productImageURL: URL?
    var priceCents: Int
    var createdAt: Date
    /// Order-scoped key returned in the `X-Api-Key` response header.
    var apiKey: String?
    /// Failure reason from `job_result`, shown in the order detail.
    var jobResultError: String?

    init(dto: AgentOrderDTO, product: Product, apiKey: String?, createdAt: Date = Date()) {
        self.id = dto.id
        self.status = dto.status
        self.trackingNumbers = dto.trackingNumbers
        self.productTitle = product.title
        self.productImageURL = product.imageURL
        self.priceCents = product.priceCents
        self.apiKey = apiKey
        self.createdAt = createdAt
        self.jobResultError = dto.jobResultError
    }

    /// Merge a fresh server fetch into the stored record.
    mutating func apply(_ dto: AgentOrderDTO) {
        status = dto.status
        if !dto.trackingNumbers.isEmpty { trackingNumbers = dto.trackingNumbers }
        jobResultError = dto.jobResultError
    }

    var statusDisplay: String { status.replacingOccurrences(of: "_", with: " ").capitalized }

    /// True while the order is still moving toward fulfillment — used to decide
    /// whether to keep polling / running the Live Activity.
    var isInProgress: Bool {
        if jobResultError != nil { return false }
        if !trackingNumbers.isEmpty { return false }
        switch status.lowercased() {
        case "shipped", "delivered", "completed", "cancelled", "canceled", "failed", "error":
            return false
        default:
            return true
        }
    }
}
