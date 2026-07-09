import XCTest
@testable import ZincShop

final class APIKeyFieldTests: XCTestCase {
    func testAcceptsLiveAndTestKeys() {
        XCTAssertTrue(APIKeyField.looksLikeKey("zn_live_abcdef123456"))
        XCTAssertTrue(APIKeyField.looksLikeKey("zn_test_abcdef123456"))
    }

    func testTrimsSurroundingWhitespace() {
        XCTAssertTrue(APIKeyField.looksLikeKey("  zn_live_abcdef123456  "))
    }

    func testRejectsWrongPrefixOrTooShort() {
        XCTAssertFalse(APIKeyField.looksLikeKey("sk_live_abcdef123456"))
        XCTAssertFalse(APIKeyField.looksLikeKey("zn_short"))
        XCTAssertFalse(APIKeyField.looksLikeKey(""))
    }
}
