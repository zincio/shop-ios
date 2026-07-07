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
                    OrderThumbnail(orderID: context.attributes.orderId, size: 32)
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
                    OrderThumbnail(orderID: context.attributes.orderId, size: 32)
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
                OrderThumbnail(orderID: context.attributes.orderId, size: 20)
            } compactTrailing: {
                Text(context.state.status).font(.caption2).lineLimit(1)
            } minimal: {
                OrderThumbnail(orderID: context.attributes.orderId, size: 20)
            }
        }
    }
}

/// Shows the cached product thumbnail for an order, falling back to a box icon.
/// The image is loaded synchronously from the shared App Group container (widgets
/// can't fetch remote images), written there by the app when the activity starts.
private struct OrderThumbnail: View {
    let orderID: String
    var size: CGFloat = 28

    var body: some View {
        if let image = SharedImageStore.image(orderID: orderID) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.22))
        } else {
            Image(systemName: "shippingbox.fill")
                .font(.system(size: size * 0.7))
                .foregroundStyle(.tint)
                .frame(width: size, height: size)
        }
    }
}
