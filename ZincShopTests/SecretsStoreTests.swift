import XCTest
@testable import ZincShop

final class SecretsStoreTests: XCTestCase {
    func testStripsSurroundingQuotes() {
        XCTAssertEqual(SecretsStore.clean("\"zn_live_abc\""), "zn_live_abc")
    }

    func testTrimsWhitespace() {
        XCTAssertEqual(SecretsStore.clean("  zn_live_abc  "), "zn_live_abc")
        XCTAssertEqual(SecretsStore.clean(" \"zn_live_abc\" "), "zn_live_abc")
    }

    func testLeavesUnquotedValueUntouched() {
        XCTAssertEqual(SecretsStore.clean("zn_live_abc"), "zn_live_abc")
    }

    func testEmptyStaysEmpty() {
        XCTAssertEqual(SecretsStore.clean(""), "")
        XCTAssertEqual(SecretsStore.clean("\"\""), "")
    }
}
