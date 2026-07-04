# Zinc — "Hey Siri, buy toilet paper"

A SwiftUI iOS prototype that buys real products by voice. Ask Siri to buy
something, confirm with a glance (Apple Pay = Face ID), and the order is placed
through the [Zinc](https://www.zinc.com/docs) commerce API and tracked with a
Live Activity.

## How it works (no backend)

This app talks **directly** to Zinc using its **MPP (Machine Payments Protocol)**
agent endpoint — chosen specifically so the app needs no server and ships no
secret keys:

```
POST /agent/orders   (no auth)         → 402 Payment Required + WWW-Authenticate
   ⮑ pay the Stripe challenge with Apple Pay (publishable key, on-device)
POST /agent/orders   (Authorization)   → 201 Created  (+ order-scoped X-Api-Key)
GET  /orders/{id}    (X-Api-Key)        → status + tracking
```

Why MPP instead of Stripe Connect:

| Concern | Stripe Connect | **MPP (used here)** |
|---|---|---|
| Zinc secret key on device | required | **none** — unauth until paid |
| Card vaulting (Customer/SetupIntent, secret key) | required | **none** — pay-per-request |
| Stripe key on device | secret/restricted | **publishable only** (safe) |
| Status auth | master key | **per-order `X-Api-Key`** |

The live MPP 402 flow (both Stripe and Tempo rails) is verified against
`api.zinc.com`; see `ZincShopTests/PaymentChallengeTests.swift`, which parses a
real captured challenge.

## Voice flow

1. "Hey Siri, **order paper towels on Zinc**." The product is an `AppEntity`
   (`ProductEntity`), so Siri parses it inline; say just "order on Zinc" to be
   prompted. (Avoid "buy" — it collides with Siri's built-in purchase domain;
   see `ZincShopShortcuts.swift`.)
2. The intent resolves the product and shows the match + price in a confirmation
   snippet.
3. On confirm, the app foregrounds and presents **Apple Pay** — the biometric
   tap is both the purchase guard and the payment (Apple Pay can't appear from a
   background intent).
4. Order placed → tracked via a Live Activity (Lock Screen / Dynamic Island).

## First run: enabling the Siri shortcut (required)

On first launch the app shows a short onboarding (`OnboardingView`): welcome →
shipping address → **enable Siri**. App Shortcuts don't respond to Siri until
they're enabled for the app, so if Siri answers *"I can't … in the Zinc app"*
instead of running the shortcut, it isn't enabled yet:

1. **Shortcuts** app → search "Zinc" → make sure **"Order a Product"** is enabled
   / **Use with Siri** is on. (Or **Settings → Apps → Zinc → Siri**.)
2. Launch Zinc once and finish onboarding (shipping is required by the intent).
3. Say **"Hey Siri, order paper towels on Zinc"** (also: toilet paper, coffee,
   laundry detergent, dish soap). Give Siri ~30s after install to index.

> Non-voice entry points that always work: tap **"Order a Product"** in the
> Shortcuts app, Spotlight, or the Action Button.

## Project layout

- `ZincShop/` — app: `Models`, `Services` (ZincClient, MPP coordinator, Apple
  Pay), `Intents` (Siri: `BuyProductIntent`, `ProductEntity`), `Features`
  (SwiftUI, incl. `Onboarding`), plus `App`.
- `ZincShopWidget/` — Live Activity UI.
- `Shared/` — `OrderTrackingAttributes` (app + widget).
- `ZincShopTests/` — challenge parsing, order encode/decode, search.
- `Config/Secrets.xcconfig` — publishable key, merchant id, base URL (gitignored).
- `project.yml` — XcodeGen spec (the `.xcodeproj` is generated, not committed).

## Build & run

```bash
brew install xcodegen          # if needed
cp Config/Secrets.example.xcconfig Config/Secrets.xcconfig   # fill in real values
xcodegen generate
open ZincShop.xcodeproj
```

CLI build + test:

```bash
xcodebuild build -scheme ZincShop -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO
xcodebuild test  -scheme ZincShop \
  -destination 'platform=iOS Simulator,name=iPhone 16' CODE_SIGNING_ALLOWED=NO
```

For Siri, Apple Pay, and Face ID you need a **real device** with a development
team, the Apple Pay capability, and a registered merchant id.

### Running on the iOS 27 beta

The scheme sets `debugEnabled: false` (runs **without** the debugger). Attaching
the debugger on iOS 27 triggers a backtrace-recording crash
(`-[OS_dispatch_mach_msg _setContext:]: unrecognized selector`). Consequence:
no breakpoints / Xcode console while running — use **Console.app** (subsystem
`io.zinc.zincshop`) or `xcrun simctl spawn <dev> log stream`. Revert to
`debugEnabled: true` in `project.yml` once the OS ships and the bug is fixed.

## Prototype limitations / TODO before real money

- **Stripe integration seam** — `StripeMPPAdapter.credential(...)` currently
  builds the MPP credential envelope from the Apple Pay token. Wire in the
  Stripe iOS SDK to actually charge the connected account from the 402 `request`
  (publishable key, `STPApplePayContext`), and confirm the credential format
  with Zinc. This is the one piece that can't be exercised offline.
- **Search** — `ZincClient.search` calls Zinc's cross-retailer search
  (`GET /search?q=…`, Bearer key) and falls back to a small demo catalog
  (`MockCatalog`) when no key is set or the call fails. Add your key to
  `Config/Secrets.xcconfig` as `ZINC_API_KEY` to enable live results.
  ⚠️ Demo only — the Bearer key ships on-device; a production build must move
  search behind a backend.
- Single retailer per order (Amazon), single top-result purchase; no cart/returns.
