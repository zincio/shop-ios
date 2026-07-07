import Foundation

/// Reads build configuration injected via `Config/Secrets.xcconfig` → Info.plist.
/// Only non-secret values (publishable key, merchant id, base URL) live here —
/// the MPP design means no Zinc secret key is shipped at all.
enum SecretsStore {
    private static func string(_ key: String) -> String {
        clean((Bundle.main.object(forInfoDictionaryKey: key) as? String) ?? "")
    }

    /// xcconfig values are literal, so a value the user quoted ("zn_live_…")
    /// keeps its quotes and breaks the request. Strip surrounding quotes and
    /// whitespace defensively.
    static func clean(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.count >= 2, s.hasPrefix("\""), s.hasSuffix("\"") {
            s = String(s.dropFirst().dropLast())
        }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static var stripePublishableKey: String { string("StripePublishableKey") }
    static var applePayMerchantID: String { string("ApplePayMerchantID") }

    /// Bearer key for cross-retailer search (`GET /search`). Demo-only on-device;
    /// empty → search falls back to the built-in catalog.
    static var zincApiKey: String { string("ZincApiKey") }

    static var zincBaseURL: URL {
        let raw = string("ZincBaseURL")
        return URL(string: raw.isEmpty ? "https://api.zinc.com" : raw)
            ?? URL(string: "https://api.zinc.com")!
    }
}
