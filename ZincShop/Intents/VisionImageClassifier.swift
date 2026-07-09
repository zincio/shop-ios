import Vision
import CoreVideo

/// On-device image classification used as the fallback when Visual Intelligence
/// provides no labels. Returns human-readable identifiers, most-confident first,
/// above a confidence threshold. Runs off the main thread.
enum VisionImageClassifier {
    static func labels(
        from pixelBuffer: CVPixelBuffer?,
        minimumConfidence: Float = 0.15,
        limit: Int = 3
    ) async -> [String] {
        guard let pixelBuffer else { return [] }
        return await Task.detached(priority: .userInitiated) {
            let request = VNClassifyImageRequest()
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
            do {
                try handler.perform([request])
            } catch {
                return []
            }
            let observations = (request.results ?? [])
                .filter { $0.confidence >= minimumConfidence }
                .sorted { $0.confidence > $1.confidence }
                .prefix(limit)
            // Vision identifiers look like "coffee_mug"; humanize for search.
            return observations.map {
                $0.identifier.replacingOccurrences(of: "_", with: " ")
            }
        }.value
    }
}
