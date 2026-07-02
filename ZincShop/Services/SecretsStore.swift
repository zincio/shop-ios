import Foundation

/// Reads build configuration injected via `Config/Secrets.xcconfig` → Info.plist.
/// Only non-secret values (publishable key, merchant id, base URL) live here —
/// the MPP design means no Zinc secret key is shipped at all.
enum SecretsStore {
    private static func string(_ key: String) -> String {
        (Bundle.main.object(forInfoDictionaryKey: key) as? String) ?? ""
    }

    static var stripePublishableKey: String { string("StripePublishableKey") }
    static var applePayMerchantID: String { string("ApplePayMerchantID") }

    static var zincBaseURL: URL {
        let raw = string("ZincBaseURL")
        return URL(string: raw.isEmpty ? "https://api.zinc.com" : raw)
            ?? URL(string: "https://api.zinc.com")!
    }
}
