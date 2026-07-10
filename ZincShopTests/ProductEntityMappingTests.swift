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

    func testBreaksPriceTiesByURLDeterministically() {
        let products = [
            Product(url: "zzz", title: "Z", priceCents: 500, imageURL: nil, retailer: "amazon"),
            Product(url: "aaa", title: "A", priceCents: 500, imageURL: nil, retailer: "walmart"),
        ]
        let ids = ProductEntityMapping.entities(from: products).map(\.id)
        XCTAssertEqual(ids, ["aaa", "zzz"])   // equal price → sorted by url
    }
}
