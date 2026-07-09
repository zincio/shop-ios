# Visual Intelligence → Order (design)

Date: 2026-07-09
Status: Approved (design phase)

## Goal

Let a user point Siri's Visual Intelligence (Camera Control / Control Center /
Lock Screen) at a real product — or pick a photo — and be taken straight into
Zinc's tap-to-buy flow for a matching product. Photo → product → Apple Pay.

## Why the schema-based Visual Intelligence path (not a hand-rolled camera)

iOS 26/27 App Intents ship a purpose-built path for this:

- **`IntentValueQuery`** — "provides entity values to the system, for example
  for visual intelligence search." We implement `values(for:)` and return
  `AppEntity` results.
- **`SemanticContentDescriptor`** — what the system hands the query: the
  captured **image (pixel buffer)** plus system-detected **labels**.
- **`@AppIntent(schema: .visualIntelligence.semanticContentSearch)`** — renders
  richer visual search results in the app and opens Zinc when a result is tapped.

Rejected alternative: a custom in-app "scan to shop" camera + our own
`VNClassifyImageRequest`. It works on more OS versions but duplicates Apple's
capture/crop UX, forgoes the system entry points, and is more code. On the
iOS 27 beta the schema path is strictly better.

The one constant: **Zinc search is text-only** (no image/reverse search), so the
query handler must convert the descriptor into a text query and call
`ZincClient.search`.

## User flow

1. User invokes Visual Intelligence, points at a product (or picks a photo).
2. Taps **Search**, picks **Zinc** among the app results.
3. Visual Intelligence calls our query with a `SemanticContentDescriptor`. We
   derive a text query, call `ZincClient.search`, return `[ProductEntity]` into
   the system panel (rendered from each entity's `DisplayRepresentation` —
   product image, title, price).
4. User taps a result → Zinc opens directly to that product in
   `PurchaseFlowView` (`.ready` state) → taps **Confirm Order / Apple Pay**.
   We stop short of auto-charging; `PurchaseFlowView` already starts in `.ready`.

## New pieces (all under `ZincShop/Intents/`)

- **`ProductSemanticSearchQuery: IntentValueQuery`** —
  `values(for: SemanticContentDescriptor) -> [ProductEntity]`. Home of the
  image→query bridge; calls `ZincClient.search` and maps results.
- **`ProductSemanticSearchIntent`** —
  `@AppIntent(schema: .visualIntelligence.semanticContentSearch)`, returns
  `[ProductEntity]` for the in-app results surface / entry point.
- **Tap-to-open** — an `OpenIntent` over `ProductEntity` (or the entity's open
  behavior) that sets `ProfileStore.pendingPurchase` and foregrounds the app —
  the same path `BuyProductIntent` already uses.

Reused as-is: `ProductEntity`, `ZincClient.search`, `ProfileStore.pendingPurchase`,
`RootView`'s `.sheet(item:)`, `PurchaseFlowView`. No order/payment code changes.

## Image → query bridge

A pure, unit-testable helper `SemanticQueryBuilder`:

```
query(from descriptor) -> String?
  1. descriptor.labels non-empty      → join top labels into a query string
  2. else VNClassifyImageRequest(pixelBuffer) → top label(s) above a threshold
  3. else                             → nil (no confident match)
```

`ProductSemanticSearchQuery.values(for:)`: if the builder returns a string, call
`ZincClient.search` and map to `[ProductEntity]`; on `nil`, return `[]`. Vision
runs on-device, off the main thread.

Decision: **labels first, Vision fallback** (chosen over labels-only and
Vision-only) for robustness with no backend.

## Error handling

- No labels + no confident Vision result → `[]`, no crash/alert.
- `ZincClient.search` throws → catch, return `[]` (matches the app's existing
  lenient search-fallback posture; failure is invisible in the VI panel).
- Missing shipping on tap-through → existing guards handle it; mirror
  `BuyProductIntent`'s "add your shipping address first" message.
- Dev mode / price cap → untouched; enforced by the existing `PurchaseFlowView`.

## Testing & project wiring

- **Unit tests** (`SemanticQueryBuilderTests`): labels-present uses labels;
  labels-empty exercises the Vision path with a fixture `CVPixelBuffer`; nothing
  confident → `nil`. Plus a mapper test: search results → `[ProductEntity]`.
- **Device-only** (documented, not automated — per CLAUDE.md's Siri caveats):
  the real VI panel needs Apple-Intelligence hardware + iOS 26/27; the simulator
  can't exercise it.
- **Project wiring:** new files under `ZincShop/Intents/`; run
  **`xcodegen generate`** after adding them or they won't build. Verify the
  `.visualIntelligence.semanticContentSearch` schema symbols against the
  installed SDK during implementation (xcode docs MCP dropped mid-session).
```

