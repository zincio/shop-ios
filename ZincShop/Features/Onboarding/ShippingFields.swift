import SwiftUI

/// Reusable shipping address fields, bound to a draft profile. Used by both the
/// first-launch onboarding and the Settings editor.
struct ShippingFields: View {
    @Binding var profile: ShippingProfile

    var body: some View {
        Group {
            required("First name", $profile.firstName, content: .givenName)
            required("Last name", $profile.lastName, content: .familyName)
            required("Address line 1", $profile.addressLine1, content: .fullStreetAddress)
            TextField("Address line 2 (optional)", text: $profile.addressLine2)
            required("City", $profile.city, content: .addressCity)
            TextField("State", text: $profile.state)
                .textContentType(.addressState)
            required("ZIP", $profile.postalCode, content: .postalCode,
                     keyboard: .numbersAndPunctuation)
            required("Phone", $profile.phoneNumber, content: .telephoneNumber,
                     keyboard: .phonePad)
        }
    }

    /// A required field (one of `ShippingProfile.isComplete`'s), with a red
    /// asterisk shown until it's filled so gaps are visible before advancing.
    private func required(_ title: String, _ text: Binding<String>,
                          content: UITextContentType,
                          keyboard: UIKeyboardType = .default) -> some View {
        HStack(spacing: 6) {
            TextField(title, text: text)
                .textContentType(content)
                .keyboardType(keyboard)
            if text.wrappedValue.trimmingCharacters(in: .whitespaces).isEmpty {
                Text("*")
                    .font(.body.weight(.bold))
                    .foregroundStyle(.red)
                    .accessibilityLabel("Required")
            }
        }
    }
}
