import XCTest
@testable import ZincShop

final class OrderEncodingTests: XCTestCase {
    private func sampleProduct() -> Product {
        Product(url: "https://www.amazon.com/dp/B01N5IB20Q",
                title: "Toilet Paper", priceCents: 2399, imageURL: nil, retailer: "amazon")
    }

    private func sampleShipping() -> ShippingProfile {
        ShippingProfile(firstName: "Tim", lastName: "Beaver",
                        addressLine1: "77 Massachusetts Avenue", addressLine2: "",
                        city: "Cambridge", state: "MA", postalCode: "02139",
                        country: "US", phoneNumber: "+15551230101")
    }

    func testOrderBodyUsesSnakeCaseKeys() throws {
        let body = OrderRequestBody(product: sampleProduct(), quantity: 2,
                                    shipping: sampleShipping(), maxPriceCents: 3000,
                                    idempotencyKey: "abc-123")
        let data = try JSONEncoder().encode(body)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(json["max_price"] as? Int, 3000)
        XCTAssertEqual(json["idempotency_key"] as? String, "abc-123")
        let products = try XCTUnwrap(json["products"] as? [[String: Any]])
        XCTAssertEqual(products.first?["quantity"] as? Int, 2)
        XCTAssertEqual(products.first?["url"] as? String, sampleProduct().url)

        let addr = try XCTUnwrap(json["shipping_address"] as? [String: Any])
        XCTAssertEqual(addr["first_name"] as? String, "Tim")
        XCTAssertEqual(addr["postal_code"] as? String, "02139")
        XCTAssertEqual(addr["phone_number"] as? String, "+15551230101")
    }

    func testBlankAddressLine2EncodesAsNull() throws {
        let body = OrderRequestBody(product: sampleProduct(), quantity: 1,
                                    shipping: sampleShipping(), maxPriceCents: 3000,
                                    idempotencyKey: "x")
        XCTAssertNil(body.shippingAddress.addressLine2)
    }
}
