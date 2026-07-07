import Foundation
import UIKit

/// Bridges product thumbnails from the app into the widget extension.
///
/// Live Activities render in the widget process and can't load remote images
/// (`AsyncImage`/networking don't run during the render pass). So the app
/// downloads the product image once, downsizes it, and writes it to the shared
/// App Group container; the widget then loads it synchronously from disk by
/// order id at render time.
enum SharedImageStore {
    /// Must match `com.apple.security.application-groups` in both targets' entitlements.
    static let appGroupID = "group.io.zinc.zincshop"

    /// Longest edge for the cached thumbnail. Live Activity art is shown small,
    /// so keep it tiny to stay well within the widget's memory budget.
    private static let maxDimension: CGFloat = 160

    private static var directory: URL? {
        guard let container = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else { return nil }
        let dir = container.appendingPathComponent("OrderImages", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private static func fileURL(orderID: String) -> URL? {
        let safe = orderID.unicodeScalars
            .map { CharacterSet.alphanumerics.contains($0) ? Character($0) : "_" }
        return directory?.appendingPathComponent(String(safe) + ".jpg")
    }

    // MARK: - App side

    /// Downloads, downsizes, and caches the product image for an order. Safe to
    /// call repeatedly; skips the download if a cached copy already exists.
    static func cache(from url: URL, orderID: String) async {
        guard let fileURL = fileURL(orderID: orderID) else { return }
        if FileManager.default.fileExists(atPath: fileURL.path) { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let thumbnail = downsized(data) else { return }
            try thumbnail.write(to: fileURL, options: .atomic)
        } catch {
            // Non-fatal: the widget falls back to a placeholder icon.
        }
    }

    private static func downsized(_ data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let longest = max(image.size.width, image.size.height)
        let scale = longest > maxDimension ? maxDimension / longest : 1
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let rendered = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return rendered.jpegData(compressionQuality: 0.8)
    }

    // MARK: - Widget side

    /// Whether a cached thumbnail exists for the order.
    static func hasImage(orderID: String) -> Bool {
        guard let fileURL = fileURL(orderID: orderID) else { return false }
        return FileManager.default.fileExists(atPath: fileURL.path)
    }

    /// Loads the cached thumbnail for the order, if any.
    static func image(orderID: String) -> UIImage? {
        guard let fileURL = fileURL(orderID: orderID),
              let data = try? Data(contentsOf: fileURL) else { return nil }
        return UIImage(data: data)
    }

    /// Removes the cached thumbnail (e.g. when an order reaches a terminal state).
    static func remove(orderID: String) {
        guard let fileURL = fileURL(orderID: orderID) else { return }
        try? FileManager.default.removeItem(at: fileURL)
    }
}
