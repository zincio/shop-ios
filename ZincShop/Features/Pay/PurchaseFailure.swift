import Foundation
import LocalAuthentication
import PassKit

/// A user-facing interpretation of a purchase error: what to tell the user and
/// which action to offer. Maps the domain errors thrown along the order path
/// (`PaymentError`, `ZincError`, LocalAuthentication's `LAError`, and Apple
/// Pay's `PKPaymentError`) to specific guidance instead of surfacing a raw
/// `localizedDescription` like "The operation couldn't be completed."
struct PurchaseFailure: Equatable {
    /// What the user can do about the failure — drives which button the
    /// failure screen shows.
    enum Recovery: Equatable {
        /// Transient (network, Face ID cancelled, server hiccup) — offer "Try Again".
        case retry
        /// Price cap exceeded — retrying won't help until they change it in Settings.
        case adjustCap
        /// Unrecoverable on this device/order (Apple Pay unavailable, no card rail).
        case dismiss
    }

    var title: String
    var message: String
    var recovery: Recovery

    init(title: String, message: String, recovery: Recovery) {
        self.title = title
        self.message = message
        self.recovery = recovery
    }

    init(_ error: Error) {
        if let payment = error as? PaymentError {
            self = Self.classify(payment)
        } else if let zinc = error as? ZincError {
            self = Self.classify(zinc)
        } else if let auth = error as? LAError {
            self = Self.classify(auth)
        } else if error is PKPaymentError {
            self = .init(title: "Apple Pay problem",
                         message: "Apple Pay couldn't complete the payment. Please try again.",
                         recovery: .retry)
        } else {
            self = .init(title: "Something went wrong",
                         message: error.localizedDescription,
                         recovery: .retry)
        }
    }

    private static func classify(_ error: PaymentError) -> PurchaseFailure {
        switch error {
        case .overPriceCap(let amount, let cap):
            return .init(title: "Over your price cap",
                         message: "\(currency(amount)) is above your \(currency(cap)) limit. "
                                + "Raise your cap in Settings to order this.",
                         recovery: .adjustCap)
        case .cancelled:
            return .init(title: "Purchase cancelled",
                         message: "You cancelled before the order was placed.",
                         recovery: .retry)
        case .applePayUnavailable:
            return .init(title: "Apple Pay unavailable",
                         message: "Apple Pay isn't set up on this device, so this order can't be paid.",
                         recovery: .dismiss)
        case .noStripeRail:
            return .init(title: "Card payment unavailable",
                         message: "This order doesn't offer a card payment option.",
                         recovery: .dismiss)
        case .chargeFailed(let detail):
            return .init(title: "Payment failed",
                         message: detail,
                         recovery: .retry)
        }
    }

    private static func classify(_ error: ZincError) -> PurchaseFailure {
        switch error {
        case .http(let code, let msg):
            if code >= 500 {
                return .init(title: "Zinc had a problem",
                             message: "The order service is having trouble (error \(code)). Please try again.",
                             recovery: .retry)
            }
            return .init(title: "Order rejected",
                         message: msg.isEmpty ? "Zinc rejected this order (error \(code))." : msg,
                         recovery: .dismiss)
        case .transport:
            return .init(title: "Network problem",
                         message: "Couldn't reach Zinc. Check your connection and try again.",
                         recovery: .retry)
        case .decoding:
            return .init(title: "Unexpected response",
                         message: "Zinc returned something we couldn't read. Please try again.",
                         recovery: .retry)
        case .noProductsFound:
            return .init(title: "Product unavailable",
                         message: "This product is no longer available to order.",
                         recovery: .dismiss)
        case .unauthorized:
            return .init(title: "API key rejected",
                         message: "Your Zinc API key was rejected. Open Settings and check your key.",
                         recovery: .dismiss)
        }
    }

    private static func classify(_ error: LAError) -> PurchaseFailure {
        switch error.code {
        case .userCancel, .appCancel, .systemCancel:
            return .init(title: "Face ID cancelled",
                         message: "You cancelled Face ID before confirming the order.",
                         recovery: .retry)
        case .authenticationFailed:
            return .init(title: "Couldn't verify it's you",
                         message: "Face ID didn't match. Please try again.",
                         recovery: .retry)
        case .biometryLockout:
            return .init(title: "Face ID locked",
                         message: "Too many attempts. Unlock with your passcode, then try again.",
                         recovery: .retry)
        default:
            return .init(title: "Couldn't confirm",
                         message: "We couldn't confirm the order with Face ID. Please try again.",
                         recovery: .retry)
        }
    }

    private static func currency(_ cents: Int) -> String {
        (Double(cents) / 100).formatted(.currency(code: "USD"))
    }
}
