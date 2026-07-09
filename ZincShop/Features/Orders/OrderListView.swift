import SwiftUI

struct OrderListView: View {
    @EnvironmentObject private var store: ProfileStore
    /// The product to re-place, set when the user taps "Retry Order" on a failed
    /// order; presents the purchase flow for a fresh attempt.
    @State private var retryProduct: Product?
    @State private var isRefreshing = false

    private let zinc = ZincClient()

    var body: some View {
        NavigationStack {
            List {
                ForEach(store.orders) { order in
                    NavigationLink(value: order) { OrderRow(order: order) }
                        .contextMenu { rowActions(order) }
                }
                if store.orders.isEmpty {
                    ContentUnavailableView("No orders yet", systemImage: "shippingbox",
                                           description: Text("Your purchases will appear here."))
                }
            }
            .navigationTitle("Orders")
            .navigationDestination(for: OrderRecord.self) { OrderDetailView(orderID: $0.id) }
            .refreshable { await refreshActiveOrders() }
            .toolbar {
                if isRefreshing {
                    ToolbarItem(placement: .topBarTrailing) { ProgressView() }
                }
            }
            .sheet(item: $retryProduct) { product in
                PurchaseFlowView(product: product, quantity: 1)
            }
            // Pull fresh status when the tab opens, rather than waiting for the
            // ~10s background poll to catch up.
            .task { await refreshActiveOrders() }
        }
    }

    /// Re-fetch the latest status for every still-in-progress order. There's no
    /// server-side order list (orders are created and stored on-device), so this
    /// refreshes the ones we know about; terminal orders won't change.
    private func refreshActiveOrders() async {
        let active = store.orders.filter(\.isInProgress)
        guard !active.isEmpty else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        for order in active {
            guard let dto = try? await zinc.getOrder(id: order.id, apiKey: order.apiKey),
                  var record = store.orders.first(where: { $0.id == order.id }) else { continue }
            record.apply(dto)
            store.upsert(record)
            await LiveActivityManager.update(for: record)
        }
    }

    /// Retry is offered only for failed orders we can rebuild the product for.
    @ViewBuilder private func rowActions(_ order: OrderRecord) -> some View {
        if order.isFailed, let product = order.reorderProduct {
            Button {
                retryProduct = product
            } label: {
                Label("Retry Order", systemImage: "arrow.clockwise")
            }
        }
    }
}

struct OrderRow: View {
    let order: OrderRecord

    var body: some View {
        HStack(spacing: 12) {
            ProductThumbnail(url: order.productImageURL)
            VStack(alignment: .leading, spacing: 5) {
                Text(order.productTitle).lineLimit(1)
                HStack(spacing: 6) {
                    StatusBadge(order: order)
                    Spacer(minLength: 0)
                    Text((Double(order.priceCents) / 100).formatted(.currency(code: "USD")))
                        .font(.caption.bold()).foregroundStyle(.secondary)
                }
            }
        }
    }
}

/// Small colored pill reflecting the order state.
struct StatusBadge: View {
    let order: OrderRecord

    var body: some View {
        HStack(spacing: 4) {
            if order.isInProgress {
                ProgressView().controlSize(.mini)
            }
            Text(label)
                .font(.caption2.weight(.semibold))
        }
        .padding(.horizontal, 8).padding(.vertical, 3)
        .background(tint.opacity(0.15), in: Capsule())
        .foregroundStyle(tint)
    }

    private var label: String { order.jobResultError != nil ? "Failed" : order.statusDisplay }

    private var tint: Color {
        if order.jobResultError != nil { return .red }
        switch order.status.lowercased() {
        case "delivered", "completed": return .green
        case "shipped": return .blue
        case "cancelled", "canceled", "failed", "error": return .red
        default: return .orange
        }
    }
}

/// Product image thumbnail with a consistent placeholder/loading look, shared
/// by the search results (`ProductRow`) and the Orders list (`OrderRow`).
struct ProductThumbnail: View {
    let url: URL?
    var size: CGFloat = 52

    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(.quaternary)
            .frame(width: size, height: size)
            .overlay {
                if let url {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image): image.resizable().scaledToFit().padding(4)
                        case .failure: Image(systemName: "shippingbox.fill").foregroundStyle(.secondary)
                        default: ProgressView()
                        }
                    }
                } else {
                    Image(systemName: "shippingbox.fill").foregroundStyle(.secondary)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
