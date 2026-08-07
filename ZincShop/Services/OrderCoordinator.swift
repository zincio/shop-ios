import Foundation
import CryptoKit

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

    /// - Parameter requireBiometric: gate the keyed path behind Face ID. The
    ///   in-app flow passes `true`; the Siri path passes `false` because Siri's
    ///   own order confirmation is the authorization and Face ID can't reliably
    ///   present from a background intent.
    func purchase(product: Product, quantity: Int, shipping: ShippingProfile,
                  maxPriceCents: Int, devMode: Bool = false,
                  requireBiometric: Bool = true) async throws -> OrderRecord {
        // max_price is sized to THIS item (plus ~30% headroom for tax/shipping),
        // NOT the flat price cap. Sending the cap made Zinc secure roughly the
        // whole cap against the wallet, so a cheap item tripped "insufficient
        // funds" (402) on a small balance. The user's cap still bounds it, and
        // the guard still blocks items whose price alone exceeds the cap.
        // Dev mode sends max_price = 0 so the order can never finalize (safe
        // testing); the price-cap guard is skipped since 0 would always trip it.
        let effectiveMax: Int
        if devMode {
            effectiveMax = 0
        } else {
            guard product.priceCents <= maxPriceCents else {
                throw PaymentError.overPriceCap(amountCents: product.priceCents, capCents: maxPriceCents)
            }
            let withHeadroom = Int(Double(product.priceCents) * 1.3)
            effectiveMax = min(maxPriceCents, max(withHeadroom, product.priceCents))
        }

        let body = OrderRequestBody(product: product, quantity: quantity, shipping: shipping,
                                    maxPriceCents: effectiveMax,
                                    idempotencyKey: Self.idempotencyKey(for: product))

        if !ZincCredentials.apiKey.isEmpty {
            return try await keyedOrder(body: body, product: product, requireBiometric: requireBiometric)
        } else {
            return try await mppOrder(body: body, product: product, maxPriceCents: effectiveMax)
        }
    }

    // MARK: Keyed (wallet-funded) order with a Face ID guard

    private func keyedOrder(body: OrderRequestBody, product: Product,
                            requireBiometric: Bool) async throws -> OrderRecord {
        if requireBiometric {
            try await BiometricAuth.confirm("Confirm your order of \(product.title)")
        }
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

    /// Idempotency key that's **stable for the same product within a short
    /// window**, so an accidental double-tap (or a snippet button firing twice,
    /// possibly in separate processes) dedupes at Zinc instead of placing two
    /// orders. A later intentional re-order lands in a new window → new key.
    /// SHA-256 (not `hashValue`, which is randomized per process) so the key is
    /// identical across the two executions.
    private static func idempotencyKey(for product: Product) -> String {
        let window = Int(Date().timeIntervalSince1970 / 120)   // 2-minute bucket
        let seed = "\(product.url)|\(window)"
        let digest = SHA256.hash(data: Data(seed.utf8))
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        // Zinc caps idempotency_key at 36 chars; the full SHA-256 hex is 64.
        // 32 hex chars (128 bits) is still collision-safe for dedup.
        return String(hex.prefix(32))
    }
}
