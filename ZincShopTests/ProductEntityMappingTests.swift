import XCTest
@testable import ZincShop

final class ProductEntityMappingTests: XCTestCase {
    func testMapsAndSortsCheapestFirst() {
        let products = [
            Product(url: "b", title: "B", priceCents: 900, imageURL: nil, retailer: "amazon"),
            Product(url: "a", title: "A", priceCents: 100, imageURL: nil, retailer: "amazon"),
        ]
        let entities = ProductEntityMapping.entities(from: products)
        XCTAssertEqual(entities.map(\.id), ["a", "b"])
    }
}
