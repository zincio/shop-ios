import AppIntents

/// Exposes Zinc product search to Siri and Apple Intelligence via the system
/// `.system.search` assistant schema.
///
/// Adopting the schema is what tells Siri the app *owns* product search, so an
/// utterance like "Search Zinc for paper towels" is routed here instead of being
/// swallowed by Siri's built-in shopping domain — which otherwise refuses with
/// "I can't search for items or place orders directly within the Zinc app"
/// before our own intents ever run. A plain custom `AppIntent` + commerce-sounding
/// App Shortcut phrases isn't enough; the schema conformance is the signal Siri's
/// NLU looks for (see Apple's "Making in-app search actions available to Siri and
/// Apple Intelligence").
///
/// It opens the app on the Shop tab with the spoken term pre-run; the user taps a
/// result to pay with Apple Pay. Fully hands-free ordering isn't offered here on
/// purpose: the built-in commerce domain intercepts spoken "order/buy" phrases,
/// and Apple Pay can't present from a background intent anyway (see
/// `BuyProductIntent`).
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
