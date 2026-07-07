import SwiftUI

struct OrderListView: View {
    @EnvironmentObject private var store: ProfileStore

    var body: some View {
        NavigationStack {
            List {
                ForEach(store.orders) { order in
                    NavigationLink(value: order) { OrderRow(order: order) }
                }
                if store.orders.isEmpty {
                    ContentUnavailableView("No orders yet", systemImage: "shippingbox",
                                           description: Text("Your purchases will appear here."))
                }
            }
            .navigationTitle("Orders")
            .navigationDestination(for: OrderRecord.self) { OrderDetailView(orderID: $0.id) }
        }
    }
}

struct OrderRow: View {
    let order: OrderRecord

    var body: some View {
        HStack(spacing: 12) {
            OrderThumbnail(url: order.productImageURL)
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

/// Product image thumbnail shared by the Orders list and detail.
struct OrderThumbnail: View {
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
