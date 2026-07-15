# Shop with Zinc on iOS — "Hey Siri, order paper towels using Zinc"

A small, complete SwiftUI sample app that buys **real products by voice** through
the [Zinc](https://www.zinc.com/docs) API — with **no backend needed**. The app talks straight to `api.zinc.com`: ask Siri (or search in-app),
confirm, and the order is placed and tracked with a Live Activity.

It's meant to be read as much as run — a worked example of wiring the Zinc API
into a native iOS app, including the Apple-platform pieces (App Intents, Visual
Intelligence, Apple Pay, Live Activities) that make it feel like a real shopping
assistant. Some iOS 27 features may be required to run this app properly.

> ⚠️ **Prototype, not production.** For convenience the demo can ship a Zinc API
> key inside the app bundle. Production app must keep secret keys on a server/backend!
> See [Security & going to production](#security--going-to-production).

## What you'll learn

- **Calling the Zinc API from Swift** — product search and order placement over
  plain `URLRequest`/`async-await`, with no SDK (`ZincClient`, `OrderCoordinator`).
- **Two ordering models**, selected automatically by whether a key is present:
  a **keyed** wallet-funded path (`Bearer` key), and a **keyless MPP** path
  (Machine Payments Protocol: HTTP `402` paid with Apple Pay — no key on device).
- **Siri voice ordering** with the App Intents framework (`BuyProductIntent`,
  `ProductEntity`) — including the phrasing/routing gotchas that trip Siri up.
- **Visual Intelligence** search — point the camera at a product and buy the match.
- **Live Activities** for order tracking on the Lock Screen / Dynamic Island.
- **Keychain**, **Apple Pay**, **Face ID / passcode**, and an **XcodeGen**-managed
  project with secrets in a gitignored `.xcconfig`.

## The Zinc API surface this app uses

Everything the app does maps to a handful of endpoints. This is the core of the
integration — start here, then follow the code references.

| Endpoint             | Auth                                 | What it does                  | In code                       |
| -------------------- | ------------------------------------ | ----------------------------- | ----------------------------- |
| `GET /search?q=…`    | `Bearer` key                         | Cross-retailer product search | `ZincClient.keyedSearch`      |
| `POST /orders`       | `Bearer` key                         | Place a wallet-funded order   | `OrderCoordinator.keyedOrder` |
| `GET /orders/{id}`   | `Bearer` (keyed) / `X-Api-Key` (MPP) | Order status & tracking       | `OrderTracker`                |
| `POST /agent/orders` | none → `402` → Apple Pay             | Keyless order via MPP         | `OrderCoordinator.mppOrder`   |

**Keyed vs. keyless.** With a Zinc API key set, search and ordering use the
`Bearer` paths above and the order is funded by the account's Zinc wallet. With
**no** key, ordering falls back to MPP: `POST /agent/orders` returns `402 Payment
Required`, the app pays the Stripe challenge with Apple Pay, and retries — so it
needs no secret key at all. Search has no keyless API tier; without a key it
serves a small built-in demo catalog (`MockCatalog`) so the app still runs offline.

### Why MPP is interesting

The keyless MPP path is what lets an app transact with **no backend and no secret
key on device** — worth understanding even though the default here is the keyed path:

| Concern                                          | Stripe Connect    | **MPP**                      |
| ------------------------------------------------ | ----------------- | ---------------------------- |
| Zinc secret key on device                        | required          | **none** — unauth until paid |
| Card vaulting (Customer/SetupIntent, secret key) | required          | **none** — pay-per-request   |
| Stripe key on device                             | secret/restricted | **publishable only** (safe)  |
| Status auth                                      | master key        | **per-order `X-Api-Key`**    |

The live MPP `402` flow (both Stripe and Tempo rails) is verified against
`api.zinc.com` by `ZincShopTests/PaymentChallengeTests.swift`, which parses a real
captured challenge.

## Prerequisites

- **Xcode 16 or later** (the optional App-Intents end-to-end tests need Xcode 27).
- **[XcodeGen](https://github.com/yonaskolb/XcodeGen)** — `brew install xcodegen`.
- A **Zinc API key** — sign up at [zinc.com](https://www.zinc.com/docs). Optional:
  skip it to explore the keyless MPP + demo-catalog paths.
- For on-device features (Siri, Apple Pay, Face ID, Live Activities): a **real
  device** and an **Apple Developer team**. The Simulator covers everything else.

## Getting started

```bash
git clone <this-repo> && cd zinc-ios
brew install xcodegen                                   # once
cp Config/Secrets.example.xcconfig Config/Secrets.xcconfig   # gitignored — fill in below
xcodegen generate                                       # generates ZincShop.xcodeproj
open ZincShop.xcodeproj
```

`Config/Secrets.xcconfig` is where your keys and signing identity live (it's
gitignored, so nothing personal is committed). The example file documents each
value:

| Key                                    | Needed for              | Notes                                                                    |
| -------------------------------------- | ----------------------- | ------------------------------------------------------------------------ |
| `ZINC_BASE_URL`                        | all API calls           | Defaults to `https://api.zinc.com`.                                      |
| `ZINC_API_KEY`                         | keyed search + ordering | Leave blank to use the keyless MPP + demo paths.                         |
| `STRIPE_PUBLISHABLE_KEY`               | Apple Pay (MPP)         | Publishable key — safe to ship.                                          |
| `APPLE_PAY_MERCHANT_ID`                | on-device Apple Pay     | Must be registered under your team.                                      |
| `DEVELOPMENT_TEAM`/`APP_BUNDLE_PREFIX` | building to a device    | Your team ID + a bundle prefix you own; blank is fine for the Simulator. |

> **Tip:** you don't have to bake `ZINC_API_KEY` into the build. You can enter
> your key during onboarding or in **Settings**, and the app stores it in the
> **Keychain** (`ZincCredentials`), which is the more realistic and more secure
> path. A key entered in-app takes priority over the build-time one.

> **xcconfig gotcha:** values are literal — no quotes, and `//` starts a comment,
> so escape URLs as `https:/$()/api.zinc.com`.

## Build & run

```bash
# Build the app + widget for the Simulator (no signing needed)
xcodebuild build -scheme ZincShop -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO

# Run the unit tests
xcodebuild test -scheme ZincShop \
  -destination 'platform=iOS Simulator,name=iPhone 16' CODE_SIGNING_ALLOWED=NO
```

If `-destination` can't find that device, list what you have with
`xcrun simctl list devices available` and pass one by `name=` or `id=<UUID>`.

**Regenerate after structural changes.** The `.xcodeproj` is generated and
gitignored — re-run `xcodegen generate` after editing `project.yml` or
adding/removing/renaming any source or test file (a new test file silently won't
run until you do).

## Voice flow

1. **"Hey Siri, order paper towels on Zinc."** The product is an `AppEntity`
   (`ProductEntity`), so Siri parses it inline; say just "order on Zinc" to be
   prompted. (Avoid the verb "buy" — it collides with Siri's built-in purchase
   domain; see `ZincShopShortcuts.swift`.)
2. Siri resolves the product and shows the match + price in a confirmation snippet.
3. On confirm, the order is placed:
   - **With an API key (default):** placed right in Siri, headless — **Face ID /
     passcode** authorizes it, then `POST /orders` (`Bearer`, wallet-funded). The
     app never opens.
   - **Without a key:** the app foregrounds so **Apple Pay** can pay the MPP `402`
     challenge — Apple Pay can't present from a background intent.
4. The order is tracked with a **Live Activity** (Lock Screen / Dynamic Island),
   polled with the `Bearer` key (keyed) or the per-order `X-Api-Key` (MPP).

You can also search and tap-to-buy entirely in-app on the Shop tab — no voice
required.

## Visual Intelligence

Point your camera at a product (or pick a photo), tap **Search → Zinc**, and tap a
match to buy — photo → results → in-app Apple Pay. Needs a real
Apple-Intelligence device; see `ZincShop/Intents/` (the
`.visualIntelligence.semanticContentSearch` schema).

## First run: enabling the Siri shortcut

App Shortcuts don't respond to Siri until they're enabled for the app. On first
launch the app walks you through onboarding (welcome → shipping address → enable
Siri). If Siri answers _"I can't … in the Zinc app"_ instead of running the
shortcut, it isn't enabled yet:

1. **Shortcuts** app → search "Zinc" → make sure **"Order a Product"** /
   **Use with Siri** is on. (Or **Settings → Apps → Zinc → Siri**.)
2. Launch Zinc once and finish onboarding — a shipping address is required by the
   order intent.
3. Say **"Hey Siri, order paper towels on Zinc"** (also try toilet paper, coffee,
   laundry detergent, dish soap). Give Siri ~30s after install to index.

> Non-voice entry points that always work: tap **"Order a Product"** in the
> Shortcuts app, Spotlight, or the Action Button.

## Project layout

- `ZincShop/` — the app.
  - `Models/` — Codable DTOs and domain types.
  - `Services/` — networking and coordinators (`ZincClient`, `OrderCoordinator`,
    `OrderTracker`, Apple Pay, Keychain).
  - `Intents/` — Siri & Visual Intelligence App Intents (`BuyProductIntent`,
    `ProductEntity`, the Visual Intelligence search).
  - `Features/` — SwiftUI screens (incl. `Onboarding`).
  - `App/` — entry point and root gating.
- `ZincShopWidget/` — the Live Activity UI.
- `Shared/` — code compiled into both the app and the widget.
- `ZincShopTests/` — unit tests: search mapping, order encode/decode, challenge
  parsing, the price-cap guard, secret cleaning.
- `Config/Secrets.xcconfig` — your keys + signing identity (gitignored).
- `project.yml` — the XcodeGen spec; the `.xcodeproj` is generated, not committed.

## Security & going to production

This is a demo. Before real money changes hands:

- **Move ordering behind a backend.** The keyed path uses a Zinc API key that, in
  this prototype, can ship inside the app bundle. That key can place real orders —
  a production app must hold it server-side and place orders from there. (The
  keyless MPP path is the model for how a keyless client _can_ transact.)
- **Wire up the MPP/Stripe seam.** `StripeMPPAdapter.credential(...)` builds the
  MPP credential envelope from the Apple Pay token but is stubbed; a real build
  charges via the Stripe iOS SDK from the `402` challenge and confirms the
  credential format with Zinc.
- Ordering is capped by a user-set **price cap** and gated by **Face ID /
  passcode**; **Dev Mode** (Settings) sends `max_price = 0` so orders never
  finalize — use it to exercise the flow without charges.
- Scope today: single retailer per order (Amazon), single top-result purchase, no
  cart or returns.

### Running on the iOS 27 beta

Currently (as of xcode-beta 3), the scheme sets `debugEnabled: false` (runs **without** the debugger).
Attaching the debugger on iOS 27 triggers a backtrace-recording crash
(`-[OS_dispatch_mach_msg _setContext:]: unrecognized selector`). Consequence: no
breakpoints / Xcode console while running — use **Console.app** (subsystem
`io.zinc.zincshop`) or `xcrun simctl spawn <dev> log stream`. Revert to
`debugEnabled: true` in `project.yml` once the OS ships and the bug is fixed.

## License

Released under the [MIT License](LICENSE) — free to use, modify, and learn from.
