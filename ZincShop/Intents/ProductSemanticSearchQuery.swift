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
        // `SemanticContentDescriptor.pixelBuffer` is a `CVReadOnlyPixelBuffer?`
        // whose underlying `CVPixelBuffer` is only vended inside `withUnsafeBuffer`.
        // Grab that reference once so we can hand it to the (async) classifier.
        let pixelBuffer: CVPixelBuffer? = input.pixelBuffer?.withUnsafeBuffer { $0 }

        let query = await SemanticQueryBuilder.query(labels: input.labels) {
            await VisionImageClassifier.labels(from: pixelBuffer)
        }
        guard let query else { return [] }

        let products = (try? await ZincClient().search(query)) ?? []
        await ProductEntityCache.shared.store(products)
        return ProductEntityMapping.entities(from: products)
    }
}
#endif
