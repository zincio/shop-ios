import AppIntents
import SwiftUI

/// The Siri entry point: "Hey Siri, order toilet paper on Zinc."
///
/// Stays **fully headless** whenever it can:
///  - Search + the confirmation snippet always run in the Siri/Shortcuts UI.
///  - **Keyed (API-key) path:** the order is wallet-funded (`POST /orders`) with
///    no Apple Pay, so the whole purchase completes right in Siri — Siri's order
///    confirmation is the authorization, and we speak the result. The app never
///    opens.
///  - **Keyless (MPP) path:** ordering needs Apple Pay, which *cannot* present
///    from a background intent, so — and only then — we hand off to the app via
///    `requestToContinueInForeground`.
///
/// NOTE: do NOT set `openAppWhenRun = true`. That opens the app before
/// `perform()` runs, and the parameter prompt + `requestConfirmation` then try
/// to present over the half-launched app, leaving a black screen. The correct
/// pattern is `ForegroundContinuableIntent`: stay headless, and foreground
/// explicitly only for the Apple Pay path.
struct BuyProductIntent: AppIntent, ForegroundContinuableIntent {
    static let title: LocalizedStringResource = "Order a Product"
    static let description = IntentDescription("Search Zinc for a product and order the top match.")

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

        // Keyed path: place the wallet-funded order right here, headless. No
        // Apple Pay, no app — Siri's confirmation above is the authorization.
        if !ZincCredentials.apiKey.isEmpty {
            do {
                let order = try await OrderCoordinator().purchase(
                    product: top, quantity: 1, shipping: store.shipping,
                    maxPriceCents: store.priceCapCents, devMode: store.devMode,
                    requireBiometric: false
                )
                store.upsert(order)
                OrderTracker.shared.track(order)
                LiveActivityManager.start(for: order)
                return .result(dialog: "Ordered \(top.title). I'll keep track of it for you.")
            } catch let error as PaymentError {
                let reason = error.errorDescription ?? "I couldn't place that order."
                return .result(dialog: "\(reason)")
            } catch {
                return .result(dialog: "I couldn't place that order: \(error.localizedDescription)")
            }
        }

        // Keyless (MPP) path: Apple Pay must present, which can't happen from a
        // background intent — hand off to the app. RootView observes
        // pendingPurchase and presents the payment sheet on launch.
        store.pendingPurchase = PendingPurchase(product: top, quantity: 1)
        try await requestToContinueInForeground(
            "Ready to pay for \(top.title) with Apple Pay."
        )
        return .result(dialog: "Finish your purchase in Zinc.")
    }
}

