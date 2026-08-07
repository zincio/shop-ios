import AppIntents
import SwiftUI

/// The Siri entry point: "Hey Siri, order paper towels from Zinc."
///
/// Fully in-Siri, no app launch:
///  1. Siri resolves the spoken product via `ProductEntityQuery` — it asks
///     "What would you like to order?", the user speaks it, `entities(matching:)`
///     runs a live Zinc search, and Siri shows the matches as its own **picker
///     list** (rendered from `ProductEntity.displayRepresentation` — image +
///     concise title + price).
///  2. The user taps the one they want → it resolves into `product` → `perform()`
///     places the wallet-funded order **headlessly** (the tap is the
///     authorization; keyed path needs no Apple Pay) and returns an "Ordered ✓"
///     result card. No app, no second list.
///
/// Keyless MPP would still need the app for Apple Pay — out of scope here; branch
/// on `ZincCredentials.apiKey` if that case ever matters.
struct BuyProductIntent: AppIntent {
    static let title: LocalizedStringResource = "Order a Product"
    static let description = IntentDescription("Search Zinc and order the product you pick, right in Siri.")

    @Parameter(title: "Product", requestValueDialog: "What would you like to order?")
    var product: ProductEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Order \(\.$product)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let store = ProfileStore.shared
        let top = product.product

        guard store.shipping.isComplete else {
            return .result(dialog: "Open Zinc and add your shipping address first, then try again.",
                           view: OrderPlacedSnippet(title: top.title, state: .failed("Add a shipping address in Zinc.")))
        }

        do {
            let order = try await OrderCoordinator().purchase(
                product: top, quantity: 1, shipping: store.shipping,
                maxPriceCents: store.priceCapCents, devMode: store.devMode,
                requireBiometric: false
            )
            store.upsert(order)
            OrderTracker.shared.track(order)
            LiveActivityManager.start(for: order)
            return .result(dialog: "Ordered \(top.title). I'll keep track of it for you.",
                           view: OrderPlacedSnippet(title: top.title, state: .ordered))
        } catch let error as PaymentError {
            let reason = error.errorDescription ?? "I couldn't place that order."
            return .result(dialog: "\(reason)", view: OrderPlacedSnippet(title: top.title, state: .failed(reason)))
        } catch {
            // Keep it short — the raw Zinc body can be a wall of JSON.
            let reason = Self.shortReason(error.localizedDescription)
            return .result(dialog: "I couldn't place that order.",
                           view: OrderPlacedSnippet(title: top.title, state: .failed(reason)))
        }
    }

    private static func shortReason(_ raw: String) -> String {
        let line = raw.split(whereSeparator: \.isNewline).first.map(String.init) ?? raw
        return line.count > 80 ? String(line.prefix(80)) + "…" : line
    }
}

/// Compact result card shown in Siri after an order is placed (or fails).
struct OrderPlacedSnippet: View {
    enum State { case ordered, failed(String) }
    let title: String
    let state: State

    var body: some View {
        HStack(spacing: 10) {
            icon
            VStack(alignment: .leading, spacing: 1) {
                Text(headline).font(.subheadline.weight(.semibold))
                Text(title).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                if case .failed(let reason) = state {
                    Text(reason).font(.caption2).foregroundStyle(.red).lineLimit(2)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 8).padding(.horizontal, 12)
    }

    private var headline: String {
        switch state {
        case .ordered: return "Ordered"
        case .failed:  return "Couldn't order"
        }
    }

    @ViewBuilder private var icon: some View {
        switch state {
        case .ordered: Image(systemName: "checkmark.seal.fill").font(.title3).foregroundStyle(.green)
        case .failed:  Image(systemName: "xmark.octagon.fill").font(.title3).foregroundStyle(.red)
        }
    }
}
