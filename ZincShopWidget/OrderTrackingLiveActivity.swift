import ActivityKit
import WidgetKit
import SwiftUI

/// Lock Screen + Dynamic Island rendering for an in-flight Zinc order.
struct OrderTrackingLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: OrderTrackingAttributes.self) { context in
            // Lock Screen / banner.
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "shippingbox.fill").foregroundStyle(.tint)
                    Text(context.attributes.productTitle).font(.headline).lineLimit(1)
                    Spacer()
                    Text(context.state.status).font(.caption).foregroundStyle(.secondary)
                }
                ProgressView(value: context.state.progress)
                if let tracking = context.state.trackingNumber {
                    Text("Tracking: \(tracking)").font(.caption2).foregroundStyle(.secondary)
                }
            }
            .padding()
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "shippingbox.fill").foregroundStyle(.tint)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.productTitle).font(.caption).lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ProgressView(value: context.state.progress) {
                        Text(context.state.status).font(.caption2)
                    }
                }
            } compactLeading: {
                Image(systemName: "shippingbox.fill")
            } compactTrailing: {
                Text(context.state.status).font(.caption2).lineLimit(1)
            } minimal: {
                Image(systemName: "shippingbox.fill")
            }
        }
    }
}
