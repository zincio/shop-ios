import AppIntents

/// Registers the spoken phrases. Siri requires the app name (`\(.applicationName)`,
/// the app's display name "Zinc") in every App Shortcut phrase.
///
/// The `\(\.$item)` token is an `AppEnum` (`ShoppingItem`), which App Shortcut
/// phrases DO allow inline — so Siri parses "Buy paper towels with Zinc" as the
/// item directly instead of falling back to its built-in "buy …" behavior
/// (which was routing to Reminders). The parameterless phrases let a user say
/// just "Buy with Zinc" and get prompted for the item.
struct ZincShopShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: BuyProductIntent(),
            phrases: [
                "Buy \(\.$item) with \(.applicationName)",
                "Order \(\.$item) with \(.applicationName)",
                "Get \(\.$item) with \(.applicationName)",
                "Buy \(\.$item) on \(.applicationName)",
                "Buy with \(.applicationName)",
            ],
            shortTitle: "Buy a Product",
            systemImageName: "cart.fill"
        )
    }
}
