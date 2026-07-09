import Foundation

/// Turns Visual Intelligence's `SemanticContentDescriptor` signal into a text
/// query for Zinc's text-only search. Pure and side-effect free: the actual
/// on-device Vision call is injected as `classify`, so this is unit-testable
/// without an image or the Vision framework.
enum SemanticQueryBuilder {
    /// Labels first (Visual Intelligence already computed them); fall back to the
    /// injected classifier (Vision) only when there are none; else `nil`.
    static func query(
        labels: [String],
        classify: () async -> [String]
    ) async -> String? {
        if let q = compose(labels) { return q }
        return compose(await classify())
    }

    /// Trim, drop empties, take the top 3, join with spaces. `nil` if nothing left.
    private static func compose(_ raw: [String]) -> String? {
        let cleaned = raw
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .prefix(3)
        return cleaned.isEmpty ? nil : cleaned.joined(separator: " ")
    }
}
