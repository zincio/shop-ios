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
        /// True once the product thumbnail has been cached to the shared container.
        /// Flipping this drives a re-render so the widget picks up the image.
        var hasImage: Bool = false
    }

    /// Static info that doesn't change for the life of the activity.
    var productTitle: String
    var orderId: String
}
