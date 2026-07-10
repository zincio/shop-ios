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
/// here: this foregrounds the app and lands on `PurchaseFlowView`, matching the
/// other in-app buy entry points (`HomeView`, `OrderListView`), which also present
/// it unguarded. The headless intent must guard because it can't prompt once it
/// loses the foreground; here an incomplete address just surfaces as the normal
/// in-app failure card.
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
