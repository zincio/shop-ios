import XCTest
@testable import ZincShop

final class PaymentChallengeTests: XCTestCase {
    // Real captured 402 `WWW-Authenticate` values from api.zinc.com.
    // HTTPURLResponse joins repeated headers with ", " — replicate that here.
    private let tempo = #"Payment id="TMeujawAl9Mh5knrCBxYAP0oSivbgm8ic9vOTwBv_4s", realm="api.zinc.com", method="tempo", intent="charge", request="eyJhbW91bnQiOiIxMDAwMDAwIiwiY3VycmVuY3kiOiIweDIwQzAwMDAwMDAwMDAwMDAwMDAwMDAwMGI5NTM3ZDExYzYwRThiNTAiLCJtZXRob2REZXRhaWxzIjp7ImNoYWluSWQiOjQyMTd9LCJyZWNpcGllbnQiOiIweDNiYTliNTA0ZTQxYjlkMjBlNTc3NjgxYTBmNGJiZWQxYjBmYmU0NmIifQ", expires="2026-06-30T21:48:08.286010Z""#
    private let stripe = #"Payment id="YcMzusg_9Sn8mdUeGXj5ID7XQ2wZ6WZsOVHS34xVUzo", realm="api.zinc.com", method="stripe", intent="charge", request="eyJhbW91bnQiOiIxMDAiLCJjdXJyZW5jeSI6InVzZCIsIm1ldGhvZERldGFpbHMiOnsibmV0d29ya0lkIjoicHJvZmlsZV82MVVOWllzaVZ0dWVKUFIyUkE2VU5aWXNLZlNRZ0dGcW83RDA0Z0dFYTg2QyJ9LCJyZWNpcGllbnQiOiJhY2N0XzFScjJqNEM1eEFUNjJFdGcifQ", expires="2026-06-30T21:48:08.286157Z""#

    func testParsesBothRails() {
        let header = [tempo, stripe].joined(separator: ", ")
        let challenges = PaymentChallenge.parseAll(headerValue: header)
        XCTAssertEqual(challenges.count, 2)
        XCTAssertEqual(Set(challenges.map(\.method)), ["tempo", "stripe"])
    }

    func testStripeChallengeDecodesAmountAndRecipient() throws {
        let header = [tempo, stripe].joined(separator: ", ")
        let stripeChallenge = try XCTUnwrap(
            PaymentChallenge.parseAll(headerValue: header).first { $0.method == "stripe" }
        )
        XCTAssertEqual(stripeChallenge.id, "YcMzusg_9Sn8mdUeGXj5ID7XQ2wZ6WZsOVHS34xVUzo")
        XCTAssertEqual(stripeChallenge.amountCents, 100)
        XCTAssertEqual(stripeChallenge.currency, "usd")
        XCTAssertEqual(stripeChallenge.recipient, "acct_1Rr2j4C5xAT62Etg")
        XCTAssertTrue(stripeChallenge.networkId?.hasPrefix("profile_") ?? false)
    }

    func testTempoAmountDecodes() throws {
        let stripeChallenge = try XCTUnwrap(
            PaymentChallenge.parseAll(headerValue: tempo).first
        )
        XCTAssertEqual(stripeChallenge.amountCents, 1_000_000)
        XCTAssertTrue(stripeChallenge.recipient.hasPrefix("0x"))
    }

    func testEmptyHeaderYieldsNoChallenges() {
        XCTAssertTrue(PaymentChallenge.parseAll(headerValue: "").isEmpty)
    }
}
