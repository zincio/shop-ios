#if DEBUG
import AppIntents

/// DEBUG-only, non-discoverable intents that let the AppIntentsTesting UI tests
/// drive and inspect app state out-of-process. This is Apple's recommended
/// pattern (see "Use testing-only intents for setup and teardown") — the UI test
/// bundle can't import app types, so it manipulates state through intents rather
/// than UI automation. `isDiscoverable = false` keeps them out of Siri/Shortcuts,
/// and `#if DEBUG` keeps them out of release builds.

/// Resets the profile to a known state before a test: sets shipping to a complete
/// or empty address and clears any staged purchase.
struct ResetProfileForTestingIntent: AppIntent {
    static let title: LocalizedStringResource = "Reset Profile For Testing"
    static let isDiscoverable = false

    @Parameter(title: "Complete Shipping")
    var completeShipping: Bool

    @MainActor
    func perform() async throws -> some IntentResult {
        let store = ProfileStore.shared
        store.pendingPurchase = nil
        store.shipping = completeShipping
            ? ShippingProfile(firstName: "Test", lastName: "Buyer",
                              addressLine1: "1 Infinite Loop", addressLine2: "",
                              city: "Cupertino", state: "CA", postalCode: "95014",
                              country: "US", phoneNumber: "5555555555")
            : ShippingProfile()
        return .result()
    }
}

/// Returns the title of the currently staged pending purchase, or "" if none, so
/// a test can assert whether `BuyProductIntent` reached its foreground hand-off.
struct ReadPendingPurchaseTitleIntent: AppIntent {
    static let title: LocalizedStringResource = "Read Pending Purchase Title"
    static let isDiscoverable = false

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        .result(value: ProfileStore.shared.pendingPurchase?.product.title ?? "")
    }
}
#endif
