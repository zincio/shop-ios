import AppIntents

/// Registers the spoken phrases. Siri requires the app name (`\(.applicationName)`,
/// the app's display name "Zinc") in every App Shortcut phrase.
///
/// The `\(\.$product)` token is an `AppEntity` (`ProductEntity`), which App
/// Shortcut phrases allow inline; Siri resolves it via `ProductEntityQuery` and
/// presents the matches as a selectable list right in the Siri UI.
///
/// IMPORTANT — phrasing matters for Siri routing:
///  - Avoid the verb "buy". It's tied to Siri's built-in purchase/commerce
///    domain, which intercepts "buy …" ("I can't complete purchases…") before
///    the App Shortcut. Apple's own examples use "Order"/"Reorder" (see HIG).
///  - "…with \(.applicationName)" is included as an explicit template so "order
///    AA batteries with Zinc" binds the product (Siri treats the "with Zinc" tail
///    as the app suffix). In free speech "with zinc" can otherwise read as an
///    ingredient, so we keep the "on/from" framings too.
///
/// The parameterless "Order on \(.applicationName)" phrase is kept DELIBERATELY.
/// It's the headless fallback: Apple can't reliably extract an arbitrary product
/// from a spoken phrase and resolve it to a live search result on the first turn,
/// so when inline extraction fails Siri needs *something* to match. With this
/// phrase, it matches here and asks "What would you like to order?" once, then
/// runs the search and shows the picker — all still in Siri. WITHOUT it, a failed
/// extraction makes Siri bail and open the app instead. So this chooses
/// "any product, headless, at most one follow-up" over "opens the app".
///
/// The alternative (guaranteed first-turn but for a FIXED product vocabulary) is
/// `suggestedEntities()`; and guaranteed first-turn for arbitrary text only comes
/// from `SearchProductsIntent` (`.system.search`), which opens the app. This is a
/// hard App Intents limitation, not a bug — see the trade-off table in the PR.
struct ZincShopShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: BuyProductIntent(),
            phrases: [
                "Order \(\.$product) on \(.applicationName)",
                "Order \(\.$product) with \(.applicationName)",
                "Reorder \(\.$product) on \(.applicationName)",
                "Order \(\.$product) from \(.applicationName)",
                "Shop for \(\.$product) on \(.applicationName)",
                "Order on \(.applicationName)",
            ],
            shortTitle: "Order a Product",
            systemImageName: "cart.fill"
        )
    }
}
