import XCTest
@testable import ZincShop

@MainActor
final class OrderCoordinatorTests: XCTestCase {
    private let shipping = ShippingProfile()

    // The price cap is the spending safety net shared by the in-app and the
    // headless Siri order paths. It must throw before any network call or
    // biometric prompt, so this needs no stubbing.
    func testPurchaseThrowsWhenProductExceedsPriceCap() async {
        let coord = OrderCoordinator()
        let pricey = Product(url: "x", title: "Pricey", priceCents: 5_000,
                             imageURL: nil, retailer: "amazon")
        do {
            _ = try await coord.purchase(product: pricey, quantity: 1,
                                         shipping: shipping, maxPriceCents: 2_000)
            XCTFail("Expected overPriceCap to be thrown")
        } catch let PaymentError.overPriceCap(amount, cap) {
            XCTAssertEqual(amount, 5_000)
            XCTAssertEqual(cap, 2_000)
        } catch {
            XCTFail("Wrong error: \(error)")
        }
    }

    // A retried order (Siri re-running perform(), or a double-tap of Pay) within
    // the window must reuse the same idempotency key so the server can dedupe it
    // instead of double-charging; a distinct item or quantity must not collide.
    func testIdempotencyKeyIsStableForSameOrderAndDistinctOtherwise() {
        let a = Product(url: "prod/1", title: "A", priceCents: 100, imageURL: nil, retailer: "amazon")
        let b = Product(url: "prod/2", title: "B", priceCents: 100, imageURL: nil, retailer: "amazon")

        XCTAssertEqual(OrderCoordinator.idempotencyKey(product: a, quantity: 1),
                       OrderCoordinator.idempotencyKey(product: a, quantity: 1),
                       "Same product + quantity within the window must reuse the key")
        XCTAssertNotEqual(OrderCoordinator.idempotencyKey(product: a, quantity: 1),
                          OrderCoordinator.idempotencyKey(product: b, quantity: 1),
                          "Different product must get a different key")
        XCTAssertNotEqual(OrderCoordinator.idempotencyKey(product: a, quantity: 1),
                          OrderCoordinator.idempotencyKey(product: a, quantity: 2),
                          "Different quantity must get a different key")
    }
}
