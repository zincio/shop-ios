import SwiftUI

/// Reusable shipping address fields, bound to a draft profile. Used by both the
/// first-launch onboarding and the Settings editor.
struct ShippingFields: View {
    @Binding var profile: ShippingProfile

    var body: some View {
        Group {
            TextField("First name", text: $profile.firstName)
                .textContentType(.givenName)
            TextField("Last name", text: $profile.lastName)
                .textContentType(.familyName)
            TextField("Address line 1", text: $profile.addressLine1)
                .textContentType(.fullStreetAddress)
            TextField("Address line 2 (optional)", text: $profile.addressLine2)
            TextField("City", text: $profile.city)
                .textContentType(.addressCity)
            TextField("State", text: $profile.state)
                .textContentType(.addressState)
            TextField("ZIP", text: $profile.postalCode)
                .textContentType(.postalCode)
                .keyboardType(.numbersAndPunctuation)
            TextField("Phone", text: $profile.phoneNumber)
                .textContentType(.telephoneNumber)
                .keyboardType(.phonePad)
        }
    }
}
