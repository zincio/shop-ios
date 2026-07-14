import SwiftUI

/// Presents the order confirmation for a product and reports the outcome.
/// Used both for Siri-initiated purchases (via `ProfileStore.pendingPurchase`)
/// and direct in-app buys from `HomeView`. With an API key, ordering is
/// wallet-funded and guarded by Face ID; without one, it pays via Apple Pay (MPP).
struct PurchaseFlowView: View {
    let product: Product
    var quantity: Int = 1
    /// Called once the order is successfully placed (e.g. to clear the search).
    var onOrdered: (() -> Void)? = nil

    @EnvironmentObject private var store: ProfileStore
    @Environment(\.dismiss) private var dismiss
    @State private var phase: Phase = .ready

    private let coordinator = OrderCoordinator()
    private var keyed: Bool { !ZincCredentials.apiKey.isEmpty }

    enum Phase: Equatable {
        case ready, paying, success(OrderRecord), failure(PurchaseFailure)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                ProductConfirmationSnippet(product: product)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))

                content
                Spacer()
            }
            .padding()
            .navigationTitle("Confirm Purchase")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder private var content: some View {
        switch phase {
        case .ready:
            VStack(spacing: 8) {
                Button(action: { Task { await pay() } }) {
                    Label(keyed ? "Confirm Order" : "Pay with Apple Pay",
                          systemImage: keyed ? "faceid" : "applelogo")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                if store.devMode {
                    Label("Dev mode: max price $0 — order won't complete.",
                          systemImage: "hammer.fill")
                        .font(.caption).foregroundStyle(.orange)
                } else {
                    Text("Face ID confirms your purchase. Cap: \(capFormatted).")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        case .paying:
            ProgressView("Placing your order…")
        case .success(let order):
            VStack(spacing: 12) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.largeTitle).foregroundStyle(.green)
                Text("Ordered!").font(.title2.bold())
                Text("Order \(order.id.prefix(8))… is on the way.")
                    .font(.footnote).foregroundStyle(.secondary)
                Button("Done") { dismiss() }.buttonStyle(.bordered)
            }
        case .failure(let failure):
            VStack(spacing: 12) {
                Image(systemName: "xmark.octagon.fill")
                    .font(.largeTitle).foregroundStyle(.red)
                Text(failure.title).font(.headline)
                Text(failure.message)
                    .font(.subheadline).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                failureAction(failure.recovery)
            }
        }
    }

    /// The recovery button for a failure, chosen by how the error can be resolved.
    @ViewBuilder private func failureAction(_ recovery: PurchaseFailure.Recovery) -> some View {
        switch recovery {
        case .retry:
            Button("Try Again") { phase = .ready }.buttonStyle(.borderedProminent)
        case .adjustCap:
            Button("Close") { dismiss() }.buttonStyle(.bordered)
        case .dismiss:
            Button("Close") { dismiss() }.buttonStyle(.bordered)
        }
    }

    private var capFormatted: String {
        (Double(store.priceCapCents) / 100).formatted(.currency(code: "USD"))
    }

    private func pay() async {
        // In-flight guard: a fast double-tap can enqueue two `pay()` tasks while
        // `phase` is still `.ready` (the `.paying` swap below is what normally
        // hides the button). Bail if an order is already in flight so we don't
        // submit twice. Runs before the first `await`, so main-actor
        // serialization guarantees the second task sees `.paying` and returns.
        guard phase == .ready else { return }
        phase = .paying
        do {
            let order = try await coordinator.purchase(
                product: product, quantity: quantity,
                shipping: store.shipping, maxPriceCents: store.priceCapCents,
                devMode: store.devMode
            )
            store.upsert(order)
            LiveActivityManager.start(for: order)
            OrderTracker.shared.track(order)
            store.pendingPurchase = nil
            onOrdered?()
            phase = .success(order)
        } catch {
            phase = .failure(PurchaseFailure(error))
        }
    }
}
