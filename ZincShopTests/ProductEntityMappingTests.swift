import XCTest
@testable import ZincShop

final class ProductEntityMappingTests: XCTestCase {
    func testPreservesSearchRelevanceOrder() {
        // The Zinc API ranks results by relevance; mapping must not reorder them
        // (a price sort here made the Siri picker's top match jump around).
        let products = [
            Product(url: "b", title: "B", priceCents: 900, imageURL: nil, retailer: "amazon"),
            Product(url: "a", title: "A", priceCents: 100, imageURL: nil, retailer: "amazon"),
        ]
        let entities = ProductEntityMapping.entities(from: products)
        XCTAssertEqual(entities.map(\.id), ["b", "a"])
    }

    func testMapsEveryProductOneToOne() {
        let products = [
            Product(url: "zzz", title: "Z", priceCents: 500, imageURL: nil, retailer: "amazon"),
            Product(url: "aaa", title: "A", priceCents: 500, imageURL: nil, retailer: "walmart"),
        ]
        let ids = ProductEntityMapping.entities(from: products).map(\.id)
        XCTAssertEqual(ids, ["zzz", "aaa"])   // same order in, same order out
    }
}
