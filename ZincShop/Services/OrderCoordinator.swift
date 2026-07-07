import Foundation

/// Places an order via whichever path is configured:
///
/// - **Keyed (default when `ZINC_API_KEY` is set):** Face ID guard →
///   `POST /orders` (Bearer, wallet-funded) → `201`.
/// - **MPP (no key):** `POST /agent/orders` → `402` → pay the Stripe challenge
///   with Apple Pay → retry with the credential → `201`; capture the per-order
///   `X-Api-Key` for status polling.
@MainActor
final class OrderCoordinator {
    private let zinc: ZincClient
    private let applePay: ApplePayService

    init(zinc: ZincClient = ZincClient(), applePay: ApplePayService? = nil) {
        self.zinc = zinc
        self.applePay = applePay ?? ApplePayService()
    }

    func purchase(product: Product, quantity: Int,
                  shipping: ShippingProfile, maxPriceCents: Int) async throws -> OrderRecord {
        // Guardrail: never order above the user's per-order price cap.
        guard product.priceCents <= maxPriceCents else {
            throw PaymentError.overPriceCap(amountCents: product.priceCents, capCents: maxPriceCents)
        }

        let body = OrderRequestBody(product: product, quantity: quantity, shipping: shipping,
                                    maxPriceCents: maxPriceCents, idempotencyKey: UUID().uuidString)

        if !SecretsStore.zincApiKey.isEmpty {
            return try await keyedOrder(body: body, product: product)
        } else {
            return try await mppOrder(body: body, product: product, maxPriceCents: maxPriceCents)
        }
    }

    // MARK: Keyed (wallet-funded) order with a Face ID guard

    private func keyedOrder(body: OrderRequestBody, product: Product) async throws -> OrderRecord {
        try await BiometricAuth.confirm("Confirm your order of \(product.title)")
        let (resp, data) = try await zinc.createKeyedOrder(body: body)
        guard resp.statusCode == 201 else {
            throw ZincError.http(resp.statusCode, Self.message(data))
        }
        let dto = try zinc.decodeOrder(data)
        // No X-Api-Key for keyed orders — status is polled with the Bearer key.
        return OrderRecord(dto: dto, product: product, apiKey: nil)
    }

    // MARK: MPP order (Apple Pay pays the 402 challenge)

    private func mppOrder(body: OrderRequestBody, product: Product,
                          maxPriceCents: Int) async throws -> OrderRecord {
        var (resp, data) = try await zinc.createAgentOrder(body: body, credential: nil)
        if resp.statusCode == 201 { return try record(resp, data, product) }
        guard resp.statusCode == 402 else {
            throw ZincError.http(resp.statusCode, Self.message(data))
        }

        let challenges = PaymentChallenge.parseAll(from: resp)
        guard let stripe = challenges.first(where: { $0.method == "stripe" }) else {
            throw PaymentError.noStripeRail
        }
        guard stripe.amountCents <= maxPriceCents else {
            throw PaymentError.overPriceCap(amountCents: stripe.amountCents, capCents: maxPriceCents)
        }

        let credential = try await applePay.pay(challenge: stripe, productTitle: product.title)
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
