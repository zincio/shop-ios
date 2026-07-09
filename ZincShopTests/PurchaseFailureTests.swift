import XCTest
import LocalAuthentication
@testable import ZincShop

final class PurchaseFailureTests: XCTestCase {
    func testOverPriceCapSendsToSettings() {
        let f = PurchaseFailure(PaymentError.overPriceCap(amountCents: 2599, capCents: 2000))
        XCTAssertEqual(f.recovery, .adjustCap)
        XCTAssertTrue(f.message.contains("$25.99"))
        XCTAssertTrue(f.message.contains("$20.00"))
        XCTAssertTrue(f.message.contains("Settings"))
    }

    func testCancelledIsRetryable() {
        let f = PurchaseFailure(PaymentError.cancelled)
        XCTAssertEqual(f.recovery, .retry)
    }

    func testApplePayUnavailableIsUnrecoverable() {
        let f = PurchaseFailure(PaymentError.applePayUnavailable)
        XCTAssertEqual(f.recovery, .dismiss)
    }

    func testNoStripeRailIsUnrecoverable() {
        let f = PurchaseFailure(PaymentError.noStripeRail)
        XCTAssertEqual(f.recovery, .dismiss)
    }

    func testServerErrorIsRetryable() {
        let f = PurchaseFailure(ZincError.http(503, "service unavailable"))
        XCTAssertEqual(f.recovery, .retry)
        XCTAssertTrue(f.message.contains("503"))
    }

    func testClientErrorIsNotRetryable() {
        let f = PurchaseFailure(ZincError.http(422, "invalid address"))
        XCTAssertEqual(f.recovery, .dismiss)
        XCTAssertEqual(f.message, "invalid address")
    }

    func testTransportErrorIsRetryable() {
        let f = PurchaseFailure(ZincError.transport("offline"))
        XCTAssertEqual(f.recovery, .retry)
        XCTAssertTrue(f.title.contains("Network"))
    }

    func testFaceIDCancelledIsRetryable() {
        let f = PurchaseFailure(LAError(.userCancel))
        XCTAssertEqual(f.recovery, .retry)
        XCTAssertTrue(f.title.contains("Face ID"))
    }

    func testFaceIDLockoutMentionsPasscode() {
        let f = PurchaseFailure(LAError(.biometryLockout))
        XCTAssertEqual(f.recovery, .retry)
        XCTAssertTrue(f.message.lowercased().contains("passcode"))
    }

    func testUnknownErrorFallsBackToRetry() {
        struct Weird: Error {}
        let f = PurchaseFailure(Weird())
        XCTAssertEqual(f.recovery, .retry)
        XCTAssertEqual(f.title, "Something went wrong")
    }
}
