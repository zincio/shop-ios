# Visual Intelligence → Order Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Let a user point iOS Visual Intelligence at a product (or pick a photo) and land in Zinc's tap-to-buy flow for a matching product.

**Architecture:** Adopt the iOS 26/27 App Intents visual-intelligence path. Visual Intelligence hands our app a `SemanticContentDescriptor` (image + labels); an `IntentValueQuery` converts it to a text query (labels first, on-device Vision fallback), calls the existing `ZincClient.search`, and returns `ProductEntity` results into the system panel. Tapping a result runs an `OpenIntent` that sets `ProfileStore.pendingPurchase`, which `RootView` already presents as `PurchaseFlowView` (`.ready`, no auto-charge). No changes to order/payment code.

**Tech Stack:** Swift, SwiftUI, App Intents (`IntentValueQuery`, `@AppIntent(schema: .visualIntelligence.semanticContentSearch)`, `OpenIntent`), Vision (`VNClassifyImageRequest`), XcodeGen, XCTest.

**Design doc:** `docs/plans/2026-07-09-visual-intelligence-ordering-design.md`

---

## Conventions for every task

- Build: `xcodebuild build -project ZincShop.xcodeproj -scheme ZincShop -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO`
- Test: `xcodebuild test -project ZincShop.xcodeproj -scheme ZincShop -destination 'platform=iOS Simulator,name=iPhone 16' CODE_SIGNING_ALLOWED=NO`
- Single test: append `-only-testing:ZincShopTests/<Suite>/<method>`
- **After adding/removing ANY source or test file, run `xcodegen generate` before building** (per CLAUDE.md — new files silently won't compile/run otherwise).
- Commit after each task passes.

---

## Task 1: `SemanticQueryBuilder` — labels path (pure, injectable)

Build the image→query bridge as a pure type with the Vision call injected as a closure, so it is fully unit-testable without a real image or the Vision framework. This task covers only the labels branch and the nil branch.

**Files:**
- Create: `ZincShop/Intents/SemanticQueryBuilder.swift`
- Test: `ZincShopTests/SemanticQueryBuilderTests.swift`

**Step 1: Write the failing tests**

```swift
// ZincShopTests/SemanticQueryBuilderTests.swift
import XCTest
@testable import ZincShop

final class SemanticQueryBuilderTests: XCTestCase {
    func testUsesLabelsWhenPresent() async {
        let q = await SemanticQueryBuilder.query(
            labels: ["paper towels", "roll", "kitchen", "cardboard", "extra"],
            classify: { XCTFail("should not classify when labels exist"); return [] }
        )
        // Joins up to the top 3 labels, trimmed.
        XCTAssertEqual(q, "paper towels roll kitchen")
    }

    func testTrimsAndDropsEmptyLabels() async {
        let q = await SemanticQueryBuilder.query(
            labels: ["  ", "cast iron skillet ", ""],
            classify: { [] }
        )
        XCTAssertEqual(q, "cast iron skillet")
    }

    func testReturnsNilWhenNoLabelsAndNoClassification() async {
        let q = await SemanticQueryBuilder.query(labels: [], classify: { [] })
        XCTAssertNil(q)
    }
}
```

**Step 2: Run to verify it fails**

Run the single suite: `... -only-testing:ZincShopTests/SemanticQueryBuilderTests`
Expected: FAIL to compile — `SemanticQueryBuilder` undefined. (Remember `xcodegen generate` first so the new test file is in the target.)

**Step 3: Write minimal implementation**

```swift
// ZincShop/Intents/SemanticQueryBuilder.swift
import Foundation

/// Turns Visual Intelligence's `SemanticContentDescriptor` signal into a text
/// query for Zinc's text-only search. Pure and side-effect free: the actual
/// on-device Vision call is injected as `classify`, so this is unit-testable
/// without an image or the Vision framework.
enum SemanticQueryBuilder {
    /// Labels first (Visual Intelligence already computed them); fall back to the
    /// injected classifier (Vision) only when there are none; else `nil`.
    static func query(
        labels: [String],
        classify: () async -> [String]
    ) async -> String? {
        if let q = compose(labels) { return q }
        return compose(await classify())
    }

    /// Trim, drop empties, take the top 3, join with spaces. `nil` if nothing left.
    private static func compose(_ raw: [String]) -> String? {
        let cleaned = raw
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .prefix(3)
        return cleaned.isEmpty ? nil : cleaned.joined(separator: " ")
    }
}
```

**Step 4: Run to verify pass**

Run: `... -only-testing:ZincShopTests/SemanticQueryBuilderTests`
Expected: PASS (3 tests).

**Step 5: Commit**

```bash
xcodegen generate
git add ZincShop/Intents/SemanticQueryBuilder.swift ZincShopTests/SemanticQueryBuilderTests.swift project.yml
git commit -m "feat: SemanticQueryBuilder labels→query bridge"
```

---

## Task 2: Vision fallback classifier + builder fallback test

Add the real Vision-backed classifier and prove the builder falls back to it when labels are empty.

**Files:**
- Create: `ZincShop/Intents/VisionImageClassifier.swift`
- Test: `ZincShopTests/SemanticQueryBuilderTests.swift` (add one test)

**Step 1: Write the failing test (fallback branch)**

```swift
    func testFallsBackToClassifierWhenNoLabels() async {
        let q = await SemanticQueryBuilder.query(
            labels: [],
            classify: { ["mug", "cup"] }
        )
        XCTAssertEqual(q, "mug cup")
    }
```

**Step 2: Run to verify it fails**

Run: `... -only-testing:ZincShopTests/SemanticQueryBuilderTests/testFallsBackToClassifierWhenNoLabels`
Expected: PASS already if Task 1 logic is correct — this test locks the fallback contract. If it passes immediately, that's fine; keep it as a regression guard and proceed to add the real classifier.

**Step 3: Write the Vision classifier**

```swift
// ZincShop/Intents/VisionImageClassifier.swift
import Vision
import CoreVideo

/// On-device image classification used as the fallback when Visual Intelligence
/// provides no labels. Returns human-readable identifiers, most-confident first,
/// above a confidence threshold. Runs off the main thread.
enum VisionImageClassifier {
    static func labels(
        from pixelBuffer: CVPixelBuffer?,
        minimumConfidence: Float = 0.15,
        limit: Int = 3
    ) async -> [String] {
        guard let pixelBuffer else { return [] }
        let request = VNClassifyImageRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return []
        }
        let observations = (request.results ?? [])
            .filter { $0.confidence >= minimumConfidence }
            .prefix(limit)
        // Vision identifiers look like "coffee_mug"; humanize for search.
        return observations.map {
            $0.identifier.replacingOccurrences(of: "_", with: " ")
        }
    }
}
```

**Step 4: Run to verify pass + build**

Run the suite and a build (the classifier compiles against Vision):
`... -only-testing:ZincShopTests/SemanticQueryBuilderTests` then the build command.
Expected: tests PASS, build SUCCEEDS.

**Step 5: Commit**

```bash
xcodegen generate
git add ZincShop/Intents/VisionImageClassifier.swift ZincShopTests/SemanticQueryBuilderTests.swift project.yml
git commit -m "feat: on-device Vision fallback classifier"
```

---

## Task 3: Search-results → `[ProductEntity]` mapping + entity image

Factor the "search a query, sort, cache, map to entities" step (identical to `ProductEntityQuery.entities(matching:)`) into a shared spot so the new query reuses it DRY, and add a product image to `ProductEntity`'s display representation so the VI panel shows thumbnails.

**Files:**
- Modify: `ZincShop/Intents/ProductEntityQuery.swift` (extract a helper)
- Modify: `ZincShop/Intents/ProductEntity.swift:19-24` (add image to `DisplayRepresentation`)
- Test: `ZincShopTests/SemanticQueryBuilderTests.swift` or a new `ProductEntityMappingTests.swift`

**Step 1: Write the failing test**

```swift
// ZincShopTests/ProductEntityMappingTests.swift
import XCTest
@testable import ZincShop

final class ProductEntityMappingTests: XCTestCase {
    func testMapsAndSortsCheapestFirst() {
        let products = [
            Product(url: "b", title: "B", priceCents: 900, imageURL: nil, retailer: "amazon"),
            Product(url: "a", title: "A", priceCents: 100, imageURL: nil, retailer: "amazon"),
        ]
        let entities = ProductEntityMapping.entities(from: products)
        XCTAssertEqual(entities.map(\.id), ["a", "b"])
    }
}
```

**Step 2: Run to verify it fails**

Run: `... -only-testing:ZincShopTests/ProductEntityMappingTests`
Expected: FAIL — `ProductEntityMapping` undefined.

**Step 3: Implement the helper and reuse it**

Add to `ProductEntityQuery.swift` (same file, keeps intents together):

```swift
/// Shared mapping so every entry point (typed/spoken query, visual search)
/// sorts and shapes results identically.
enum ProductEntityMapping {
    static func entities(from products: [Product]) -> [ProductEntity] {
        products.sorted { $0.priceCents < $1.priceCents }.map(ProductEntity.init)
    }
}
```

Then refactor `ProductEntityQuery.entities(matching:)` to use it:

```swift
    func entities(matching string: String) async throws -> [ProductEntity] {
        let products = try await ZincClient().search(string)
        await ProductEntityCache.shared.store(products)
        return ProductEntityMapping.entities(from: products)
    }
```

Add the image to `ProductEntity.displayRepresentation` (`ProductEntity.swift`):

```swift
    var displayRepresentation: DisplayRepresentation {
        let price = (Double(priceCents) / 100).formatted(.currency(code: "USD"))
        let image: DisplayRepresentation.Image? = imageURL.map { .init(url: $0) }
        return priceCents > 0
            ? DisplayRepresentation(title: "\(title)", subtitle: "\(price)", image: image)
            : DisplayRepresentation(title: "\(title)", image: image)
    }
```

> Verify `DisplayRepresentation.Image(url:)` exists in the installed SDK. If not, drop the image argument (title+price still render) and note it — do not block the feature on the thumbnail.

**Step 4: Run tests + build**

Expected: PASS + build SUCCEEDS. Existing `ProductEntityQuery` behavior unchanged (regression-covered by any existing intent tests).

**Step 5: Commit**

```bash
xcodegen generate
git add ZincShop/Intents/ProductEntity.swift ZincShop/Intents/ProductEntityQuery.swift ZincShopTests/ProductEntityMappingTests.swift project.yml
git commit -m "refactor: shared ProductEntity mapping + entity thumbnail"
```

---

## Task 4: `ProductSemanticSearchQuery: IntentValueQuery`

The query Visual Intelligence calls. Wires descriptor → builder → search → entities. Lenient: any failure returns `[]`.

**Files:**
- Create: `ZincShop/Intents/ProductSemanticSearchQuery.swift`

> **SDK verification first (2 min):** confirm the real member names on `SemanticContentDescriptor` — the image accessor (expected `pixelBuffer`) and the labels accessor (expected `labels: [String]`). Adjust the two extraction lines below to match. The pure `SemanticQueryBuilder` does not depend on this type, so only this file changes if names differ.

**Step 1: Implement**

```swift
// ZincShop/Intents/ProductSemanticSearchQuery.swift
import AppIntents

/// Bridges Visual Intelligence to Zinc search. The system calls `values(for:)`
/// with the captured image + labels; we derive a text query (labels first,
/// on-device Vision fallback), run the existing keyed search, and return
/// products as `ProductEntity` for the visual-search results panel.
@available(iOS 26.0, *)
struct ProductSemanticSearchQuery: IntentValueQuery {
    func values(for input: SemanticContentDescriptor) async throws -> [ProductEntity] {
        // VERIFY these two accessors against the SDK (see note above).
        let labels = input.labels
        let query = await SemanticQueryBuilder.query(labels: labels) {
            await VisionImageClassifier.labels(from: input.pixelBuffer)
        }
        guard let query else { return [] }

        let products = (try? await ZincClient().search(query)) ?? []
        await ProductEntityCache.shared.store(products)
        return ProductEntityMapping.entities(from: products)
    }
}
```

**Step 2: Build**

Run the build command. Expected: SUCCEEDS. (No unit test — this is thin glue over already-tested units; the builder/mapper/classifier are covered. Behavior is device-verified in Task 7.)

**Step 3: Commit**

```bash
xcodegen generate
git add ZincShop/Intents/ProductSemanticSearchQuery.swift project.yml
git commit -m "feat: IntentValueQuery for visual intelligence product search"
```

---

## Task 5: `ProductSemanticSearchIntent` (visual-intelligence schema)

The schema intent that registers the app with Visual Intelligence and drives the richer in-app results surface.

**Files:**
- Create: `ZincShop/Intents/ProductSemanticSearchIntent.swift`

> **SDK verification first:** confirm the schema intent shape for `.visualIntelligence.semanticContentSearch` in the installed SDK — the criteria parameter type (expected `SemanticContentDescriptor`) and the required return (`some ReturnsValue<[ProductEntity]>` vs. an associated `IntentValueQuery` registration). Use whichever the schema macro requires; the body stays the same.

**Step 1: Implement**

```swift
// ZincShop/Intents/ProductSemanticSearchIntent.swift
import AppIntents

/// Registers Zinc with Visual Intelligence's visual-search domain and returns
/// richer product results shown inside the app. Delegates the actual matching
/// to `ProductSemanticSearchQuery` so there is one source of truth.
@available(iOS 26.0, *)
@AppIntent(schema: .visualIntelligence.semanticContentSearch)
struct ProductSemanticSearchIntent {
    var criteria: SemanticContentDescriptor

    func perform() async throws -> some ReturnsValue<[ProductEntity]> {
        let results = try await ProductSemanticSearchQuery().values(for: criteria)
        return .result(value: results)
    }
}
```

**Step 2: Build**

Expected: SUCCEEDS. If the schema macro rejects the shape, follow the compiler's fix-it / the SDK doc for `AppSchema.VisualIntelligenceIntent.semanticContentSearch` and adjust.

**Step 3: Commit**

```bash
xcodegen generate
git add ZincShop/Intents/ProductSemanticSearchIntent.swift project.yml
git commit -m "feat: visual intelligence semanticContentSearch intent"
```

---

## Task 6: Tap-to-open → `pendingPurchase`

When the user taps a product in the VI panel, open the app straight into that product's purchase flow, reusing the exact `pendingPurchase` path `BuyProductIntent` uses (starts in `.ready`, no auto-charge).

**Files:**
- Create: `ZincShop/Intents/OpenProductIntent.swift`

**Step 1: Implement**

```swift
// ZincShop/Intents/OpenProductIntent.swift
import AppIntents

/// Opens Zinc to a specific product chosen from a Visual Intelligence result and
/// stages it for purchase. `OpenIntent` foregrounds the app; `RootView` already
/// observes `pendingPurchase` and presents `PurchaseFlowView` in its `.ready`
/// state (Confirm Order / Apple Pay) — we never auto-charge.
@available(iOS 26.0, *)
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
```

> **SDK/behavior verification:** confirm how a visual-search result binds its tap action to an entity `OpenIntent`. On current App Intents, declaring an `OpenIntent` whose `target` is `ProductEntity` makes the entity openable. If the schema requires the entity to declare its opener explicitly, wire that per the SDK. Verify on device (Task 7) that tapping a result foregrounds Zinc with the purchase sheet.

**Step 2: Build**

Expected: SUCCEEDS.

**Step 3: Commit**

```bash
xcodegen generate
git add ZincShop/Intents/OpenProductIntent.swift project.yml
git commit -m "feat: open tapped visual-search product into purchase flow"
```

---

## Task 7: Full build, regression run, and device verification

**Step 1: Regenerate + full build + all tests**

```bash
xcodegen generate
# build (simulator)
xcodebuild build -project ZincShop.xcodeproj -scheme ZincShop -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO
# all unit tests
xcodebuild test -project ZincShop.xcodeproj -scheme ZincShop -destination 'platform=iOS Simulator,name=iPhone 16' CODE_SIGNING_ALLOWED=NO
```

Expected: build SUCCEEDS; all suites PASS (new `SemanticQueryBuilderTests`, `ProductEntityMappingTests`, plus existing).

**Step 2: Device verification (documented; not automatable — per CLAUDE.md Siri/AI caveats)**

On an Apple-Intelligence-capable device running iOS 26/27:
1. Open Visual Intelligence (Camera Control / Control Center / Lock Screen).
2. Point at a product (e.g. a roll of paper towels) or select a photo → **Search**.
3. Confirm **Zinc** appears among app results and shows product cards (title, price, thumbnail).
4. Tap a card → Zinc foregrounds into `PurchaseFlowView` in `.ready` for that product.
5. Confirm the Confirm Order / Apple Pay button behaves as in the normal flow; dev mode still caps `max_price = 0`.

Log via Console.app (subsystem `io.zinc.zincshop`) since the debugger is disabled on the beta.

**Step 3: Update docs**

- Add a short "Visual Intelligence ordering" note to the Siri/App Intents section of `CLAUDE.md` and `README.md` (mirrors how `SearchProductsIntent` is documented): entry point, the labels→Vision bridge, and that tap-through reuses `pendingPurchase`.

**Step 4: Commit**

```bash
git add CLAUDE.md README.md
git commit -m "docs: document Visual Intelligence ordering feature"
```

---

## Notes / open verifications (resolve during implementation)

1. `SemanticContentDescriptor` member names (`pixelBuffer`, `labels`) — Task 4.
2. `.visualIntelligence.semanticContentSearch` schema intent shape (criteria type + return) — Task 5.
3. Entity tap→open binding for visual-search results — Task 6.
4. `DisplayRepresentation.Image(url:)` availability — Task 3.

All four are localized to a single file each and do not affect the pure, tested core (`SemanticQueryBuilder`, `VisionImageClassifier`, `ProductEntityMapping`). The xcode docs MCP dropped mid-session; use `mcp__xcode__DocumentationSearch` if it reconnects, else check the SDK headers / a WWDC "Visual intelligence" sample.
