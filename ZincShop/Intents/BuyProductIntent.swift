import AppIntents
import SwiftUI

/// The Siri entry point: "Hey Siri, buy toilet paper with Zinc."
///
/// Runs the safe-to-do-headless part (search + confirmation) in the
/// Siri/Shortcuts UI, then stashes a `PendingPurchase` and continues into the
/// app so Apple Pay can present its sheet — Apple Pay's biometric approval is
/// the purchase guard *and* the payment.
///
/// NOTE: do NOT set `openAppWhenRun = true` here. That opens the app before
/// `perform()` runs, and the parameter prompt + `requestConfirmation` then try
/// to present over the half-launched app, leaving a black screen. The correct
/// pattern is `ForegroundContinuableIntent`: stay headless until after the
/// user confirms, then request the foreground transition explicitly.
struct BuyProductIntent: AppIntent, ForegroundContinuableIntent {
    static let title: LocalizedStringResource = "Buy a Product"
    static let description = IntentDescription("Search a retailer and buy the top match.")

    // An AppEnum (not a free-form String) so Siri can parse the product inline
    // in a phrase like "Buy paper towels with Zinc". If omitted, Siri asks and
    // offers the item list.
    @Parameter(title: "Item", requestValueDialog: "What would you like to buy?")
    var item: ShoppingItem

    static var parameterSummary: some ParameterSummary {
        Summary("Buy \(\.$item)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = ProfileStore.shared

        guard store.shipping.isComplete else {
            return .result(dialog: "Open Zinc and add your shipping address first, then try again.")
        }

        let query = item.searchQuery
        let products = try await ZincClient().search(query)
        guard let top = products.first else {
            return .result(dialog: "I couldn't find \(query).")
        }

        // Confirm with an interactive snippet before committing to buy.
        try await requestConfirmation(
            result: .result(
                dialog: "Buy \(top.title) for \(top.priceFormatted)?",
                view: ProductConfirmationSnippet(product: top)
            ),
            confirmationActionName: .buy
        )

        // Hand off to the app to collect payment via Apple Pay. RootView
        // observes pendingPurchase and presents the payment sheet on launch.
        store.pendingPurchase = PendingPurchase(product: top, quantity: 1)
        try await requestToContinueInForeground(
            "Ready to pay for \(top.title) with Apple Pay."
        )
        return .result(dialog: "Finish your purchase in Zinc.")
    }
}
