import XCTest
@testable import ZincShop

final class SemanticQueryBuilderTests: XCTestCase {
    func testUsesLabelsWhenPresent() async {
        let q = await SemanticQueryBuilder.query(
            labels: ["paper towels", "roll", "kitchen", "cardboard", "extra"],
            classify: { XCTFail("should not classify when labels exist"); return [] }
        )
        // Joins up to the top 3 labels, trimmed.
        XCTAssertEqual(q, "paper towels roll kitchen")
    }

    func testTrimsAndDropsEmptyLabels() async {
        let q = await SemanticQueryBuilder.query(
            labels: ["  ", "cast iron skillet ", ""],
            classify: { [] }
        )
        XCTAssertEqual(q, "cast iron skillet")
    }

    func testReturnsNilWhenNoLabelsAndNoClassification() async {
        let q = await SemanticQueryBuilder.query(labels: [], classify: { [] })
        XCTAssertNil(q)
    }

    func testFallsBackToClassifierWhenNoLabels() async {
        let q = await SemanticQueryBuilder.query(
            labels: [],
            classify: { ["mug", "cup"] }
        )
        XCTAssertEqual(q, "mug cup")
    }
}
