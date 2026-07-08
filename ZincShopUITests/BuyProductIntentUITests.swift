// End-to-end tests built on AppIntentsTesting, which ships only in the iOS 27 SDK
// (Xcode 27+) — it's absent from the iOS 26.5 SDK the default /Applications/Xcode.app
// uses. This target is therefore isolated in its own `ZincShopIntentTests` scheme so
// the standard `ZincShop` scheme still builds and tests under the stable Xcode.
//
// HOW TO RUN: Xcode 27, `ZincShopIntentTests` scheme, Product ▸ Test — or headless
// on a real device (verified passing):
//
//   DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcodebuild test \
//     -project ZincShop.xcodeproj -scheme ZincShopIntentTests \
//     -destination 'id=<your-iphone-udid>' -allowProvisioningUpdates
//
// NOTE: these only pass under real development signing. A *simulator* always
// ad-hoc-signs ("Sign to Run Locally"), which AppIntentsServices rejects — error
// 803 ("internal tests on a Customer build") with CODE_SIGNING_ALLOWED=NO, or error
// 800 ("app does not have permission … io.zinc.zincshop") otherwise. A device signs
// with your Apple Development cert + provisioning profile, which clears both.
import XCTest
import AppIntentsTesting

/// End-to-end tests for the Siri purchase intent, exercised through the real App
/// Intents infrastructure (the same code path Siri and Shortcuts use) via the
/// AppIntentsTesting framework. These run out-of-process against the live app, so
/// they live in a UI-test bundle and reference every type by string name.
///
/// What we deliberately do NOT drive to completion: the full purchase.
/// `BuyProductIntent.perform()`'s happy path calls `requestConfirmation` (needs an
/// interactive tap) and then places a real wallet-funded order — neither is safe
/// nor possible to automate. We cover the two regression-prone, side-effect-free
/// parts instead: product resolution (the path Siri uses to find a product) and
/// the pre-confirmation guard.
final class BuyProductIntentUITests: XCTestCase {
    private let app = XCUIApplication()
    private var definitions: IntentDefinitions!

    override func setUp() async throws {
        continueAfterFailure = false
        await app.launch()
        definitions = IntentDefinitions(bundleIdentifier: "io.zinc.zincshop")
    }

    /// The core Siri resolution path: turn a typed/spoken product string into a
    /// `ProductEntity` via `ProductEntityQuery.entities(matching:)`. This is what
    /// silently breaks when Siri "can't find" a product. `MockCatalog` backs
    /// search, so the assertion holds even without a network or API key.
    func testProductEntityResolvesSearchTerm() async throws {
        let products = definitions.entities["ProductEntity"]
        let matches = try await products.entities(matching: "paper towels")
        XCTAssertFalse(matches.isEmpty,
                       "Expected 'paper towels' to resolve at least one ProductEntity")
    }

    /// With no shipping address set, the intent must short-circuit with guidance
    /// and never reach `requestConfirmation` or stage a pending purchase. That the
    /// run even completes is itself meaningful — the happy path would block
    /// awaiting a confirmation tap.
    func testMissingShippingShortCircuitsBeforePurchase() async throws {
        try await definitions.intents["ResetProfileForTestingIntent"]
            .makeIntent(completeShipping: false)
            .run()

        let products = definitions.entities["ProductEntity"]
        let matches = try await products.entities(matching: "paper towels")
        let product = try XCTUnwrap(matches.first,
                                    "Search should resolve a product to feed the intent")

        _ = try await definitions.intents["BuyProductIntent"]
            .makeIntent(product: product)
            .run()

        let pending = try await definitions.intents["ReadPendingPurchaseTitleIntent"]
            .makeIntent()
            .run()
        XCTAssertEqual(try pending.value, "",
                       "Guard must not stage a pending purchase when shipping is missing")
    }
}
