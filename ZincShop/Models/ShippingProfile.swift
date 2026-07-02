import Foundation

/// The buyer's shipping destination. Persisted locally; sent with every order.
struct ShippingProfile: Codable, Equatable {
    var firstName: String = ""
    var lastName: String = ""
    var addressLine1: String = ""
    var addressLine2: String = ""
    var city: String = ""
    var state: String = ""
    var postalCode: String = ""
    var country: String = "US"
    var phoneNumber: String = ""

    var isComplete: Bool {
        !firstName.isEmpty && !lastName.isEmpty && !addressLine1.isEmpty
            && !city.isEmpty && !postalCode.isEmpty && !phoneNumber.isEmpty
    }
}
