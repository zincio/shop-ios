import SwiftUI

@main
struct ZincShopApp: App {
    @StateObject private var store = ProfileStore.shared

    // Note: no updateAppShortcutParameters() call — the shortcut has no dynamic
    // parameters, and that call only triggers a benign but noisy
    // "Failed to connect to linkd" error on the simulator. App Shortcuts are
    // registered from build-time metadata at install, so no runtime nudge is
    // needed.

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
        }
    }
}
