import AppIntents

/// Registers the spoken phrases. Siri requires the app name (`\(.applicationName)`,
/// the app's display name "Zinc") in every App Shortcut phrase.
///
/// The `\(\.$product)` token is an `AppEntity` (`ProductEntity`), which App
/// Shortcut phrases allow inline — so Siri parses "Buy AA batteries with Zinc"
/// and resolves the product via `ProductEntityQuery` (any product search can
/// return), instead of falling back to its built-in "buy …" behavior (which was
/// routing to Reminders). The parameterless phrase lets a user say just "Buy
/// with Zinc" and get prompted.
struct ZincShopShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: BuyProductIntent(),
            phrases: [
                "Buy \(\.$product) with \(.applicationName)",
                "Order \(\.$product) with \(.applicationName)",
                "Get \(\.$product) with \(.applicationName)",
                "Buy \(\.$product) on \(.applicationName)",
                "Buy with \(.applicationName)",
            ],
            shortTitle: "Buy a Product",
            systemImageName: "cart.fill"
        )
    }
}
