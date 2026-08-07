import AppIntents

/// Registers the spoken phrases. Every phrase must contain the app name
/// (`\(.applicationName)` → "Zinc").
///
/// All phrases are DELIBERATELY parameterless. Apple's App Shortcut phrases
/// can't carry an open-ended parameter — an `AppEntity` used inline needs a
/// finite, known vocabulary via `suggestedEntities()` (see WWDC22 "Implement App
/// Shortcuts with App Intents"). Our catalog is open-ended, so a
/// `"Order \(\.$product) on Zinc"` phrase can't reliably bind an arbitrary spoken
/// product — in practice it either fails to carry the product or gets routed to
/// the `.system.search` app-opener. A parameterless phrase, by contrast, reaches
/// `BuyProductIntent` cleanly; its required `product` is then captured by the
/// follow-up prompt ("What would you like to order?") → `entities(matching:)`
/// live search → the in-Siri results list. That two-turn flow is the supported
/// pattern for open-ended search, and it's the one that actually works on-device.
struct ZincShopShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: BuyProductIntent(),
            phrases: [
                "Order on \(.applicationName)",
                "Order something on \(.applicationName)",
                "Get me something on \(.applicationName)",
                "Reorder on \(.applicationName)",
                "Shop on \(.applicationName)",
                "Start an order on \(.applicationName)",
                "Order from \(.applicationName)",
            ],
            shortTitle: "Order a Product",
            systemImageName: "cart.fill"
        )
    }
}
