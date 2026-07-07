import XCTest
@testable import ZincShop

final class OrderDecodingTests: XCTestCase {
    func testDecodesAgentOrderResponse() throws {
        let json = """
        {
          "id": "550e8400-e29b-41d4-a716-446655440000",
          "status": "pending",
          "max_price": 5000,
          "items": [{"url": "https://www.amazon.com/dp/B07JGBW826", "quantity": 1, "status": "pending"}],
          "tracking_numbers": []
        }
        """.data(using: .utf8)!

        let dto = try ZincClient.decoder.decode(AgentOrderDTO.self, from: json)
        XCTAssertEqual(dto.id, "550e8400-e29b-41d4-a716-446655440000")
        XCTAssertEqual(dto.status, "pending")
        XCTAssertEqual(dto.maxPrice, 5000)
        XCTAssertEqual(dto.items.count, 1)
        XCTAssertTrue(dto.trackingNumbers.isEmpty)
    }

    func testToleratesMissingItemsAndTracking() throws {
        let json = #"{"id":"abc","status":"shipped"}"#.data(using: .utf8)!
        let dto = try ZincClient.decoder.decode(AgentOrderDTO.self, from: json)
        XCTAssertEqual(dto.status, "shipped")
        XCTAssertTrue(dto.items.isEmpty)
    }

    func testJobResultErrorSurfaced() {
        let e1 = #"{"id":"o1","status":"failed","job_result":{"type":"error","message":"max_price exceeded"}}"#
        XCTAssertEqual(ZincClient.jobResultError(from: Data(e1.utf8)), "max_price exceeded")

        let e2 = #"{"id":"o2","status":"failed","job_result":{"error":{"code":"insufficient_funds","message":"Wallet is empty"}}}"#
        XCTAssertEqual(ZincClient.jobResultError(from: Data(e2.utf8)), "Wallet is empty")
    }

    func testJobResultSuccessOrMissingYieldsNoError() {
        let ok = #"{"id":"o3","status":"placed","job_result":{"type":"success","price_components":{"total":1999}}}"#
        XCTAssertNil(ZincClient.jobResultError(from: Data(ok.utf8)))
        let none = #"{"id":"o4","status":"pending"}"#
        XCTAssertNil(ZincClient.jobResultError(from: Data(none.utf8)))
    }

    func testApplyMergesStatusAndTracking() throws {
        let product = Product(url: "u", title: "Toilet Paper", priceCents: 2399,
                              imageURL: nil, retailer: "amazon")
        let initial = try ZincClient.decoder.decode(
            AgentOrderDTO.self, from: #"{"id":"o1","status":"pending"}"#.data(using: .utf8)!)
        var record = OrderRecord(dto: initial, product: product, apiKey: "k")

        let update = try ZincClient.decoder.decode(
            AgentOrderDTO.self,
            from: #"{"id":"o1","status":"shipped","tracking_numbers":["1Z999"]}"#.data(using: .utf8)!)
        record.apply(update)

        XCTAssertEqual(record.status, "shipped")
        XCTAssertEqual(record.trackingNumbers, ["1Z999"])
        XCTAssertEqual(record.statusDisplay, "Shipped")
    }
}
