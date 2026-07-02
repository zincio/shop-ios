import XCTest
@testable import ZincShop

final class CatalogSearchTests: XCTestCase {
    func testRanksMatchingItemFirst() async throws {
        let results = try await MockCatalog().search("toilet paper")
        XCTAssertEqual(results.first?.title.lowercased().contains("toilet"), true)
    }

    func testNeverReturnsEmptyForDemo() async throws {
        let results = try await MockCatalog().search("zzz-nonexistent-item")
        XCTAssertFalse(results.isEmpty, "Demo search should always return something")
    }

    func testPaperTowelsMatch() async throws {
        let results = try await MockCatalog().search("paper towels")
        XCTAssertTrue(results.first?.title.lowercased().contains("towel") ?? false)
    }
}
