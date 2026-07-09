import SwiftUI

struct OrderDetailView: View {
    let orderID: String
    @EnvironmentObject private var store: ProfileStore
    @State private var isRefreshing = false
    @State private var errorText: String?

    private let zinc = ZincClient()

    private var order: OrderRecord? { store.orders.first { $0.id == orderID } }

    var body: some View {
        List {
            if let order {
                Section {
                    heroHeader(order)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
                Section("Item") {
                    Text(order.productTitle)
                }
                Section("Status") {
                    LabeledContent("State") { StatusBadge(order: order) }
                    LabeledContent("Total", value: (Double(order.priceCents) / 100)
                        .formatted(.currency(code: "USD")))
                    LabeledContent("Order ID", value: order.id)
                }
                if let problem = order.jobResultError {
                    Section("Problem") {
                        Label(problem, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
                }
                if !order.trackingNumbers.isEmpty {
                    Section("Tracking") {
                        ForEach(order.trackingNumbers, id: \.self) { Text($0).textSelection(.enabled) }
                    }
                }
                if let errorText {
                    Section { Text(errorText).foregroundStyle(.red) }
                }
            } else {
                ContentUnavailableView("Order not found", systemImage: "shippingbox",
                                       description: Text("This order is no longer available."))
            }
        }
        .listStyle(.grouped)
        .refreshable { await refresh() }
        .navigationTitle("Order")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { Task { await refresh() } } label: {
                    // Spin the icon while refreshing — clearer than swapping to a
                    // tiny inline spinner.
                    Image(systemName: "arrow.clockwise")
                        .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                        .animation(isRefreshing
                                   ? .linear(duration: 1).repeatForever(autoreverses: false)
                                   : .default,
                                   value: isRefreshing)
                }
                .disabled(isRefreshing)
            }
        }
        .task { await refresh() }
    }

    /// Full-bleed product image at the top of the detail screen, with a graceful
    /// placeholder while loading or when no image is available.
    @ViewBuilder private func heroHeader(_ order: OrderRecord) -> some View {
        ZStack {
            Rectangle().fill(.quaternary)
            if let url = order.productImageURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        placeholderIcon
                    default:
                        ProgressView()
                    }
                }
            } else {
                placeholderIcon
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 240)
        .clipped()
    }

    private var placeholderIcon: some View {
        Image(systemName: "shippingbox.fill")
            .font(.system(size: 44))
            .foregroundStyle(.secondary)
    }

    private func refresh() async {
        guard let order else { return }
        isRefreshing = true; errorText = nil
        defer { isRefreshing = false }
        do {
            let dto = try await zinc.getOrder(id: order.id, apiKey: order.apiKey)
            var updated = order
            updated.apply(dto)
            store.upsert(updated)
            await LiveActivityManager.update(for: updated)
        } catch {
            errorText = "Couldn't refresh: \(error.localizedDescription)"
        }
    }
}
