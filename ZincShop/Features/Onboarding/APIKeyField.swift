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
