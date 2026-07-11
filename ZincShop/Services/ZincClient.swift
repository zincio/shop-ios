import Foundation

enum ZincError: LocalizedError {
    case http(Int, String)
    case decoding(String)
    case noProductsFound
    case transport(String)
    case unauthorized

    var errorDescription: String? {
        switch self {
        case .http(let code, let msg): return "Zinc error \(code): \(msg)"
        case .decoding(let m): return "Couldn't read Zinc response: \(m)"
        case .noProductsFound: return "No products found."
        case .transport(let m): return "Network error: \(m)"
        case .unauthorized:
            return "Your Zinc API key was rejected. Open Zinc → Settings and check your key."
        }
    }
}

/// Thin client over Zinc's MPP agent API. Holds **no** secret key — order
/// creation is unauthenticated until paid, and status checks use the per-order
/// `X-Api-Key` returned on success.
struct ZincClient {
    var baseURL: URL = SecretsStore.zincBaseURL
    var session: URLSession = .shared
    /// Use the built-in demo catalog when the live search endpoint is
    /// unavailable/unverified, so the end-to-end flow stays demonstrable.
    var searchFallback: ProductSearching = MockCatalog()

    // MARK: Search

    /// Search priority:
    /// 1. When a Zinc API key is set: keyed cross-retailer search (`GET /search`,
    ///    Bearer) exclusively. A rejected key or network failure now *throws* so
    ///    the UI (and Siri) can tell the user, instead of silently masking a bad
    ///    key behind the demo catalog.
    /// 2. No key at all: the built-in demo catalog, so the app is usable offline.
    func search(_ query: String) async throws -> [Product] {
        guard !ZincCredentials.apiKey.isEmpty else {
            return try await searchFallback.search(query)
        }
        return try await keyedSearch(query)
    }

    /// Cross-retailer search: `GET /search?q=…` with a Bearer API key. Results
    /// carry `url`, per-item `retailer`, and `stars`. Throws `.unauthorized` on a
    /// rejected key (401/403) so callers can prompt the user to fix it.
    private func keyedSearch(_ query: String) async throws -> [Product] {
        guard let url = searchURL("search", query) else { return [] }
        var req = URLRequest(url: url)
        req.timeoutInterval = 15
        req.setValue("Bearer \(ZincCredentials.apiKey)", forHTTPHeaderField: "Authorization")
        let (data, resp) = try await session.data(for: req)
        switch (resp as? HTTPURLResponse)?.statusCode ?? 0 {
        case 200:
            return SearchResponseMapper.products(from: data)
        case 401, 403:
            throw ZincError.unauthorized
        case let code:
            throw ZincError.http(code, String(data: data, encoding: .utf8) ?? "")
        }
    }

    /// One-shot credential check for the Settings/onboarding "Verify" button.
    /// Runs a minimal keyed search with the supplied key and reports whether the
    /// key is accepted — without touching the stored key or the demo fallback.
    enum KeyCheck { case valid, invalid, networkError }

    func verify(key: String) async -> KeyCheck {
        let trimmed = SecretsStore.clean(key)
        guard !trimmed.isEmpty, let url = searchURL("search", "phone") else {
            return .networkError
        }
        var req = URLRequest(url: url)
        req.timeoutInterval = 15
        req.setValue("Bearer \(trimmed)", forHTTPHeaderField: "Authorization")
        do {
            let (_, resp) = try await session.data(for: req)
            switch (resp as? HTTPURLResponse)?.statusCode ?? 0 {
            case 200:        return .valid
            case 401, 403:   return .invalid
            default:         return .networkError
            }
        } catch {
            return .networkError
        }
    }

    private func searchURL(_ path: String, _ query: String) -> URL? {
        var comps = URLComponents(url: baseURL.appendingPathComponent(path),
                                  resolvingAgainstBaseURL: false)
        comps?.queryItems = [.init(name: "q", value: query)]
        return comps?.url
    }

    // MARK: Create order (keyed, wallet-funded)

