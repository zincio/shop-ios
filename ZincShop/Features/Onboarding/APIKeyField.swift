import SwiftUI

/// Reusable Zinc API-key entry field with a show/hide (eye) toggle, bound to a
/// draft string. Used by both first-launch onboarding and the Settings editor.
///
/// A key is a live secret, so it defaults to obscured (`SecureField`); tapping
/// the eye reveals it as a plain `TextField` for visual verification while
/// typing/pasting.
struct APIKeyField: View {
    @Binding var text: String
    @State private var isRevealed = false

    /// A Zinc key looks like `zn_live_…` / `zn_test_…`. Used only for a gentle
    /// format hint — an empty field is valid (falls back to the bundled dev key).
    static func looksLikeKey(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        return trimmed.hasPrefix("zn_") && trimmed.count >= 12
    }

    private var isEmpty: Bool { text.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        HStack(spacing: 8) {
            Group {
                if isRevealed {
                    TextField("zn_live_…", text: $text)
                } else {
                    SecureField("zn_live_…", text: $text)
                }
            }
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .font(.body.monospaced())

            if !isEmpty {
                let valid = Self.looksLikeKey(text)
                Image(systemName: valid ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(valid ? .green : .orange)
                    .accessibilityLabel(valid ? "Key format looks valid"
                                               : "Key should start with zn_")
            }

            Button {
                isRevealed.toggle()
            } label: {
                Image(systemName: isRevealed ? "eye.slash" : "eye")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(isRevealed ? "Hide API key" : "Show API key")
        }
    }
}
