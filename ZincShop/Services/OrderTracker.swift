import Foundation

/// Polls order status while an order is pending/processing, updating both the
/// stored record (list badge + detail) and its Live Activity, then stops once
/// the order reaches a terminal state (shipped/delivered/failed/tracking).
@MainActor
final class OrderTracker {
    static let shared = OrderTracker()

    private let zinc = ZincClient()
    private let store = ProfileStore.shared
    private var tasks: [String: Task<Void, Never>] = [:]

    private let interval: Duration = .seconds(10)
    private let maxPolls = 60 // ~10 min ceiling

    /// Begin polling an order if it's still in progress and not already tracked.
    func track(_ order: OrderRecord) {
        guard order.isInProgress, tasks[order.id] == nil else { return }
        let id = order.id, apiKey = order.apiKey
        tasks[id] = Task { [weak self] in await self?.poll(id: id, apiKey: apiKey) }
    }

    /// Resume tracking any in-progress orders (e.g. on app launch).
    func resumeAll() {
        for order in store.orders where order.isInProgress { track(order) }
    }

    private func poll(id: String, apiKey: String?) async {
        defer { tasks[id] = nil }
        for _ in 0..<maxPolls {
            try? await Task.sleep(for: interval)
            if Task.isCancelled { return }
            guard let dto = try? await zinc.getOrder(id: id, apiKey: apiKey),
                  var record = store.orders.first(where: { $0.id == id }) else { continue }
            record.apply(dto)
            store.upsert(record)
            await LiveActivityManager.update(for: record)
            if !record.isInProgress {
                await LiveActivityManager.end(for: record)
                return
            }
        }
    }
}
