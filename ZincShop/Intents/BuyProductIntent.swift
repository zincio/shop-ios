import AppIntents
import SwiftUI

/// The Siri entry point: "Hey Siri, buy toilet paper with Zinc."
///
/// Runs the safe-to-do-headless part (search + confirmation), then stashes a
/// `PendingPurchase` and opens the app so Apple Pay can present its sheet —
/// Apple Pay's biometric approval is the purchase guard *and* the payment.
struct BuyProductIntent: AppIntent {
    static let title: LocalizedStringResource = "Buy a Product"
    static let description = IntentDescription("Search a retailer and buy the top match.")

    /// Opening the app lets us present Apple Pay (it can't appear from a
    /// background intent).
    static let openAppWhenRun = true

    @Parameter(title: "Product", requestValueDialog: "What would you like to buy?")
    var productQuery: String

    static var parameterSummary: some ParameterSummary {
        Summary("Buy \(\.$productQuery)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = ProfileStore.shared

        guard store.shipping.isComplete else {
            return .result(dialog: "Open Zinc and add your shipping address first, then try again.")
        }

        let products = try await ZincClient().search(productQuery)
        guard let top = products.first else {
            return .result(dialog: "I couldn't find \(productQuery).")
        }

        // Confirm with an interactive snippet before committing to buy.
        try await requestConfirmation(
            result: .result(
                dialog: "Buy \(top.title) for \(top.priceFormatted)?",
                view: ProductConfirmationSnippet(product: top)
            ),
            confirmationActionName: .buy
        )

        // Hand off to the app to collect payment via Apple Pay.
        store.pendingPurchase = PendingPurchase(product: top, quantity: 1)
        return .result(dialog: "Opening Zinc to confirm payment for \(top.title).")
    }
}
