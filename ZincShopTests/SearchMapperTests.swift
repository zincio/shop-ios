import XCTest
@testable import ZincShop

final class SearchMapperTests: XCTestCase {
    // Shape from Zinc's cross-retailer search docs.
    private let sample = """
    {
      "status": "completed",
      "query": "cast iron skillet",
      "results": [
        {
          "url": "https://www.wayfair.com/cookware/pdp/lodge-cast-iron-skillet",
          "retailer": "wayfair",
          "title": "Lodge Cast Iron Skillet 6.5\\" Pre-Seasoned",
          "image": "https://example.com/img.jpg",
          "brand": null,
          "price": 1890,
          "stars": 4.7,
          "num_reviews": 1000,
          "available": null
        },
        { "retailer": "amazon", "price": 999 }
      ]
    }
    """.data(using: .utf8)!

    func testMapsResultsAndSkipsIncompleteItems() {
        let products = SearchResponseMapper.products(from: sample)
        // Second item has no url/title → skipped.
        XCTAssertEqual(products.count, 1)
        let p = products[0]
        XCTAssertEqual(p.url, "https://www.wayfair.com/cookware/pdp/lodge-cast-iron-skillet")
        XCTAssertEqual(p.title, "Lodge Cast Iron Skillet 6.5\" Pre-Seasoned")
        XCTAssertEqual(p.priceCents, 1890)
        XCTAssertEqual(p.retailer, "wayfair")
        XCTAssertNotNil(p.imageURL)
    }

    // Shape from Zinc's retailer-specific /products/search (product_id, no url).
    private let productSearchSample = """
    {
      "status": "success",
      "results": [
        { "product_id": "B0123456789", "title": "Dell XPS 13 Laptop",
          "image": "https://example.com/x.jpg", "price": 99999, "prime": true }
      ],
      "next_page": 2
    }
    """.data(using: .utf8)!

    func testMapsProductIdToRetailerURL() {
        let products = SearchResponseMapper.products(from: productSearchSample, defaultRetailer: "amazon")
        XCTAssertEqual(products.count, 1)
        XCTAssertEqual(products[0].url, "https://www.amazon.com/dp/B0123456789")
        XCTAssertEqual(products[0].retailer, "amazon")
        XCTAssertEqual(products[0].priceCents, 99999)
        XCTAssertEqual(products[0].title, "Dell XPS 13 Laptop")
    }

    func testWalmartProductIdURL() {
        XCTAssertEqual(SearchResponseMapper.productURL("55049252", retailer: "walmart"),
                       "https://www.walmart.com/ip/55049252")
    }

    func testEmptyOrJunkYieldsNoProducts() {
        XCTAssertTrue(SearchResponseMapper.products(from: Data("{}".utf8)).isEmpty)
        XCTAssertTrue(SearchResponseMapper.products(from: Data("not json".utf8)).isEmpty)
        XCTAssertTrue(SearchResponseMapper.products(
            from: Data(#"{"results":[]}"#.utf8)).isEmpty)
    }
}
