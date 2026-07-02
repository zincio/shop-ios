import Foundation

/// Drives Zinc's MPP 402 payment dance end-to-end:
/// 1. POST the order unauthenticated → expect `402` with `WWW-Authenticate`.
/// 2. Parse the Stripe challenge.
/// 3. Pay it with Apple Pay (Face ID) → MPP credential.
/// 4. Retry the same body with the credential → `201`; capture the order-scoped
///    `X-Api-Key` for status polling.
@MainActor
final class MPPPaymentCoordinator {
    private let zinc: ZincClient
    private let applePay: ApplePayService

    init(zinc: ZincClient = ZincClient(), applePay: ApplePayService? = nil) {
        self.zinc = zinc
        self.applePay = applePay ?? ApplePayService()
    }

    func purchase(product: Product, quantity: Int,
                  shipping: ShippingProfile, maxPriceCents: Int) async throws -> OrderRecord {
        let body = OrderRequestBody(product: product, quantity: quantity, shipping: shipping,
                                    maxPriceCents: maxPriceCents, idempotencyKey: UUID().uuidString)

        // 1. Unauthenticated request → challenge (or, rarely, immediate success).
        var (resp, data) = try await zinc.createAgentOrder(body: body, credential: nil)
        if resp.statusCode == 201 { return try record(resp, data, product) }
        guard resp.statusCode == 402 else {
            throw ZincError.http(resp.statusCode, Self.message(data))
        }

        // 2. Pick the Stripe rail.
        let challenges = PaymentChallenge.parseAll(from: resp)
        guard let stripe = challenges.first(where: { $0.method == "stripe" }) else {
            throw PaymentError.noStripeRail
        }

        // Guardrail: never let the charge exceed the user's price cap.
        guard stripe.amountCents <= maxPriceCents else {
            throw PaymentError.overPriceCap(amountCents: stripe.amountCents, capCents: maxPriceCents)
        }

        // 3. Pay (Apple Pay sheet = confirm + Face ID).
        let credential = try await applePay.pay(challenge: stripe, productTitle: product.title)

        // 4. Retry with the credential.
        (resp, data) = try await zinc.createAgentOrder(body: body, credential: credential)
        guard resp.statusCode == 201 else {
            throw ZincError.http(resp.statusCode, Self.message(data))
        }
        return try record(resp, data, product)
    }

    private func record(_ resp: HTTPURLResponse, _ data: Data, _ product: Product) throws -> OrderRecord {
        let dto = try zinc.decodeOrder(data)
        let apiKey = resp.value(forHTTPHeaderField: "X-Api-Key")
        return OrderRecord(dto: dto, product: product, apiKey: apiKey)
    }

    private static func message(_ data: Data) -> String {
        String(data: data, encoding: .utf8) ?? "unknown error"
    }
}
