import SwiftUI

/// Standalone shipping editor used from Settings. (First-run collection happens
/// in OnboardingView.)
struct ShippingSetupView: View {
    @EnvironmentObject private var store: ProfileStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft = ShippingProfile()

    var body: some View {
        Form {
            Section("Shipping address") {
                ShippingFields(profile: $draft)
            }
            Section {
                Button("Save") {
                    store.shipping = draft
                    dismiss()
                }
                .disabled(!draft.isComplete)
            }
        }
        .navigationTitle("Shipping")
        .onAppear { draft = store.shipping }
    }
}
