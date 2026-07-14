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
}
