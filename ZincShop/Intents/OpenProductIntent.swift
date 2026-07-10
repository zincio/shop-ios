import AppIntents

/// Opens Zinc to a specific product chosen from a Visual Intelligence result and
/// stages it for purchase. `OpenIntent` foregrounds the app; `RootView` already
/// observes `pendingPurchase` and presents `PurchaseFlowView` in its `.ready`
/// state (Confirm Order / Apple Pay) — we never auto-charge. Associating an
/// `OpenIntent` with `ProductEntity` is also what makes the entity "openable" for
/// the Visual Intelligence `IntentValueQuery` results (required by the App Intents
/// metadata processor).
///
/// Unlike `BuyProductIntent`, there's deliberately no shipping-completeness guard
/// here: this foregrounds the app and lands on `PurchaseFlowView`, where an
/// incomplete address is handled in-app — versus the headless intent, which must
/// bail before it loses the chance to prompt.
struct OpenProductIntent: OpenIntent {
    static let title: LocalizedStringResource = "Open Product"

    @Parameter(title: "Product")
    var target: ProductEntity

    @MainActor
    func perform() async throws -> some IntentResult {
        ProfileStore.shared.pendingPurchase = PendingPurchase(product: target.product, quantity: 1)
        return .result()
    }
}
