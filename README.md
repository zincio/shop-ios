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

1. "Hey Siri, **buy with Zinc**" → Siri asks "What would you like to buy?"
   (App Shortcut phrases can't embed free-form text, so the product is a
   follow-up prompt — see note in `ZincShopShortcuts.swift`).
2. The intent searches Zinc and shows the top match + price in a confirmation
   snippet.
3. On confirm, the app foregrounds and presents **Apple Pay** — the biometric
   tap is both the purchase guard and the payment (Apple Pay can't appear from a
   background intent).
4. Order placed → tracked via a Live Activity (Lock Screen / Dynamic Island).

## Project layout

- `ZincShop/` — app: `Models`, `Services` (ZincClient, MPP coordinator, Apple
  Pay), `Intents` (Siri), `Features` (SwiftUI), plus `App`.
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

## Prototype limitations / TODO before real money

- **Stripe integration seam** — `StripeMPPAdapter.credential(...)` currently
  builds the MPP credential envelope from the Apple Pay token. Wire in the
  Stripe iOS SDK to actually charge the connected account from the 402 `request`
  (publishable key, `STPApplePayContext`), and confirm the credential format
  with Zinc. This is the one piece that can't be exercised offline.
- **Search** — `ZincClient.search` tries the live agent-search endpoint and
  falls back to a small demo catalog (`MockCatalog`) of real Amazon URLs so the
  flow always works. Swap to live results once the search contract is confirmed.
- Single retailer (Amazon), single top-result purchase; no cart/returns.
- One-shot "buy toilet paper with Zinc" needs the product modeled as an
  AppEnum/AppEntity (see `ZincShopShortcuts.swift`).
