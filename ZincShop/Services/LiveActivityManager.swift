import Foundation
import ActivityKit

/// Wraps ActivityKit for order tracking. No-ops gracefully when Live Activities
/// are disabled or unsupported, so callers don't need to guard.
@MainActor
enum LiveActivityManager {
    private static var activities: [String: Activity<OrderTrackingAttributes>] = [:]

    static func start(for order: OrderRecord) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let attributes = OrderTrackingAttributes(productTitle: order.productTitle, orderId: order.id)
        let state = contentState(for: order)
        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: nil)
            )
            activities[order.id] = activity
            cacheProductImage(for: order)
        } catch {
            // Live Activity unavailable (e.g. no widget, simulator limits) — ignore.
        }
    }

    /// Downloads and caches the product thumbnail, then refreshes the activity so
    /// the widget re-renders with the image in place.
    private static func cacheProductImage(for order: OrderRecord) {
        guard let url = order.productImageURL, !SharedImageStore.hasImage(orderID: order.id) else { return }
        Task {
            await SharedImageStore.cache(from: url, orderID: order.id)
            await update(for: order)
        }
    }

    static func update(for order: OrderRecord) async {
        guard let activity = activities[order.id] else { return }
        await activity.update(.init(state: contentState(for: order), staleDate: nil))
    }

    static func end(for order: OrderRecord) async {
        guard let activity = activities[order.id] else { return }
        await activity.end(.init(state: contentState(for: order), staleDate: nil),
                           dismissalPolicy: .default)
        activities[order.id] = nil
        SharedImageStore.remove(orderID: order.id)
    }

    /// On launch, re-adopt Live Activities started in a previous process so
    /// updates keep flowing, and immediately end any that no longer map to an
    /// in-progress order (stale/orphaned).
    static func reattach(to orders: [OrderRecord]) async {
        let byID = Dictionary(orders.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        for activity in Activity<OrderTrackingAttributes>.activities {
            let id = activity.attributes.orderId
            if let order = byID[id], order.isInProgress {
                activities[id] = activity
                await activity.update(.init(state: contentState(for: order), staleDate: nil))
                cacheProductImage(for: order)
            } else {
                let finalState = byID[id].map(contentState(for:)) ?? activity.content.state
                await activity.end(.init(state: finalState, staleDate: nil),
                                   dismissalPolicy: .immediate)
                activities[id] = nil
            }
        }
    }

    private static func contentState(for order: OrderRecord) -> OrderTrackingAttributes.ContentState {
        let tracking = order.trackingNumbers.first
        let progress: Double = {
            switch order.status.lowercased() {
            case "pending", "placing": return 0.25
            case "placed", "processing": return 0.5
            case "shipped": return 0.8
            case "delivered", "completed": return 1.0
            default: return tracking == nil ? 0.4 : 0.85
            }
        }()
        return .init(status: order.statusDisplay, trackingNumber: tracking, progress: progress,
                     hasImage: SharedImageStore.hasImage(orderID: order.id))
    }
}
