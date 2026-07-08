import Foundation
import Security

/// Resolves the Zinc API key used for keyed search + ordering.
///
/// Precedence: the **user's own key** (entered during onboarding, stored in the
/// Keychain) wins; otherwise we fall back to the **build-time key** from
/// `Secrets.xcconfig` (a dev convenience so the app is usable out of the box
/// without every developer typing a key). Requests only ever see `apiKey` — they
/// don't care which source it came from.
///
/// The user's key is a live credential, so it lives in the Keychain (encrypted,
/// not in the UserDefaults blob or iCloud backups) rather than alongside the rest
/// of `ProfileStore`. Access is synchronous and non-isolated so `ZincClient`
/// (which runs off the main actor) can read it inline.
enum ZincCredentials {
    private static let service = "io.zinc.zincshop"
    private static let account = "zinc-api-key"

    /// The key requests should use: the user's own key if set, else the
    /// build-time key from `Secrets.xcconfig`.
    static var apiKey: String {
        let user = userApiKey
        return user.isEmpty ? SecretsStore.zincApiKey : user
    }

    /// Whether the effective key came from the user (vs. the bundled dev key).
    static var hasUserApiKey: Bool { !userApiKey.isEmpty }

    /// The user-entered key from the Keychain, or "" if none has been stored.
    static var userApiKey: String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let key = String(data: data, encoding: .utf8) else { return "" }
        return key
    }

    /// Persist (or, for an empty value, clear) the user's key. We delete-then-add
    /// so a re-entered key replaces the old one without an update/attribute dance.
    static func setUserApiKey(_ key: String) {
        let trimmed = SecretsStore.clean(key)
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(base as CFDictionary)
        guard !trimmed.isEmpty, let data = trimmed.data(using: .utf8) else { return }
        var add = base
        add[kSecValueData as String] = data
        // AfterFirstUnlock so order-status polling can read the key when the app
        // wakes in the background.
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(add as CFDictionary, nil)
    }
}
