import AppIntents

/// Registers the spoken phrases. Siri requires the app name (`\(.applicationName)`,
/// the app's display name "Zinc") in every App Shortcut phrase.
///
/// The `\(\.$product)` token is an `AppEntity` (`ProductEntity`), which App
/// Shortcut phrases allow inline; Siri resolves it via `ProductEntityQuery`.
///
/// IMPORTANT — phrasing matters for Siri routing:
///  - Avoid the verb "buy". It's tied to Siri's built-in purchase/commerce
///    domain, which intercepts "buy …" ("I can't complete purchases…") before
///    the App Shortcut. Apple's own examples use "Order"/"Reorder" (see HIG).
///  - Use "on/from \(.applicationName)" rather than "with Zinc": "Zinc" is a
///    common word (the metal), and "…with zinc" reads to Siri like a product
///    ingredient. "on Zinc"/"from Zinc" frames it as the app.
struct ZincShopShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: BuyProductIntent(),
            phrases: [
                "Order \(\.$product) on \(.applicationName)",
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
