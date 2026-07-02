import Foundation
import PassKit

/// Presents the Apple Pay sheet for an MPP payment challenge. The biometric
/// approval in this sheet *is* the "confirm + Face ID" purchase guard. On
/// success it returns the MPP credential to attach to the order retry.
@MainActor
final class ApplePayService: NSObject {
    private var controller: PKPaymentAuthorizationController?
    private var continuation: CheckedThrowingContinuation?
    private var challenge: PaymentChallenge?
    private var producedCredential: String?
    private var producedError: Error?

    typealias CheckedThrowingContinuation = CheckedContinuation<String, Error>

    static var canPay: Bool { PKPaymentAuthorizationController.canMakePayments() }

    func pay(challenge: PaymentChallenge, productTitle: String) async throws -> String {
        guard Self.canPay else { throw PaymentError.applePayUnavailable }
        self.challenge = challenge
        self.producedCredential = nil
        self.producedError = nil

        let request = Self.makeRequest(challenge: challenge, productTitle: productTitle)
        let controller = PKPaymentAuthorizationController(paymentRequest: request)
        controller.delegate = self
        self.controller = controller

        return try await withCheckedThrowingContinuation { cont in
            self.continuation = cont
            controller.present { presented in
                if !presented {
                    Task { @MainActor in self.finish(.failure(PaymentError.applePayUnavailable)) }
                }
            }
        }
    }

    static func makeRequest(challenge: PaymentChallenge, productTitle: String) -> PKPaymentRequest {
        let r = PKPaymentRequest()
        r.merchantIdentifier = SecretsStore.applePayMerchantID
        r.supportedNetworks = [.visa, .masterCard, .amex, .discover]
        r.merchantCapabilities = .threeDSecure
        r.countryCode = "US"
        r.currencyCode = challenge.currency.uppercased()
        let amount = NSDecimalNumber(value: Double(challenge.amountCents) / 100)
        r.paymentSummaryItems = [
            PKPaymentSummaryItem(label: productTitle, amount: amount),
            PKPaymentSummaryItem(label: "Zinc", amount: amount),
        ]
        return r
    }

    private func finish(_ result: Result<String, Error>) {
        continuation?.resume(with: result)
        continuation = nil
        controller = nil
    }
}

extension ApplePayService: PKPaymentAuthorizationControllerDelegate {
    func paymentAuthorizationController(
        _ controller: PKPaymentAuthorizationController,
        didAuthorizePayment payment: PKPayment,
        handler completion: @escaping (PKPaymentAuthorizationResult) -> Void
    ) {
        guard let challenge else {
            producedError = PaymentError.cancelled
            completion(.init(status: .failure, errors: nil))
            return
        }
        do {
            producedCredential = try StripeMPPAdapter.credential(for: challenge,
                                                                 applePayToken: payment.token)
            completion(.init(status: .success, errors: nil))
        } catch {
            producedError = error
            completion(.init(status: .failure, errors: [error]))
        }
    }

    func paymentAuthorizationControllerDidFinish(_ controller: PKPaymentAuthorizationController) {
        controller.dismiss()
        if let credential = producedCredential {
            finish(.success(credential))
        } else {
            finish(.failure(producedError ?? PaymentError.cancelled))
        }
    }
}
