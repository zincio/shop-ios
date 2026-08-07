# Zinc iOS — voice shopping sample

A small SwiftUI app that buys **real products by voice** through the
[Zinc API](https://www.zinc.com/docs) — **no backend**. Ask Siri, pick a result,
and the order is placed and tracked with a Live Activity. It's a worked example
of wiring Zinc together with Apple's App Intents, Apple Pay, and Live Activities.

> **Just want to try it?** Email **ian@zinc.com** for TestFlight access.

> ⚠️ **Prototype, not production.** For convenience the demo can ship a Zinc key
> in the app bundle. A real app keeps secret keys on a server.

## Requirements

- **iOS 27 beta + Xcode 27 beta** (required — the app uses iOS 27 App Intents and
  Visual Intelligence; older versions won't build or behave correctly).
- **XcodeGen** — `brew install xcodegen` (the `.xcodeproj` is generated, not committed).
- A **Zinc API key** ([zinc.com](https://www.zinc.com/docs)) — optional; without one
  the app falls back to a small built-in demo catalog.

## Quick start

```bash
git clone git@github.com:zincio/shop-ios.git && cd shop-ios
brew install xcodegen
cp Config/Secrets.example.xcconfig Config/Secrets.xcconfig   # gitignored — fill in
xcodegen generate
open ZincShop.xcodeproj
```

Fill in `Config/Secrets.xcconfig`:

| Key | Needed for | Notes |
| --- | --- | --- |
| `ZINC_API_KEY` | search + ordering | Blank → demo catalog. You can also enter it in-app (stored in the Keychain). |
| `DEVELOPMENT_TEAM`, `APP_BUNDLE_PREFIX` | running on a device | Your Apple team ID + a reverse-DNS prefix you own. Leave blank for the Simulator. |
| `APPLE_PAY_MERCHANT_ID` | on-device Apple Pay | Only the keyless MPP path; register the ID under your team. |

`STRIPE_PUBLISHABLE_KEY` and the MPP/Apple Pay path are stubbed — not needed for
the default keyed flow. xcconfig values are literal (no quotes); escape URLs as
`https:/$()/api.zinc.com`.

## Run

```bash
# Simulator — no signing needed
xcodebuild build -scheme ZincShop -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO

# Tests
xcodebuild test -scheme ZincShop \
  -destination 'platform=iOS Simulator,name=iPhone 16' CODE_SIGNING_ALLOWED=NO
```

Re-run `xcodegen generate` after editing `project.yml` or adding/removing files.
The scheme runs **without the debugger** (`debugEnabled: false`) to dodge an iOS 27
beta crash — use **Console.app** (subsystem `io.zinc.zincshop`) for logs.

## How it works

- **Ordering** — with a Zinc key, `POST /orders` funded by the account's Zinc
  wallet (`OrderCoordinator`, `ZincClient`). No key → keyless MPP path
  (`402` + Apple Pay), which is partly stubbed.
- **Siri (in-Siri, two-turn)** — "Hey Siri, order on Zinc" → Siri asks what you
  want → you say it → it shows the top matches → **tap to order, no app**. (Apple
  doesn't allow one-shot spoken products for an open-ended catalog, so it's the
  two-turn flow.)
- **In-app** — search and tap-to-buy on the Shop tab; plus Visual Intelligence
  camera search.
- **Tracking** — a Live Activity on the Lock Screen / Dynamic Island.

## Layout

`ZincShop/` — app (`Services/` networking, `Intents/` Siri + Visual Intelligence,
`Features/` screens) · `ZincShopWidget/` — Live Activity · `Shared/` — shared code
· `Config/Secrets.xcconfig` — keys (gitignored) · `project.yml` — XcodeGen spec.

## License

[MIT](LICENSE).
