import Foundation
import ActivityKit

/// Live Activity attributes shared between the app (which starts/updates the
/// activity) and the widget extension (which renders it on the Lock Screen and
/// in the Dynamic Island).
struct OrderTrackingAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        /// Human-readable status, e.g. "Placing order", "Shipped".
        var status: String
        /// Carrier tracking number once available.
        var trackingNumber: String?
        /// 0.0...1.0 coarse progress for the progress bar.
        var progress: Double
    }

    /// Static info that doesn't change for the life of the activity.
    var productTitle: String
    var orderId: String
}
