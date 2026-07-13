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

/// "Verify" button + live result label that actually calls the Zinc API with the
/// entered key, so the user gets an immediate ✓/✗ instead of discovering a bad
/// key only when a search silently returns nothing. Used in onboarding and
/// Settings. Verifies the passed-in value without persisting it.
struct APIKeyVerifyRow: View {
    let key: String

    enum Status: Equatable { case idle, checking, valid, invalid, networkError }
    @State private var status: Status = .idle
    /// Incremented whenever the key changes so an in-flight verify started
    /// against an older key can recognize its result is stale and drop it
    /// (otherwise: tap Verify, edit the key, and the old key's ✓/✗ lands next
    /// to the new key).
    @State private var generation = 0

    private var trimmed: String { key.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                Task { await verify() }
            } label: {
                if status == .checking {
                    ProgressView()
                } else {
                    Label("Verify key", systemImage: "checkmark.shield")
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(trimmed.isEmpty || status == .checking)

            if let (text, symbol, color) = message {
                Label(text, systemImage: symbol)
                    .font(.footnote)
                    .foregroundStyle(color)
            }
        }
        // A changed key invalidates a prior result — and any in-flight check.
        .onChange(of: key) { _, _ in
            generation += 1
            status = .idle
        }
    }

    private var message: (String, String, Color)? {
        switch status {
        case .idle, .checking: return nil
        case .valid:           return ("Key verified — search is live.", "checkmark.circle.fill", .green)
        case .invalid:         return ("Key rejected by Zinc. Double-check it (watch for 0 vs O).", "xmark.circle.fill", .red)
        case .networkError:    return ("Couldn't reach Zinc. Check your connection and retry.", "wifi.exclamationmark", .orange)
        }
    }

    private func verify() async {
        let gen = generation
        status = .checking
        let result = await ZincClient().verify(key: trimmed)
        // The key was edited while this request was in flight (onChange bumped
        // `generation` and reset to .idle) — this result describes the OLD key,
        // so drop it rather than mislabel the new one.
        guard gen == generation else { return }
        switch result {
        case .valid:        status = .valid
        case .invalid:      status = .invalid
        case .networkError: status = .networkError
        }
    }
}
