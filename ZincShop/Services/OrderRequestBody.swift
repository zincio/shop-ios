import Foundation

/// JSON body for `POST /agent/orders`. The same body is sent twice: once
/// unauthenticated (to receive the 402 challenge) and once with the MPP payment
/// credential attached. The `idempotency_key` makes the retry safe.
struct OrderRequestBody: Codable, Equatable {
    let products: [Item]
    let shippingAddress: Address
    let maxPrice: Int
    let idempotencyKey: String
    let isGift: Bool

    struct Item: Codable, Equatable {
        let url: String
        let quantity: Int
    }

    struct Address: Codable, Equatable {
        let firstName: String
        let lastName: String
        let addressLine1: String
        let addressLine2: String?
        let city: String
        let state: String
        let postalCode: String
        let country: String
        let phoneNumber: String

        enum CodingKeys: String, CodingKey {
            case firstName = "first_name"
            case lastName = "last_name"
            case addressLine1 = "address_line1"
            case addressLine2 = "address_line2"
            case city, state, country
            case postalCode = "postal_code"
            case phoneNumber = "phone_number"
        }
    }

    enum CodingKeys: String, CodingKey {
        case products
        case shippingAddress = "shipping_address"
        case maxPrice = "max_price"
        case idempotencyKey = "idempotency_key"
        case isGift = "is_gift"
    }

    init(product: Product, quantity: Int, shipping: ShippingProfile,
         maxPriceCents: Int, idempotencyKey: String) {
        self.products = [Item(url: product.url, quantity: quantity)]
        self.shippingAddress = Address(
            firstName: shipping.firstName,
            lastName: shipping.lastName,
            addressLine1: shipping.addressLine1,
            addressLine2: shipping.addressLine2.isEmpty ? nil : shipping.addressLine2,
            city: shipping.city,
            state: shipping.state,
            postalCode: shipping.postalCode,
            country: shipping.country,
            phoneNumber: shipping.phoneNumber
        )
        self.maxPrice = maxPriceCents
        self.idempotencyKey = idempotencyKey
        self.isGift = false
    }
}
