#if canImport(VisualIntelligence)
import AppIntents
import VisualIntelligence

/// Registers Zinc with Visual Intelligence's visual-search domain and returns
/// richer product results shown inside the app. Delegates the actual matching to
/// `ProductSemanticSearchQuery` so there is one source of truth.
///
/// Conforms to the `.visualIntelligence.semanticContentSearch` schema (the system
/// `ShowVisualSearchResultsInAppIntent`), the signal that tells Visual Intelligence
/// the app owns visual product search. The system hands us a
/// `SemanticContentDescriptor` (captured frame + labels); we return
/// `[ProductEntity]` for the visual-search results panel. Lives behind
/// `#if canImport(VisualIntelligence)` because the framework ships only in the
/// device (iphoneos) SDK — the simulator build omits this file.
@available(iOS 26.0, *)
@AppIntent(schema: .visualIntelligence.semanticContentSearch)
struct ProductSemanticSearchIntent {
    // The schema requires a parameter named `semanticContent`; the system fills
    // it (captured frame + labels) before invoking `perform()`.
    @Parameter
    var semanticContent: SemanticContentDescriptor

    func perform() async throws -> some ReturnsValue<[ProductEntity]> {
        let results = try await ProductSemanticSearchQuery().values(for: semanticContent)
        return .result(value: results)
    }
}
#endif
