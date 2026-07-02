import Foundation

/// A single payment option parsed from a `402` `WWW-Authenticate: Payment …`
/// header returned by Zinc's MPP endpoint.
///
/// Example header value (one per offered rail):
/// `Payment id="abc", realm="api.zinc.com", method="stripe", intent="charge",
///  request="<base64-json>", expires="2026-…"`
/// where the base64 `request` decodes to
/// `{"amount":"100","currency":"usd","recipient":"acct_…","methodDetails":{"networkId":"profile_…"}}`.
struct PaymentChallenge: Equatable {
    let id: String
    let method: String          // "stripe", "tempo", …
    let intent: String          // "charge"
    let amountCents: Int        // from request.amount (USD cents for stripe)
    let currency: String        // "usd"
    let recipient: String       // Stripe connected account acct_…
    let networkId: String?      // request.methodDetails.networkId
    let rawRequestBase64: String

    /// Parse every `WWW-Authenticate` challenge from a 402 response.
    ///
    /// `HTTPURLResponse` collapses repeated headers into one comma-joined
    /// string, so we split on the `Payment ` auth-scheme keyword — safe because
    /// every value inside a challenge is double-quoted.
    static func parseAll(from response: HTTPURLResponse) -> [PaymentChallenge] {
        let raw = headerValue(response, "WWW-Authenticate")
        return parseAll(headerValue: raw)
    }

    static func parseAll(headerValue raw: String) -> [PaymentChallenge] {
        raw.components(separatedBy: "Payment ")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .compactMap { parseOne($0) }
    }

    private static func parseOne(_ chunk: String) -> PaymentChallenge? {
        let fields = quotedFields(chunk)
        guard let id = fields["id"], let method = fields["method"],
              let requestB64 = fields["request"] else { return nil }

        var amount = 0, currency = "usd", recipient = "", networkId: String? = nil
        if let json = decodeRequest(requestB64) {
            amount = Int(json["amount"] as? String ?? "") ?? (json["amount"] as? Int ?? 0)
            currency = json["currency"] as? String ?? currency
            recipient = json["recipient"] as? String ?? ""
            if let details = json["methodDetails"] as? [String: Any] {
                networkId = details["networkId"] as? String
            }
        }
        return PaymentChallenge(
            id: id, method: method, intent: fields["intent"] ?? "charge",
            amountCents: amount, currency: currency, recipient: recipient,
            networkId: networkId, rawRequestBase64: requestB64
        )
    }

    /// Parse `key="value"` pairs from a challenge chunk.
    private static func quotedFields(_ s: String) -> [String: String] {
        var out: [String: String] = [:]
        let pattern = #"(\w+)="([^"]*)""#
        guard let re = try? NSRegularExpression(pattern: pattern) else { return out }
        let range = NSRange(s.startIndex..., in: s)
        for m in re.matches(in: s, range: range) {
            guard let kR = Range(m.range(at: 1), in: s),
                  let vR = Range(m.range(at: 2), in: s) else { continue }
            out[String(s[kR])] = String(s[vR])
        }
        return out
    }

    private static func decodeRequest(_ b64: String) -> [String: Any]? {
        guard let data = decodeBase64(b64),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return obj
    }

    /// MPP `request` payloads are base64url and often unpadded — normalize both.
    private static func decodeBase64(_ s: String) -> Data? {
        var str = s.replacingOccurrences(of: "-", with: "+")
                   .replacingOccurrences(of: "_", with: "/")
        let remainder = str.count % 4
        if remainder > 0 { str += String(repeating: "=", count: 4 - remainder) }
        return Data(base64Encoded: str)
    }

    private static func headerValue(_ response: HTTPURLResponse, _ name: String) -> String {
        if #available(iOS 13.0, *) { return response.value(forHTTPHeaderField: name) ?? "" }
        return (response.allHeaderFields[name] as? String) ?? ""
    }
}
