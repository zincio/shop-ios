import Foundation
import PassKit

/// === INTEGRATION SEAM ===
///
/// Turns an Apple Pay authorization into the MPP payment credential that gets
/// attached as the `Authorization` header on the order retry.
///
/// In production this is where the Stripe iOS SDK does its work:
///   1. The 402 `request` (base64 JSON: amount/currency/recipient `acct_…`/
///      `methodDetails.networkId`) describes a charge on a Stripe **connected
///      account**.
///   2. Convert `payment.token` (the Apple Pay PKPaymentToken) into a Stripe
///      charge against that account for `challenge.amountCents` — e.g. via
///      `STPApplePayContext` confirming a PaymentIntent derived from the MPP
///      request, using only the **publishable** key.
///   3. Build the MPP credential from the resulting receipt and return it.
///
/// The Stripe SDK call surface and a real card can't be exercised in this
/// offline prototype, so we assemble the credential envelope from the Apple Pay
/// token. Swap the body of `credential(for:applePayToken:)` for the Stripe call
/// when wiring against a live Stripe account. Keep the envelope shape verified
/// against the MPP spec / Zinc support.
enum StripeMPPAdapter {
    static func credential(for challenge: PaymentChallenge,
                           applePayToken token: PKPaymentToken) throws -> String {
        let receipt = token.paymentData.base64EncodedString()
        guard !receipt.isEmpty else { throw PaymentError.chargeFailed("empty Apple Pay token") }
        // MPP auth-scheme echo of the challenge id plus the payment proof.
        return "Payment id=\"\(challenge.id)\", method=\"stripe\", receipt=\"\(receipt)\""
    }
}
