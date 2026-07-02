import Foundation

enum PaymentError: LocalizedError {
    case applePayUnavailable
    case cancelled
    case noStripeRail
    case overPriceCap(amountCents: Int, capCents: Int)
    case chargeFailed(String)

    var errorDescription: String? {
        switch self {
        case .applePayUnavailable:
            return "Apple Pay isn't available on this device."
        case .cancelled:
            return "Payment was cancelled."
        case .noStripeRail:
            return "Card payment isn't offered for this order."
        case .overPriceCap(let amount, let cap):
            let f: (Int) -> String = { (Double($0) / 100).formatted(.currency(code: "USD")) }
            return "Price \(f(amount)) exceeds your cap of \(f(cap))."
        case .chargeFailed(let m):
            return "Payment failed: \(m)"
        }
    }
}
