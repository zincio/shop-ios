import Vision
import CoreVideo

/// On-device image classification used as the fallback when Visual Intelligence
/// provides no labels. Returns human-readable identifiers, most-confident first,
/// above a confidence threshold.
///
/// Synchronous by design: the caller holds a `CVPixelBuffer` that is only valid
/// inside a `CVReadOnlyPixelBuffer.withUnsafeBuffer` scope, so classification must
/// finish before that scope ends. Call it off the main actor — the Visual
/// Intelligence query runs on a background executor and `VNImageRequestHandler.perform`
/// blocks its thread.
enum VisionImageClassifier {
    static func labels(
        from pixelBuffer: CVPixelBuffer,
        minimumConfidence: Float = 0.15,
        limit: Int = 3
    ) -> [String] {
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
    }
}
