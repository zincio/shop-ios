import SwiftUI

struct ShippingSetupView: View {
    @EnvironmentObject private var store: ProfileStore
    @State private var draft = ShippingProfile()

    var body: some View {
        NavigationStack {
            Form {
                Section("Where should we ship?") {
                    TextField("First name", text: $draft.firstName)
                        .textContentType(.givenName)
                    TextField("Last name", text: $draft.lastName)
                        .textContentType(.familyName)
                    TextField("Address line 1", text: $draft.addressLine1)
                        .textContentType(.fullStreetAddress)
                    TextField("Address line 2 (optional)", text: $draft.addressLine2)
                    TextField("City", text: $draft.city)
                        .textContentType(.addressCity)
                    TextField("State", text: $draft.state)
                        .textContentType(.addressState)
                    TextField("ZIP", text: $draft.postalCode)
                        .textContentType(.postalCode)
                        .keyboardType(.numbersAndPunctuation)
                    TextField("Phone", text: $draft.phoneNumber)
                        .textContentType(.telephoneNumber)
                        .keyboardType(.phonePad)
                }
                Section {
                    Button("Save & Continue") {
                        store.shipping = draft
                    }
                    .disabled(!draft.isComplete)
                }
                Section {
                    Text("Then enable “Buy with Zinc” in Siri and say “Hey Siri, buy toilet paper with Zinc.”")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Welcome to Zinc")
            .onAppear { draft = store.shipping }
        }
    }
}
