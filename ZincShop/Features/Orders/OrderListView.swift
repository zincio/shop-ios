import SwiftUI

struct OrderListView: View {
    @EnvironmentObject private var store: ProfileStore

    var body: some View {
        NavigationStack {
            List {
                ForEach(store.orders) { order in
                    NavigationLink(value: order) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(order.productTitle).lineLimit(1)
                            HStack {
                                Text(order.statusDisplay)
                                    .font(.caption).foregroundStyle(.secondary)
                                Spacer()
                                Text((Double(order.priceCents) / 100)
                                    .formatted(.currency(code: "USD")))
                                    .font(.caption.bold())
                            }
                        }
                    }
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
