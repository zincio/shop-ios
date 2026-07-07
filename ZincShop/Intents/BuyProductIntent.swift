import AppIntents
import SwiftUI

/// The Siri entry point: "Hey Siri, order toilet paper on Zinc."
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
    static let title: LocalizedStringResource = "Order a Product"
    static let description = IntentDescription("Search a retailer and order the top match.")

    // An AppEntity (not a free-form String) so Siri can parse ANY product inline
    // in a phrase like "Order AA batteries on Zinc". Siri resolves the words via
    // ProductEntityQuery before perform() runs; if omitted, it asks and offers
    // suggestions.
    @Parameter(title: "Product", requestValueDialog: "What would you like to order?")
    var product: ProductEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Order \(\.$product)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = ProfileStore.shared

        guard store.shipping.isComplete else {
            return .result(dialog: "Open Zinc and add your shipping address first, then try again.")
        }

        // Siri already resolved the product via ProductEntityQuery — no re-search.
        let top = product.product

        // Confirm with an interactive snippet before committing to the order.
        // Use `.order`, NOT `.buy`: `.buy` is a commerce-domain action name that
        // makes Siri intercept the whole intent ("I can't … place orders …") and
        // refuse before we run. `.order` is Apple's recommended purchase action.
        try await requestConfirmation(
            actionName: .order,
            dialog: "Order \(top.title) for \(top.priceFormatted)?"
        ) {
            ProductConfirmationSnippet(product: top)
        }

        // Hand off to the app to collect payment via Apple Pay. RootView
        // observes pendingPurchase and presents the payment sheet on launch.
        store.pendingPurchase = PendingPurchase(product: top, quantity: 1)
        try await requestToContinueInForeground(
            "Ready to pay for \(top.title) with Apple Pay."
        )
        return .result(dialog: "Finish your purchase in Zinc.")
    }
}
