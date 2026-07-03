import XCTest
@testable import ZincShop

final class CatalogSearchTests: XCTestCase {
    func testRanksMatchingItemFirst() async throws {
        let results = try await MockCatalog().search("toilet paper")
        XCTAssertEqual(results.first?.title.lowercased().contains("toilet"), true)
    }

    func testReturnsEmptyForNoMatch() async throws {
        let results = try await MockCatalog().search("zzz-nonexistent-item")
        XCTAssertTrue(results.isEmpty, "Unknown query should return no matches, not the wrong item")
    }

    func testPaperTowelsMatch() async throws {
        let results = try await MockCatalog().search("paper towels")
        XCTAssertTrue(results.first?.title.lowercased().contains("towel") ?? false)
    }
}