    /// `POST /orders` with a Bearer key. Funded by the account's prepaid wallet
    /// (default `payment.mode = wallet`). Returns the raw response so the caller
    /// can branch on 201 vs error.
    func createKeyedOrder(body: OrderRequestBody) async throws
        -> (response: HTTPURLResponse, data: Data) {
        var req = URLRequest(url: baseURL.appendingPathComponent("orders"))
        req.httpMethod = "POST"
        req.timeoutInterval = 30
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(ZincCredentials.apiKey)", forHTTPHeaderField: "Authorization")
        req.httpBody = try Self.encoder.encode(body)
        do {
            let (data, resp) = try await session.data(for: req)
            guard let http = resp as? HTTPURLResponse else {
                throw ZincError.transport("non-HTTP response")
            }
            return (http, data)
        } catch let e as ZincError { throw e }
        catch { throw ZincError.transport(error.localizedDescription) }
    }

    // MARK: Create order via MPP (the 402 dance is driven by OrderCoordinator)

    /// POST the order body. Pass `credential` (nil first, then the MPP credential).
    /// Returns the raw response so the caller can branch on 402 vs 201 and read
    /// the `X-Api-Key` / `WWW-Authenticate` headers.
    func createAgentOrder(body: OrderRequestBody, credential: String?) async throws
        -> (response: HTTPURLResponse, data: Data) {
        var req = URLRequest(url: baseURL.appendingPathComponent("agent/orders"))
        req.httpMethod = "POST"
        req.timeoutInterval = 30
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let credential { req.setValue(credential, forHTTPHeaderField: "Authorization") }
        req.httpBody = try Self.encoder.encode(body)
        do {
            let (data, resp) = try await session.data(for: req)
            guard let http = resp as? HTTPURLResponse else {
                throw ZincError.transport("non-HTTP response")
            }
            return (http, data)
        } catch let e as ZincError {
            throw e
        } catch {
            throw ZincError.transport(error.localizedDescription)
        }
    }

    func decodeOrder(_ data: Data) throws -> AgentOrderDTO {
        do {
            var dto = try Self.decoder.decode(AgentOrderDTO.self, from: data)
            dto.jobResultError = Self.jobResultError(from: data)
            return dto
        } catch { throw ZincError.decoding(error.localizedDescription) }
    }

    /// Pull a failure reason out of `job_result` when present. Its exact shape
    /// varies, so scan leniently and only surface something that looks like an
    /// error (never the success/price payload).
    static func jobResultError(from data: Data) -> String? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let jr = root["job_result"] as? [String: Any] else { return nil }
        if let err = jr["error"] as? [String: Any] {
            return (err["message"] as? String) ?? (err["code"] as? String) ?? "Order failed"
        }
        if let err = jr["error"] as? String { return err }
        let type = ((jr["type"] as? String) ?? (jr["_type"] as? String) ?? "").lowercased()
        if type.contains("error") || type.contains("fail") {
            return (jr["message"] as? String) ?? (jr["code"] as? String) ?? "Order failed"
        }
        return nil
    }

    // MARK: Status

    /// Poll order status. Keyed orders use the Bearer key; MPP orders use their
    /// per-order `X-Api-Key`.
    func getOrder(id: String, apiKey: String?) async throws -> AgentOrderDTO {
        var req = URLRequest(url: baseURL.appendingPathComponent("orders/\(id)"))
        req.timeoutInterval = 20
        if !ZincCredentials.apiKey.isEmpty {
            req.setValue("Bearer \(ZincCredentials.apiKey)", forHTTPHeaderField: "Authorization")
        } else if let apiKey {
            req.setValue(apiKey, forHTTPHeaderField: "X-Api-Key")
        }
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse else {
            throw ZincError.transport("non-HTTP response")
        }
        guard http.statusCode == 200 else {
            throw ZincError.http(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
        return try decodeOrder(data)
    }

    // MARK: Coders

    static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys]
        return e
    }()

    static let decoder = JSONDecoder()
}
