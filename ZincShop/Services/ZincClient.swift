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

    func search(_ query: String, retailer: String = "amazon") async throws -> [Product] {
        do {
            let live = try await liveSearch(query, retailer: retailer)
            if !live.isEmpty { return live }
        } catch {
            // Live search is metered/unverified in this prototype — fall back.
        }
        return try await searchFallback.search(query)
    }

    /// Cross-retailer search: GET /search?q=… with a Bearer API key.
    /// Returns [] (→ fallback) when no key is configured or the call fails.
    private func liveSearch(_ query: String, retailer: String) async throws -> [Product] {
        let key = SecretsStore.zincApiKey
        guard !key.isEmpty else { return [] }
        var comps = URLComponents(url: baseURL.appendingPathComponent("search"),
                                  resolvingAgainstBaseURL: false)
        comps?.queryItems = [.init(name: "q", value: query)]
        guard let url = comps?.url else { return [] }
        var req = URLRequest(url: url)
        req.timeoutInterval = 15
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else { return [] }
        return SearchResponseMapper.products(from: data)
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
