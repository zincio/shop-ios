import AppIntents

/// Registers the spoken phrases. Siri requires the app name in App Shortcut
/// phrases (the app's display name is "Zinc").
///
/// NOTE: App Shortcut phrases may only embed `AppEntity`/`AppEnum` parameters,
/// not a free-form `String`. So we can't capture an arbitrary product in a
/// single utterance via a static phrase. Instead the user says "Buy with Zinc"
/// and Siri prompts "What would you like to buy?" (the parameter's
/// `requestValueDialog`), which accepts any product. To make a true one-shot
/// "buy toilet paper with Zinc" work, model the product as an AppEnum of common
/// items or an AppEntity with a dynamic query.
struct ZincShopShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: BuyProductIntent(),
            phrases: [
                "Buy something with \(.applicationName)",
                "Order with \(.applicationName)",
                "Shop with \(.applicationName)",
            ],
            shortTitle: "Buy a Product",
            systemImageName: "cart.fill"
        )
    }
}
