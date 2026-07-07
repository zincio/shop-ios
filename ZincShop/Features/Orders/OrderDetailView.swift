import SwiftUI

struct OrderDetailView: View {
    let orderID: String
    @EnvironmentObject private var store: ProfileStore
    @State private var isRefreshing = false
    @State private var errorText: String?

    private let zinc = ZincClient()

    private var order: OrderRecord? { store.orders.first { $0.id == orderID } }

    var body: some View {
        Form {
            if let order {
                Section("Item") { Text(order.productTitle) }
                Section("Status") {
                    LabeledContent("State", value: order.statusDisplay)
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
                Text("Order not found.")
            }
        }
        .navigationTitle("Order")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { Task { await refresh() } } label: {
                    if isRefreshing { ProgressView() } else { Image(systemName: "arrow.clockwise") }
                }
                .disabled(isRefreshing)
            }
        }
        .task { await refresh() }
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
