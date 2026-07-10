#if canImport(VisualIntelligence)
import AppIntents
import CoreVideo
import VisualIntelligence

/// Bridges Visual Intelligence to Zinc search. The system calls the query with
/// the captured image + labels; we derive a text query (labels first, on-device
/// Vision fallback), run the existing keyed search, and return products as
/// `ProductEntity` for the visual-search results panel. Lenient: any failure
/// yields no results rather than surfacing an error in the system panel.
@available(iOS 26.0, *)
struct ProductSemanticSearchQuery: IntentValueQuery {
    func values(for input: SemanticContentDescriptor) async throws -> [ProductEntity] {
        // Labels first; only if Visual Intelligence gives none do we classify the
        // frame ourselves. The pixel buffer is valid only inside `withUnsafeBuffer`,
        // so classify synchronously in-scope — never let the buffer escape.
        let query = await SemanticQueryBuilder.query(labels: input.labels) {
            input.pixelBuffer?.withUnsafeBuffer { VisionImageClassifier.labels(from: $0) } ?? []
        }
        guard let query else { return [] }

        let products = (try? await ZincClient().search(query)) ?? []
        await ProductEntityCache.shared.store(products)
        return ProductEntityMapping.entities(from: products)
    }
}
#endif
