import Foundation
import LocalAuthentication

/// Face ID / Touch ID confirmation used as the purchase guard for keyed
/// (wallet-funded) orders, where there's no Apple Pay sheet to stand in for it.
enum BiometricAuth {
    /// Throws if the user cancels or authentication fails. If the device has no
    /// biometrics/passcode configured (e.g. a bare simulator), it proceeds so
    /// the demo isn't blocked.
    static func confirm(_ reason: String) async throws {
        let context = LAContext()
        context.localizedFallbackTitle = "Use Passcode"

        var policy: LAPolicy = .deviceOwnerAuthenticationWithBiometrics
        var error: NSError?
        if !context.canEvaluatePolicy(policy, error: &error) {
            policy = .deviceOwnerAuthentication // fall back to passcode
            if !context.canEvaluatePolicy(policy, error: &error) {
                return // nothing configured — don't block the demo
            }
        }

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            context.evaluatePolicy(policy, localizedReason: reason) { success, err in
                if success { cont.resume() }
                else { cont.resume(throwing: err ?? PaymentError.cancelled) }
            }
        }
    }
}
