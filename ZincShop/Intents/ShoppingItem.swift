import AppIntents

/// The set of items Siri can parse inline in a spoken phrase, e.g.
/// "Buy paper towels with Zinc". App Shortcut phrases only accept `AppEnum`
/// or `AppEntity` parameters (never a free-form `String`), so a curated enum is
/// what lets Siri recognize the product in one utterance instead of routing
/// "buy paper towels" to its built-in Reminders/shopping-list behavior.
///
/// Each case maps to a natural-language search query fed to `ZincClient.search`.
/// Cases stay aligned with `MockCatalog`. (For an open-ended catalog you'd swap
/// this for an `AppEntity` with a dynamic query; an enum is the reliable choice
/// for a known, common set that Siri can match inline.)
enum ShoppingItem: String, AppEnum, CaseIterable {
    case toiletPaper
    case paperTowels
    case coffee
    case laundryDetergent
    case dishSoap

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Item")

    static let caseDisplayRepresentations: [ShoppingItem: DisplayRepresentation] = [
        .toiletPaper: "toilet paper",
        .paperTowels: "paper towels",
        .coffee: "coffee",
        .laundryDetergent: "laundry detergent",
        .dishSoap: "dish soap",
    ]

    /// The query string handed to product search.
    var searchQuery: String {
        switch self {
        case .toiletPaper: "toilet paper"
        case .paperTowels: "paper towels"
        case .coffee: "coffee"
        case .laundryDetergent: "laundry detergent"
        case .dishSoap: "dish soap"
        }
    }
}
