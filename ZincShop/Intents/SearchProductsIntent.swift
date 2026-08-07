import AppIntents

/// Exposes Zinc product search to Siri and Apple Intelligence via the system
/// `.system.search` assistant schema.
///
/// Adopting the schema is what tells Siri the app *owns* product search, so an
/// utterance like "Search Zinc for paper towels" is routed here instead of being
/// swallowed by Siri's built-in shopping domain — which otherwise refuses with
/// "I can't search for or buy items directly within the Zinc app" before our own
/// intents ever run.
///
/// CONFIRMED on iOS 27 (2026-08-05): disabling this intent does NOT fall back to
/// BuyProductIntent's in-Siri pick list — Siri refuses the whole request. So this
/// must stay enabled. The unavoidable trade-off is that spoken shopping phrases
/// route here and OPEN THE APP on the Shop tab (they can't render a list inside
/// Siri). The in-Siri pick list is only reachable via the Shortcuts app / when
/// Siri chooses BuyProductIntent — not guaranteeable by voice. This is an Apple
/// platform limitation, not a code bug (filed via Feedback Assistant).
///
/// It opens the app on the Shop tab with the spoken term pre-run; the user taps a
/// result to pay. Fully hands-free ordering isn't offered here on purpose.
@available(iOS 18.2, *)
@AppIntent(schema: .system.search)
struct SearchProductsIntent {
    static let searchScopes: [StringSearchScope] = [.general]

    var criteria: StringSearchCriteria

    @MainActor
    func perform() async throws -> some IntentResult {
        // Hand the spoken term to the running app; RootView switches to the Shop
        // tab and HomeView runs the search. perform() executes in-process, so
        // this is the same ProfileStore the UI observes.
        ProfileStore.shared.pendingSearch = criteria.term
        return .result()
    }
}
