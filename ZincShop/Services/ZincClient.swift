import Foundation

enum ZincError: LocalizedError {
    case http(Int, String)
    case decoding(String)
    case noProductsFound
    case transport(String)

    var errorDescription: String? {
        switch self {
        case .http(let code, let msg): return "Zinc error \(code): \(msg)"
        case .decoding(let m): return "Couldn't read Zinc response: \(m)"
        case .noProductsFound: return "No products found."
        case .transport(let m): return "Network error: \(m)"
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

    /// Satisfies a `402` search challenge and returns the MPP credential to
    /// retry with. Provided by the foreground caller (Apple Pay); omit it and
    /// the metered MPP search is skipped.
    typealias SearchPayment = (_ challenges: [PaymentChallenge]) async throws -> String

    /// Search priority:
    /// 1. Keyed cross-retailer search (`GET /search`, Bearer) when `ZINC_API_KEY`
    ///    is set — no per-call charge. Chosen over `/products/search` because it
    ///    returns star ratings and many more results (the retailer-specific
    ///    endpoint returns null stars and only a handful of items).
    /// 2. MPP agent search (`GET /agent/search`, $0.01 per call via 402) when no
    ///    key but a `payment` closure is supplied to satisfy the challenge.
    /// 3. Built-in demo catalog otherwise / on any failure.
    func search(_ query: String, payment: SearchPayment? = nil) async throws -> [Product] {
        if !SecretsStore.zincApiKey.isEmpty {
            if let live = try? await keyedSearch(query), !live.isEmpty { return live }
        } else if let payment {
            if let live = try? await mppSearch(query, payment: payment), !live.isEmpty { return live }
        }
        return try await searchFallback.search(query)
    }

    /// Cross-retailer search: `GET /search?q=…` with a Bearer API key. Results
    /// carry `url`, per-item `retailer`, and `stars`.
    private func keyedSearch(_ query: String) async throws -> [Product] {
        guard let url = searchURL("search", query) else { return [] }
        var req = URLRequest(url: url)
        req.timeoutInterval = 15
        req.setValue("Bearer \(SecretsStore.zincApiKey)", forHTTPHeaderField: "Authorization")
        let (data, resp) = try await session.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { return [] }
        return SearchResponseMapper.products(from: data)
    }

    /// MPP agent search: `GET /agent/search?q=…`. No key; pays the 402 challenge
    /// ($0.01) via the injected `payment` closure, then retries.
    private func mppSearch(_ query: String, payment: SearchPayment) async throws -> [Product] {
        guard let url = searchURL("agent/search", query) else { return [] }
        func get(_ credential: String?) async throws -> (HTTPURLResponse, Data) {
            var req = URLRequest(url: url)
            req.timeoutInterval = 20
            if let credential { req.setValue(credential, forHTTPHeaderField: "Authorization") }
            let (data, resp) = try await session.data(for: req)
            guard let http = resp as? HTTPURLResponse else { throw ZincError.transport("non-HTTP response") }
            return (http, data)
        }

        var (resp, data) = try await get(nil)
        if resp.statusCode == 402 {
            let credential = try await payment(PaymentChallenge.parseAll(from: resp))
            (resp, data) = try await get(credential)
        }
        guard resp.statusCode == 200 else { return [] }
        return SearchResponseMapper.products(from: data)
    }

    private func searchURL(_ path: String, _ query: String) -> URL? {
        var comps = URLComponents(url: baseURL.appendingPathComponent(path),
                                  resolvingAgainstBaseURL: false)
        comps?.queryItems = [.init(name: "q", value: query)]
        return comps?.url
    }

    // MARK: Create order (the 402 dance is driven by MPPPaymentCoordinator)

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
        do { return try Self.decoder.decode(AgentOrderDTO.self, from: data) }
        catch { throw ZincError.decoding(error.localizedDescription) }
    }

    // MARK: Status

    func getOrder(id: String, apiKey: String?) async throws -> AgentOrderDTO {
        var req = URLRequest(url: baseURL.appendingPathComponent("orders/\(id)"))
        req.timeoutInterval = 20
        if let apiKey { req.setValue(apiKey, forHTTPHeaderField: "X-Api-Key") }
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
